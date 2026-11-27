require "minitest/autorun"
require_relative "application"
require_relative "../../lib/domstride"
require "action_cable"
require "puma"
require "puma/server"

class DomstrideReferenceChannel < ActionCable::Channel::Base
  def subscribed
    stream_from "domstride-reference"
  end

  def announce
    connection.server.broadcast("domstride-reference",
      '<turbo-stream action="update" target="message"><template>Published</template></turbo-stream>')
  end
end

class CableReferenceTest < Minitest::Test
  def setup
    config = ActionCable::Server::Configuration.new
    config.logger = ActiveSupport::Logger.new(IO::NULL)
    config.cable = { "adapter" => "async" }
    config.allowed_request_origins = ["http://example.test"]
    config.allow_same_origin_as_host = false
    @cable = ActionCable::Server::Base.new(config: config)
    @puma = Puma::Server.new(@cable)
    @puma.add_tcp_listener("127.0.0.1", 0)
    @puma.run
    @endpoint = "ws://127.0.0.1:#{@puma.connected_ports.first}/cable"
    asset = File.join(Gem.loaded_specs.fetch("actioncable").full_gem_path, "app/assets/javascripts/actioncable.js")
    client = File.read(asset)
    turbo = File.read(File.join(__dir__, "cable.bundle.js"))
    @app = lambda do |_env|
      [200, {"content-type" => "text/html"}, [<<~HTML]]
        <!doctype html><html><body>
          <output id="connection">Pending</output><output id="message">Initial</output>
          <button id="publish">Publish</button><button id="disconnect">Disconnect</button>
          <script>#{client}</script><script>#{turbo}</script>
        </body></html>
      HTML
    end
  end

  def teardown
    @cable&.restart
    @cable&.event_loop&.stop
    @puma&.stop(true)
  end

  def session(&block)
    Domstride::Session.open(app: @app, websocket_url: @endpoint, clock: "real", &block)
  end

  def wait_until(timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until yield
      raise "Timed out waiting for cable lifecycle" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.01
    end
  end

  def test_real_action_cable_broadcast_and_turbo_dom_updates
    session do |first|
      session do |second|
        first.visit("/")
        second.visit("/")
        assert first.wait_for_text("#connection", "Connected", timeout: 5)
        assert second.wait_for_text("#connection", "Connected", timeout: 5)
        assert_equal({"count" => 1, "open" => 1}, first.websocket_state)
        first.click("#publish")
        assert first.wait_for_text("#message", "Published", timeout: 5)
        assert second.wait_for_text("#message", "Published", timeout: 5)
        first.click("#disconnect")
        wait_until { first.websocket_state["count"] == 0 }
        wait_until { @cable.connections.size == 1 }
        @cable.broadcast("domstride-reference",
          '<turbo-stream action="update" target="message"><template>Second broadcast</template></turbo-stream>')
        assert second.wait_for_text("#message", "Second broadcast", timeout: 5)
        assert_equal "Published", first.text("#message")
        second.visit("/")
        assert second.wait_for_text("#connection", "Connected", timeout: 5)
        wait_until { @cable.connections.size == 1 }
        assert_equal 1, second.websocket_state["open"]
      end
      wait_until { @cable.connections.empty? }
    end
  end

  def test_external_endpoint_is_rejected
    session do |page|
      page.visit("/")
      assert page.wait_for_text("#connection", "Connected", timeout: 5)
      error = assert_raises(Domstride::JavaScriptError) do
        page.execute_script('new WebSocket("ws://outside.example/cable")')
      end
      assert_includes error.message, "UNSUPPORTED_WEBSOCKET_ENDPOINT"
    end
  end
end


# Real Rails signed cookies, separate authenticated Action Cable server and channels.
class DomstrideAuthenticatedConnection < ActionCable::Connection::Base
  identified_by :user
  def connect
    self.user = cookies.signed[:cable_session]
    reject_unauthorized_connection unless %w[alice bob].include?(user)
    reject_unauthorized_connection if cookies[:unrelated] || cookies[:restricted] || cookies[:secure_only]
  end
end

class DomstrideAuthenticatedChannel < ActionCable::Channel::Base
  def subscribed
    stream_from "private-#{connection.user}"
  end

  def announce
    connection.server.broadcast("private-#{connection.user}",
      '<turbo-stream action="update" target="message"><template>Private result</template></turbo-stream>')
  end
end

class AuthenticatedCableReferenceTest < Minitest::Test
  def setup
    config = ActionCable::Server::Configuration.new
    config.logger = ActiveSupport::Logger.new(IO::NULL)
    config.cable = { "adapter" => "async" }
    config.allowed_request_origins = ["http://example.test"]
    config.allow_same_origin_as_host = false
    config.connection_class = -> { DomstrideAuthenticatedConnection }
    @cable = ActionCable::Server::Base.new(config: config)
    routed = lambda do |env|
      if env["PATH_INFO"] == "/123/cable"
        env = env.merge("PATH_INFO" => "/cable", "SCRIPT_NAME" => "/123")
      end
      @cable.call(env)
    end
    @puma = Puma::Server.new(routed)
    @puma.add_tcp_listener("127.0.0.1", 0)
    @puma.run
    @endpoint = "ws://127.0.0.1:#{@puma.connected_ports.first}/cable"
    asset = File.join(Gem.loaded_specs.fetch("actioncable").full_gem_path, "app/assets/javascripts/actioncable.js")
    client = File.read(asset)
    turbo = File.read(File.join(__dir__, "cable.bundle.js")).sub("DomstrideReferenceChannel", "DomstrideAuthenticatedChannel")
    middleware = ActionDispatch::Cookies.new(lambda do |env|
      request = ActionDispatch::Request.new(env)
      if request.path == "/login"
        user = request.params.fetch("user")
        raise "Invalid test identity" unless %w[alice bob].include?(user)
        request.cookie_jar.signed[:cable_session] = { value: user, httponly: true, path: "/" }
        request.cookie_jar[:unrelated] = { value: "not forwarded", path: "/" }
        request.cookie_jar[:restricted] = { value: "wrong path", path: "/cable-other" }
        request.cookie_jar[:secure_only] = { value: "secure", secure: true, path: "/" }
        [302, {"location" => "/"}, []]
      else
        [200, {"content-type" => "text/html"}, [<<~HTML]]
          <!doctype html><html><body>
          <output id="connection">Pending</output><output id="message">Initial</output>
          <button id="publish">Publish</button><button id="disconnect">Disconnect</button>
          <script>#{client}</script><script>#{turbo}</script></body></html>
        HTML
      end
    end)
    @app = ->(env) { middleware.call(Rails.application.env_config.merge(env)) }
  end

  def teardown
    @cable&.restart
    @cable&.event_loop&.stop
    @puma&.stop(true)
  end

  def session(&block)
    Domstride::Session.open(app: @app, websocket_url: @endpoint,
      websocket_cookie_names: "cable_session,restricted,secure_only", clock: "real", &block)
  end

  def test_signed_http_only_cookie_auth_and_private_stream_isolation
    session do |alice|
      session do |bob|
        alice.visit("/login?user=alice")
        bob.visit("/login?user=bob")
        assert alice.wait_for_text("#connection", "Connected", timeout: 5)
        assert bob.wait_for_text("#connection", "Connected", timeout: 5)
        assert_equal "", alice.evaluate_script("document.cookie")
        assert_equal "", bob.evaluate_script("document.cookie")
        alice.click("#publish")
        assert alice.wait_for_text("#message", "Private result", timeout: 5)
        assert_equal "Initial", bob.text("#message")
        bob.click("#publish")
        assert bob.wait_for_text("#message", "Private result", timeout: 5)
        error = assert_raises(Domstride::JavaScriptError) do
          alice.execute_script('new WebSocket("ws://outside.example/cable")')
        end
        assert_includes error.message, "UNSUPPORTED_WEBSOCKET_ENDPOINT"
      end
    end
  end

  def test_numeric_account_path_is_explicit_and_bounded
    Domstride::Session.open(app: @app, websocket_url: @endpoint,
      websocket_cookie_names: "cable_session", websocket_path_mode: "numeric-account") do |page|
      page.visit("/login?user=alice")
      assert page.wait_for_text("#connection", "Connected", timeout: 5)
      page.execute_script(<<~JS)
        window.accountConsumer = ActionCable.createConsumer("/123/cable");
        window.accountSubscription = accountConsumer.subscriptions.create("DomstrideAuthenticatedChannel", {
          connected() { document.getElementById("connection").textContent = "Account connected"; }
        });
      JS
      assert page.wait_for_text("#connection", "Account connected", timeout: 5)
      ["/other/cable", "/123/not-cable", "/123/cable?unexpected=1", "ws://outside.example/123/cable"].each do |url|
        assert_match(/UNSUPPORTED_WEBSOCKET_ENDPOINT/, assert_raises(Domstride::JavaScriptError) {
          page.execute_script("new WebSocket(#{url.to_json})")
        }.message)
      end
    end
    assert_raises(ArgumentError) { Domstride::Session.new(app: @app, websocket_url: @endpoint, websocket_path_mode: "numeric-account") }
  end

  def test_cookie_allowlist_requires_explicit_endpoint
    assert_raises(ArgumentError) { Domstride::Session.new(app: @app, websocket_cookie_names: "cable_session") }
    assert_raises(ArgumentError) { Domstride::Session.new(app: @app, websocket_url: @endpoint, websocket_cookie_names: "bad name") }
  end
end

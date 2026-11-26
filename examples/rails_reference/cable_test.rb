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

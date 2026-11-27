# Discovery-only test server; use Fizzy's real middleware, cookies and channels.
require "puma"
require "puma/server"

module DomstrideFizzyCableServer
  def self.start!
    raise "Test environment required" unless Rails.env.test?
    raise "Parallel workers must be 1" unless ENV["PARALLEL_WORKERS"] == "1"
    cable = ActionCable.server
    # The test adapter records broadcasts without delivering them.
    # Enable the real in-process async adapter for this candidate only.
    cable.config.cable = { "adapter" => "async" }
    cable.config.allowed_request_origins = Array(cable.config.allowed_request_origins) | ["http://example.test"]
    server = Puma::Server.new(Rails.application)
    server.add_tcp_listener("127.0.0.1", 0)
    server.run
    ENV["DOMSTRIDE_WEBSOCKET_URL"] = "ws://127.0.0.1:#{server.connected_ports.first}/cable"
    ENV["DOMSTRIDE_WEBSOCKET_COOKIE_NAMES"] = "session_token"
    ENV["DOMSTRIDE_WEBSOCKET_PATH_MODE"] = "numeric-account"
    Minitest.after_run do
      begin
        Capybara.reset_sessions!
        cable.restart
        cable.event_loop.stop
      ensure
        server.stop(true)
      end
    end
  end
end

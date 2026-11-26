require_relative "application"
require "puma"
server = Puma::Server.new(Rails.application)
server.add_tcp_listener("127.0.0.1", 4567)
server.run.join

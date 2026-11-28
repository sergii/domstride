# Internal, name-neutral consumer entrypoint for isolated packaging verification.
require "domstride/consumer"

command, directory, output = ARGV
abort "Usage: viewer report|replay DIRECTORY [OUTPUT_HTML]" unless (2..3).cover?(ARGV.size) && %w[report replay].include?(command)
begin
  consumer = Domstride::Consumer
  abort "Unexpected producer dependency" if defined?(Domstride::Session) || defined?(Domstride::ReportCase) || defined?(Domstride::Runtime)
  puts (command == "report" ? consumer::Report : consumer::Replay).export(directory, output: output)
rescue Domstride::Error, SystemCallError, ArgumentError => error
  abort error.message
end

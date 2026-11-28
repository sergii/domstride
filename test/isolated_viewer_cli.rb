# Internal, name-neutral consumer entrypoint for isolated packaging verification.
require "domstride/consumer"

command, directory, output = ARGV
abort "Usage: viewer report|replay DIRECTORY [OUTPUT_HTML]" unless (2..3).cover?(ARGV.size) && %w[report replay].include?(command)
begin
  consumer = Specdrive::Consumer
  abort "Unexpected producer dependency" if defined?(Specdrive::Session) || defined?(Specdrive::ReportCase) || defined?(Specdrive::Runtime)
  puts (command == "report" ? consumer::Report : consumer::Replay).export(directory, output: output)
rescue Specdrive::Error, SystemCallError, ArgumentError => error
  abort error.message
end

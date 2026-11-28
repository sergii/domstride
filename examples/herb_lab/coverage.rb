require_relative "../../viewer/lib/coverage"

if $PROGRAM_NAME == __FILE__
  input, directory = ARGV
  abort "Usage: ruby coverage.rb mapping.json EXISTING_OUTPUT_DIRECTORY" unless ARGV.size == 2 && File.directory?(directory)
  report = UICoverage.aggregate(JSON.parse(File.read(input)))
  { "coverage.json" => JSON.pretty_generate(report) + "\n", "coverage.html" => UICoverage.render(report) }.each do |name, content|
    File.open(File.join(directory, name), File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(content) }
  end
end

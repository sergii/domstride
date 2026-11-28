require "digest"
require "json"
require_relative "coverage"
require_relative "domstride/consumer/replay"

# Trusted synthetic research only. Render a verified event, not a live page.
module CoverageBundle
  module_function

  def recording_digest(directory)
    raise ArgumentError, "Invalid recording directory" unless File.directory?(directory) && !File.symlink?(directory)
    names = Dir.children(directory).sort
    raise ArgumentError, "Invalid recording inventory" unless names.include?("events.jsonl") && names.size <= 2001 &&
      names.all? { |name| name == "events.jsonl" || name.match?(/\A\d{6,}-(before|after)\.html\z/) }
    entries = names.map do |name|
      path = File.join(directory,name)
      raise ArgumentError, "Invalid recording file" unless File.file?(path) && !File.symlink?(path)
      limit = name == "events.jsonl" ? 2 * 1024 * 1024 : 256 * 1024
      raise ArgumentError, "Recording file too large" if File.size(path) > limit
      [name,File.size(path),Digest::SHA256.file(path).hexdigest]
    end
    raise ArgumentError, "Recording too large" if entries.sum { |entry| entry[1] } > 20 * 1024 * 1024
    Digest::SHA256.hexdigest(JSON.generate(entries))
  end

  def prepare(mapping, root)
    report = UICoverage.aggregate(mapping)
    plans = []
    mapping.fetch("runs").each_with_index do |run,index|
      ref = run["recording_ref"]
      next unless ref
      expected = "recording-#{index + 1}"
      raise ArgumentError, "Invalid recording reference" unless ref.is_a?(Hash) && ref["directory"] == expected &&
        ref["sha256"].is_a?(String) && ref["sha256"].match?(/\A[0-9a-f]{64}\z/) &&
        ref["event_sequence"].is_a?(Integer) && ref["event_sequence"].positive?
      directory = File.join(root,expected)
      raise ArgumentError, "Recording digest mismatch" unless recording_digest(directory) == ref["sha256"]
      trace = Specdrive::Consumer::Replay.load_recording(directory)
      raise ArgumentError, "Incomplete recording" unless trace.fetch(:complete)
      events = trace.fetch(:events)
      sequences = events.map { |event| event["sequence"] }
      raise ArgumentError, "Duplicate event sequence" unless sequences.uniq == sequences
      event = events.find { |item| item["sequence"] == ref["event_sequence"] }
      observations = report.fetch("runs").fetch(index).fetch("observations").select { |node| node.fetch("clicked") }
      raise ArgumentError, "Unverified recorded target" unless observations.size == 1 && event &&
        event["kind"] == "click" && event["status"] == "passed" &&
        event.dig("before","target_path") == observations.first.fetch("path") &&
        event.dig("before","html").is_a?(String)
      # One event only; never present this document as the whole scenario.
      filename = "run-#{index + 1}-event-#{event.fetch("sequence")}.html"
      observations.first["replay_href"] = filename
      plans << [filename, trace.merge(events: [event])]
    end
    [report,plans]
  end

  def export(input, destination)
    raise ArgumentError, "Expected regular non-symlink input" unless File.file?(input) && !File.symlink?(input)
    raise ArgumentError, "Mapping too large" if File.size(input) > 10 * 1024 * 1024
    mapping = JSON.parse(File.read(input))
    report,plans = prepare(mapping,File.realpath(File.dirname(input)))
    Dir.mkdir(destination,0o700)
    plans.each { |name,trace| Specdrive::Consumer::Replay.render(trace,File.join(destination,name)) }
    File.open(File.join(destination,"coverage.html"),File::WRONLY | File::CREAT | File::EXCL,0o600) { |file| file.write(UICoverage.render(report)) }
    File.open(File.join(destination,"coverage.json"),File::WRONLY | File::CREAT | File::EXCL,0o600) { |file| file.write(JSON.pretty_generate(report)) }
    File.expand_path(File.join(destination,"coverage.html"))
  end
end

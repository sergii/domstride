require "json"
require "fileutils"
require "digest"

REVISION = "071062ca9193c416ec07a3225a7c5bae8da0db64"
CASES = {
  "navigation" => { file: "test/system/back_link_navigation_test.rb", expected: 5 },
  "create_card" => { file: "test/system/smoke_test.rb", name: "test_create_a_card", expected: 1 },
  "join_account" => { file: "test/system/smoke_test.rb", name: "test_joining_an_account", expected: 1 },
  "lightbox" => { file: "test/system/smoke_test.rb", name: "test_lightbox_shows_the_alt_text_of_the_image", expected: 1 }
}.freeze

group, output = ARGV
spec = CASES.fetch(group)
output = File.expand_path(output)
FileUtils.mkdir_p(output)
abort "Expected pinned Fizzy checkout" unless IO.popen(["git", "rev-parse", "HEAD"], &:read).strip == REVISION
abort "Test environment required" unless ENV["RAILS_ENV"] == "test"
helper = "test/application_system_test_case.rb"
original = File.binread(helper)
test_digest = Digest::SHA256.file(spec.fetch(:file)).hexdigest
result = { app: "fizzy", revision: REVISION, group: group, selected: spec,
           test_sha256: test_digest, baseline_mode: "fresh_browser_per_test",
           candidate_mode: "functional_only", candidate_trusted_types_inventory: "not_measured",
           candidate_asset_warnings: "direct-eval", candidate_media_profile: "static-desktop", candidate_dom_profile: "logical",
           candidate_cable: "real_rails_same_process_async_adapter",
           phases: {} }
save = -> { File.write(File.join(output, "result.json"), JSON.pretty_generate(result)) }

def run_phase(output, label, command, env: {})
  log = File.join(output, "#{label}.log")
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  status = File.open(log, "w") do |io|
    _, process = Process.wait2(Process.spawn(env, "timeout", "--kill-after=10s", "240s", *command, out: io, err: [:child, :out]))
    process
  end
  content = File.read(log)
  summary = content.scan(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips/).last
  code = status.exitstatus || 128 + status.termsig.to_i
  puts "#{label}: exit=#{code}"
  puts content.lines.last(55).join
  { exit_code: code, elapsed_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
    test_summary: summary && %w[runs assertions failures errors skips].zip(summary.map(&:to_i)).to_h,
    log: File.basename(log) }
end

def passed?(phase, expected)
  s = phase[:test_summary]
  phase[:exit_code] == 0 && s && s["runs"] == expected && s["assertions"] > 0 &&
    s.values_at("failures", "errors", "skips") == [0, 0, 0]
end

command = ["bin/rails", "test", spec.fetch(:file), "--seed", "12345"]
command += ["--name", spec[:name]] if spec[:name]
begin
  result[:phases][:setup] = run_phase(output, "setup", ["bin/rails", "db:setup"])
  save.call
  if result[:phases][:setup][:exit_code] != 0
    result[:status] = "setup_blocked"
  else
    shim = File.expand_path("fresh_browser_reset.rb", __dir__)
    result[:phases][:browser] = run_phase(output, "browser", command,
      env: { "RUBYOPT" => [ENV["RUBYOPT"], "-r#{shim}"].compact.join(" ") })
    inventory = "tmp/trusted_types_violations.json"
    FileUtils.cp(inventory, File.join(output, "browser-trusted-types.json")) if File.file?(inventory)
    save.call
    if !passed?(result[:phases][:browser], spec.fetch(:expected))
      result[:status] = "browser_baseline_blocked"
    else
      result[:phases][:reset] = run_phase(output, "reset", ["bin/rails", "db:reset"])
      save.call
      if result[:phases][:reset][:exit_code] != 0
        result[:status] = "database_reset_blocked"
      else
        # This is report-only Chromium telemetry, not a functional assertion.
        # Never synthesize an empty violation report or fake browser/CDP methods.
        marker = "  include TrustedTypesViolationsTestHelper\n"
        abort "Unexpected helper version" unless original.scan(marker).size == 1
        patched = original.sub(marker, "  # Trusted Types inventory not measured in browserless functional candidate.\n")
        patched += <<~RUBY

          require "domstride/rails"
          require #{File.expand_path("fizzy_cable_server.rb", __dir__).inspect}
          DomstrideFizzyCableServer.start!
          class ApplicationSystemTestCase
            include Domstride::RailsSystemTestSupport
            driven_by :domstride
            Capybara.app_host = "http://example.test"
          end
        RUBY
        File.binwrite(helper, patched)
        result[:phases][:candidate] = run_phase(output, "candidate", command,
          env: { "DOMSTRIDE_ASSETS" => "bundle", "DOMSTRIDE_ASSET_WARNINGS" => "direct-eval", "DOMSTRIDE_MEDIA_PROFILE" => "static-desktop", "DOMSTRIDE_DOM_PROFILE" => "logical", "DOMSTRIDE_PERFORMANCE_PROFILE" => "compatible" })
        reference = result[:phases][:browser][:test_summary]
        candidate = result[:phases][:candidate]
        result[:status] = if passed?(candidate, spec.fetch(:expected)) &&
            candidate[:test_summary]["assertions"] == reference["assertions"]
          "functional_subset_passed"
        else
          "candidate_blocked_or_different"
        end
      end
    end
  end
ensure
  File.binwrite(helper, original)
  result[:original_test_unchanged] = Digest::SHA256.file(spec.fetch(:file)).hexdigest == test_digest
  result[:helper_restored] = File.binread(helper) == original
  save.call
  puts JSON.pretty_generate(result)
end
abort "Functional subset not verified" unless result[:status] == "functional_subset_passed" &&
  result[:original_test_unchanged] && result[:helper_restored]

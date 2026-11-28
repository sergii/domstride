require_relative "namespace"
require "fileutils"
require "tmpdir"
require "json"

module Specdrive
  # Bounded, per-worker recording. Never record request bodies, command arguments or results.
  class Recording
    MAX_EVENTS = 1000
    MAX_HTML_BYTES = 16 * 1024 * 1024
    KINDS = %w[mount click fill send_keys assert_text wait_for_text execute_script evaluate_script batch settle advance_time
      node_action.click node_action.set node_action.select_option node_action.unselect_option
      node_action.send_keys node_action.attach_files].freeze

    ASSERTION_READS = %w[find_handles text count current_url node_action.visible_text node_action.all_text node_action.attribute node_action.value node_action.visible node_action.checked node_action.selected node_action.disabled].freeze

    attr_reader :path

    def initialize(directory:, html:, engine:, runtime:)
      FileUtils.mkdir_p(directory, mode: 0o700)
      @path = Dir.mktmpdir("domstride-recording-", File.expand_path(directory))
      @html = html == true
      @events = 0
      @bytes = 0
      @io = File.open(File.join(path, "events.jsonl"), "w", 0o600)
      @io.sync = true
      write(type: "header", schema_version: 1, engine: engine, runtime: runtime, html: @html,
            max_events: MAX_EVENTS, max_html_bytes: MAX_HTML_BYTES)
    end

    def html? = @html

    def accept?(kind, assertion_read: false)
      !@io.closed? && @events < MAX_EVENTS && (KINDS.include?(kind) || (assertion_read && ASSERTION_READS.include?(kind)))
    end

    def record(sequence:, kind:, step:, duration_ms:, passed:, evidence:, assertion_sequence: nil, assertion_read: false)
      return unless accept?(kind, assertion_read: assertion_read)
      @events += 1
      row = { type: "interaction", sequence: sequence, step_sequence: step, kind: kind,
              duration_ms: duration_ms, status: passed ? "passed" : "failed", assertion_sequence: assertion_sequence }
      if evidence.is_a?(Hash)
        %w[before after].each do |phase|
          frame = evidence[phase]
          next unless frame.is_a?(Hash)
          row[phase] = { target_path: frame["target_path"] }
          snapshot = frame["snapshot"]
          next unless html? && snapshot.is_a?(Hash)
          html = snapshot["html"]
          if html.is_a?(String) && @bytes + html.bytesize <= MAX_HTML_BYTES
            name = format("%06d-%s.html", sequence, phase)
            File.open(File.join(path, name), "w", 0o600) { |file| file.write(html) }
            @bytes += html.bytesize
            row[phase][:snapshot] = name
            row[phase][:body_path] = snapshot["body_path"]
          else
            row[phase][:snapshot_omitted] = snapshot["omitted"] || "total_size_limit"
          end
        end
      end
      write(row)
    rescue StandardError => error
      warn "Domstride recording stopped: #{error.class}"
      @io.close rescue nil
    end

    def close
      return if @io.closed?
      write(type: "footer", event_count: @events, html_bytes: @bytes, event_limit_reached: @events >= MAX_EVENTS)
      @io.close
    rescue StandardError => error
      warn "Domstride recording close failed: #{error.class}"
    end

    private

    def write(row)
      @io.puts(JSON.generate(row))
    end
  end
end

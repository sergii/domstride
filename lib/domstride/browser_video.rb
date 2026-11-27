require "tmpdir"
require "fileutils"
require "open3"
require "json"
require_relative "errors"
require_relative "video"

module Domstride
  # Explicit Linux X11 display capture. Never changes DISPLAY or starts a browser.
  # The caller must allocate an isolated display for one test worker.
  class BrowserVideo
    MAX_SECONDS = 120
    MAX_FILE_BYTES = 7_500_000
    STOP_TIMEOUT = 5

    def self.start(item, env: ENV)
      return unless env["DOMSTRIDE_BROWSER_VIDEO"] == "1"
      raise Error, "Browser video requires Linux X11" unless RUBY_PLATFORM.include?("linux")
      display = env.fetch("DOMSTRIDE_VIDEO_DISPLAY")
      unless /\A:\d{1,5}(?:\.0)?\z/.match?(display) && display == env["DISPLAY"]
        raise Error, "Expected explicit local isolated X11 display matching DISPLAY"
      end
      size = env.fetch("DOMSTRIDE_VIDEO_SIZE", "800x600")
      match = /\A(\d{2,4})x(\d{2,4})\z/.match(size)
      unless match && match[1].to_i.between?(160,1920) && match[2].to_i.between?(120,1080) &&
        match[1].to_i.even? && match[2].to_i.even?
        raise Error, "Invalid capture dimensions"
      end
      new(item, display: display, size: size)
    end

    def initialize(item, display:, size:)
      @item = item
      # Prevent overlapping recordings in the same suite directory for this display.
      # Independent suites must allocate independent displays.
      lock_path = File.join(File.dirname(item.path), ".video-display-#{display.delete(':')}.lock")
      @lock = File.open(lock_path, File::RDWR | File::CREAT | File::NOFOLLOW, 0o600)
      raise Error, "Display already recording in this suite" unless @lock.flock(File::LOCK_EX | File::LOCK_NB)
      @directory = Dir.mktmpdir("video-", item.path)
      @file = File.join(@directory, "capture.webm")
      @log = File.join(@directory, "frames.log")
      @clock_offset = Time.now.to_f - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @pid = Process.spawn("ffmpeg", "-hide_banner", "-loglevel", "info", "-nostdin", "-copyts",
        "-f", "x11grab", "-video_size", size, "-framerate", "12", "-i", display,
        "-vf", "showinfo,setpts=PTS-STARTPTS", "-fps_mode", "passthrough",
        "-an", "-c:v", "libvpx", "-deadline", "realtime", "-cpu-used", "8",
        "-b:v", "400k", "-pix_fmt", "yuv420p", "-t", MAX_SECONDS.to_s,
        "-fs", MAX_FILE_BYTES.to_s, "-n", @file,
        in: File::NULL, out: File::NULL, err: [@log, "w", 0o600])
    rescue Exception
      cleanup
      raise
    end

    def finish(status:)
      return unless @pid
      stop
      return if status == "skipped" || status == "pending"
      return unless File.file?(@file) && File.size(@file) > 100
      raise Error, "Recording case changed" unless ReportCase.current.equal?(@item)
      Video.attach(@file, label: "X11 browser display", cues: video_cues)
    ensure
      cleanup
    end

    private

    # X11 input PTS are epoch microseconds, verified from showinfo time_base.
    # setpts normalizes the first frame to zero; monotonic test events are
    # converted using a paired clock sample, with drift rejection.
    def video_cues
      return [] unless File.file?(@log) && File.size(@log) <= 4 * 1024 * 1024
      return [] if ((Time.now.to_f - Process.clock_gettime(Process::CLOCK_MONOTONIC)) - @clock_offset).abs > 0.050
      log = File.read(@log)
      return [] unless log.include?("config in time_base: 1/1000000,")
      frames = log.scan(/\[Parsed_showinfo_0[^\n]*?\bn:\s*(\d+)\s+pts:\s*(\d+)/)
      return [] unless frames.first&.first == "0" && frames.size >= 2
      first, last = frames.first.last.to_i / 1_000_000.0, frames.last.last.to_i / 1_000_000.0
      return [] if (first - (@clock_offset + Process.clock_gettime(Process::CLOCK_MONOTONIC))).abs > MAX_SECONDS + STOP_TIMEOUT + 30
      output, result = Open3.capture2e("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", @file)
      return [] unless result.success?
      duration = Float(JSON.parse(output).fetch("format").fetch("duration"))
      return [] unless duration.finite? && duration.positive?
      @item.video_markers.filter_map do |marker|
        seconds = marker.fetch(:monotonic) + @clock_offset - first
        next unless seconds >= 0 && seconds <= last - first && seconds < duration
        {kind: marker.fetch(:kind), sequence: marker.fetch(:sequence), time_ms: (seconds * 1000).round(1)}
      end
    rescue StandardError
      []
    end

    def reap
      return true unless @pid
      if Process.waitpid(@pid, Process::WNOHANG)
        @pid = nil
        return true
      end
      false
    rescue Errno::ECHILD
      @pid = nil
      true
    end

    def stop
      return if reap
      Process.kill("INT", @pid)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + STOP_TIMEOUT
      until reap
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          Process.kill("KILL", @pid) rescue nil
          Process.waitpid(@pid) rescue nil
          @pid = nil
          raise Error, "Video capture did not finalize"
        end
        sleep 0.025
      end
    rescue Errno::ESRCH
      Process.waitpid(@pid) rescue nil
      @pid = nil
    end

    def cleanup
      if @pid
        Process.kill("KILL", @pid) rescue nil
        Process.waitpid(@pid) rescue nil
        @pid = nil
      end
      FileUtils.remove_entry_secure(@directory) if @directory && File.directory?(@directory)
    ensure
      @directory = nil
      @lock&.close unless @lock&.closed?
      @lock = nil
    end
  end
end

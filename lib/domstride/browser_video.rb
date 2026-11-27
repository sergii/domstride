require "tmpdir"
require "fileutils"
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
      @pid = Process.spawn("ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin",
        "-f", "x11grab", "-video_size", size, "-framerate", "12", "-i", display,
        "-an", "-c:v", "libvpx", "-deadline", "realtime", "-cpu-used", "8",
        "-b:v", "400k", "-pix_fmt", "yuv420p", "-t", MAX_SECONDS.to_s,
        "-fs", MAX_FILE_BYTES.to_s, "-n", @file,
        in: File::NULL, out: File::NULL, err: File::NULL)
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
      Video.attach(@file, label: "X11 browser display")
    ensure
      cleanup
    end

    private

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

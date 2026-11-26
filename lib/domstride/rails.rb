require_relative "capybara"
require "fileutils"
require "tmpdir"

module Domstride
  module RailsSupport
    def self.driver_name(env: ENV)
      case env.fetch("DOMSTRIDE_DRIVER", "domstride")
      when "domstride" then :domstride
      when "browser"
        name = env.fetch("DOMSTRIDE_BROWSER_DRIVER", "selenium_chrome_headless").to_sym
        raise ArgumentError, "Browser driver must differ from Domstride" if name == :domstride
        raise ArgumentError, "Browser driver is not registered: #{name}" unless Capybara.drivers.key?(name)
        name
      else
        raise ArgumentError, "DOMSTRIDE_DRIVER must be domstride or browser"
      end
    end

    # Explicit opt-in. Never save DOM contents by default.
    def self.save_failure(driver, directory:, include_html: false)
      FileUtils.mkdir_p(directory, mode: 0o700)
      path = Dir.mktmpdir("domstride-failure-", File.expand_path(directory))
      File.open(File.join(path, "diagnostics.json"), "w", 0o600) do |file|
        file.write(JSON.pretty_generate(driver.diagnostics))
      end
      if include_html
        File.open(File.join(path, "page.html"), "w", 0o600) { |file| file.write(driver.html) }
      end
      path
    end
  end

  module RailsSystemTestSupport
    def take_failed_screenshot
      driver = page.driver
      return super unless driver.is_a?(Domstride::CapybaraAdapter::Driver)
      return unless !passed? && !skipped? && ENV["DOMSTRIDE_FAILURE_DIR"].to_s != ""
      path = RailsSupport.save_failure(driver, directory: ENV.fetch("DOMSTRIDE_FAILURE_DIR"),
                                      include_html: ENV["DOMSTRIDE_FAILURE_HTML"] == "1")
      warn "Domstride failure diagnostics: #{path}"
    rescue StandardError => error
      # Never mask the original test failure with a diagnostics error.
      raise unless driver.is_a?(Domstride::CapybaraAdapter::Driver)
      warn "Domstride failure diagnostics unavailable: #{error.class}"
    end
  end
end

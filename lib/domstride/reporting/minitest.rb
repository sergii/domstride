require_relative "../namespace"
require "minitest/test"
require_relative "lifecycle"
require_relative "minitest_assertions"
require_relative "capybara_assertions"

module Specdrive
  module Reporting
    module Minitest
      def self.install!(directory:, html: false)
        raise ArgumentError, "Minitest report already installed" if @installed
        MinitestAssertions.install!
        CapybaraAssertions.install!
        root = File.expand_path(directory)
        wrapper = Module.new do
          define_method(:run) do |*args, **kwargs, &block|
            item = Lifecycle.start(directory: root, name: "#{self.class.name}##{name}",
              html: html, framework: "minitest")
            result = nil
            begin
              result = super(*args, **kwargs, &block)
            ensure
              status = if result.nil?
                "unknown"
              elsif result.skipped?
                "skipped"
              elsif result.passed?
                "passed"
              else
                "failed"
              end
              Lifecycle.finish(item, status: status, assertions: result&.assertions)
            end
            result
          end
        end
        ::Minitest::Test.prepend(wrapper)
        @installed = true
      end
    end
  end
end

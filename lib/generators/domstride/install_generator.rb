require "rails/generators"

module Domstride
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Install an opt-in Domstride Rails system test base without replacing existing tests."

      def create_test_base
        template "domstride_system_test_case.rb.tt", "test/domstride_system_test_case.rb"
      end

      def show_next_steps
        say "Run bundle exec domstride setup, then use DomstrideSystemTestCase for selected system tests."
        say "Set DOMSTRIDE_DRIVER=browser for an explicit browser run. No existing test base is changed."
      end
    end
  end
end

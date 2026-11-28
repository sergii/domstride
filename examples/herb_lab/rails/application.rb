# Only boot this standalone synthetic application in an isolated test process.
ENV["RAILS_ENV"] ||= "test"
require "rails"
require "action_controller/railtie"
require "reactionview"
require "herb/engine/visitors/source_attribution_visitor"

raise "Source attribution is test-only" unless Rails.env.test?

ReActionView.configure do |config|
  config.intercept_erb = true
  config.debug_mode = false
  config.slots = false
  config.dev_server = false
  config.external_template_mode = :compile
  # The fixture's inline JS is deliberate; this is not a validator test.
  config.validation_mode = :none
  if ENV.fetch("HERB_SOURCE_ATTRIBUTION", "1") == "1"
    config.engine.visitors.use(Herb::Engine::SourceAttributionVisitor.new)
  end
end

class HerbLabApplication < Rails::Application
  config.root = File.expand_path(__dir__)
  config.load_defaults 8.1
  config.eager_load = false
  config.secret_key_base = "synthetic-fixture-only-" * 8
  config.logger = ActiveSupport::Logger.new($stderr)
  config.hosts.clear
  config.consider_all_requests_local = false
  config.action_dispatch.show_exceptions = :none
end

class PetsController < ActionController::Base
  def index
    @can_archive = params[:archive] == "1"
    @pets = %w[Milo Luna]
    render template: "pets/index", layout: false
  end
end

HerbLabApplication.initialize!
Rails.application.routes.draw do
  get "/pets", to: "pets#index"
end

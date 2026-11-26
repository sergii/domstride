require "rails"
require "action_controller/railtie"
require "active_record"
require "tmpdir"

if ENV["UPSTREAM_REFERENCE"] == "1"
  require "action_cable/engine"
  require "active_job/railtie"
  require "propshaft"
  require "importmap-rails"
  require "turbo-rails"
  require "stimulus-rails"
end

module ExpenseReference
  class Application < Rails::Application
    if ENV["UPSTREAM_REFERENCE"] == "1"
      config.root = File.join(__dir__, "upstream_app")
      config.assets.paths << File.join(config.root, "node_modules/@hotwired/turbo/dist")
      config.assets.paths << File.join(config.root, "node_modules/@hotwired/stimulus/dist")
      config.active_job.queue_adapter = :test
    end
    config.eager_load = false
    config.secret_key_base = "reference-app-test-only-secret-" * 4
    config.hosts.clear
    config.logger = ActiveSupport::Logger.new(IO::NULL)
    config.consider_all_requests_local = true
    config.session_store :cookie_store, key: "_domstride_reference"
  end

  class Expense < ActiveRecord::Base
    validates :description, presence: true
    validates :amount, numericality: { only_integer: true, greater_than: 0 }
    validates :user_id, presence: true
  end

  class ExpensesController < ActionController::Base
    protect_from_forgery with: :exception
    self.forgery_protection_origin_check = true
    rescue_from ActionController::InvalidAuthenticityToken do
      render plain: "Invalid CSRF token", status: :unprocessable_entity
    end

    def index
      javascript = ENV["UPSTREAM_REFERENCE"] == "1" ? "" : File.read(File.join(__dir__, "application.bundle.js"))
      render inline: <<~ERB, locals: { javascript: javascript }
        <!doctype html>
        <html><head><title>Expense Lab</title><%= csrf_meta_tags %></head><body>
          <h1>Expense Lab</h1>
          <output id="identity"><%= session[:user_id] ? "Signed in" : "Anonymous" %></output>
          <form action="/login" method="post" data-turbo-stream>
            <input type="hidden" name="authenticity_token" value="<%= form_authenticity_token %>">
            <label>Email <input id="email" name="email"></label>
            <label>Password <input id="password" name="password" type="password"></label>
            <button id="login">Sign in</button>
          </form>
          <section data-controller="expense" id="expense">
            <button id="add" data-action="expense#add">Add 25 EUR</button>
            <button id="fail" data-action="expense#fail">Fail</button>
            <output id="total" data-expense-target="total">0</output>
          </section>
          <turbo-frame id="details">
            <a id="details-link" href="/details">Load details</a>
          </turbo-frame>
          <turbo-frame id="stream-frame">
            <a id="approve-link" href="/approve" data-turbo-stream>Approve</a>
          </turbo-frame>
          <output id="status">Pending</output>
          <form action="/expenses" method="post" data-turbo-stream>
            <input type="hidden" name="authenticity_token" value="<%= form_authenticity_token %>">
            <label>Description <input id="description" name="description"></label>
            <label>Amount <input id="amount" name="amount"></label>
            <button id="save">Save expense</button>
          </form>
          <output id="result">Not saved</output>
          <turbo-frame id="latest">
            <a id="latest-link" href="/expenses/latest">Latest expense</a>
          </turbo-frame>
          <script><%= raw javascript %></script>
        </body></html>
      ERB
    end

    def login
      if params[:email] == "tester@example.test" && params[:password] == "fixture-password"
        session[:user_id] = 1
        stream("identity", "Signed in")
      else
        stream("identity", "Invalid credentials", status: :unprocessable_entity)
      end
    end

    def create
      return stream("result", "Unauthorized", status: :unauthorized) unless session[:user_id]
      expense = Expense.new(user_id: session[:user_id], description: params[:description], amount: params[:amount])
      if expense.save
        stream("result", "Saved")
      else
        stream("result", "Invalid expense", status: :unprocessable_entity)
      end
    end

    def latest
      expense = Expense.where(user_id: session[:user_id]).order(id: :desc).first
      render inline: '<turbo-frame id="latest"><p id="persisted"><%= value %></p></turbo-frame>', locals: { value: expense ? "#{expense.description}: #{expense.amount}" : "No expense" }
    end

    def details
      render inline: '<turbo-frame id="details"><p id="receipt">Receipt #42</p></turbo-frame>'
    end

    def approve
      stream("status", "Approved")
    end

    private

    def stream(target, value, status: :ok)
      render inline: '<turbo-stream action="update" target="<%= target %>"><template><%= value %></template></turbo-stream>', locals: { target: target, value: value }, content_type: "text/vnd.turbo-stream.html", status: status
    end
  end
end

ExpenseReference::Application.initialize!
ExpenseReference::DB_DIR = Dir.mktmpdir("domstride-reference")
at_exit { FileUtils.remove_entry(ExpenseReference::DB_DIR) if File.directory?(ExpenseReference::DB_DIR) }
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(ExpenseReference::DB_DIR, "reference.sqlite3"))
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :expenses do |t|
    t.integer :user_id, null: false
    t.string :description, null: false
    t.integer :amount, null: false
  end
end
Rails.application.routes.draw do
  root to: "expense_reference/expenses#index"
  get "/details", to: "expense_reference/expenses#details"
  get "/approve", to: "expense_reference/expenses#approve"
  post "/login", to: "expense_reference/expenses#login"
  post "/expenses", to: "expense_reference/expenses#create"
  get "/expenses/latest", to: "expense_reference/expenses#latest"
end

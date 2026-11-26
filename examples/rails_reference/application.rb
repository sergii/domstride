require "rails"
require "action_controller/railtie"

module ExpenseReference
  class Application < Rails::Application
    config.eager_load = false
    config.secret_key_base = "reference-app-test-only-secret-" * 4
    config.hosts.clear
    config.logger = ActiveSupport::Logger.new(IO::NULL)
    config.consider_all_requests_local = true
  end

  class ExpensesController < ActionController::Base
    def index
      javascript = File.read(File.join(__dir__, "application.bundle.js"))
      render inline: <<~ERB, locals: { javascript: javascript }
        <!doctype html>
        <html><head><title>Expense Lab</title></head><body>
          <h1>Expense Lab</h1>
          <section data-controller="expense" id="expense">
            <button id="add" data-action="expense#add">Add 25 EUR</button>
            <output id="total" data-expense-target="total">0</output>
          </section>
          <turbo-frame id="details">
            <a id="details-link" href="/details">Load details</a>
          </turbo-frame>
          <turbo-frame id="stream-frame">
            <a id="approve-link" href="/approve" data-turbo-stream>Approve</a>
          </turbo-frame>
          <output id="status">Pending</output>
          <script><%= raw javascript %></script>
        </body></html>
      ERB
    end

    def details
      render inline: '<turbo-frame id="details"><p id="receipt">Receipt #42</p></turbo-frame>'
    end

    def approve
      render inline: '<turbo-stream action="update" target="status"><template>Approved</template></turbo-stream>', content_type: "text/vnd.turbo-stream.html"
    end
  end
end

ExpenseReference::Application.initialize!
Rails.application.routes.draw do
  root to: "expense_reference/expenses#index"
  get "/details", to: "expense_reference/expenses#details"
  get "/approve", to: "expense_reference/expenses#approve"
end

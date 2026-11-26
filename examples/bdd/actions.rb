ENV["RAILS_ENV"] = "test"
require_relative "../rails_reference/application"
require "domstride/bdd"

module ExpenseBDD
  include Domstride::BDD::World

  def open_expense_application
    domstride_step(kind: :visit) { |page| page.visit("/") }
    domstride_page.find(:css, "#expense[data-ready=true] #total", exact_text: "0")
  end

  def add_amount
    domstride_step(kind: :click) { |page| page.find(:css, "#add").click }
  end

  def sign_in
    domstride_step(kind: :fill) do |page|
      page.find(:css, "#email").set("tester@example.test")
      page.find(:css, "#password").set("fixture-password")
      page.find(:css, "#login").click
    end
  end

  def enter_expense(description, amount)
    domstride_step(kind: :fill) do |page|
      page.find(:css, "#description").set(description)
      page.find(:css, "#amount").set(amount)
      page.find(:css, "#save").click
    end
  end

  def check_output(id, text)
    domstride_step(kind: :assert) { |page| page.find(:css, "##{id}", exact_text: text) }
  end

  def check_persisted(description, amount)
    domstride_step(kind: :assert) do |page|
      raise "Expense persistence mismatch" unless ExpenseReference::Expense.where(description: description, amount: Integer(amount), user_id: 1).count == 1
      page.visit("/")
      page.find(:css, "#latest-link").click
      page.find(:css, "#persisted", exact_text: "#{description}: #{amount}")
    end
  end
end

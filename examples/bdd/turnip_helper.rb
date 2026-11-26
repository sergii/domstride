require_relative "actions"

module ExpenseTurnipSteps
  include ExpenseBDD

  step "I open the expense application" do
    open_expense_application
  end

  step "I add an amount using Stimulus" do
    add_amount
  end

  step "I sign in" do
    sign_in
  end

  step "I enter an expense :description with amount :amount" do |description, amount|
    enter_expense(description, amount)
  end

  step "the identity is :text" do |text|
    check_output("identity", text)
  end

  step "the total is :text" do |text|
    check_output("total", text)
  end

  step "the result is :text" do |text|
    check_output("result", text)
  end

  step "the expense :description with amount :amount is persisted" do |description, amount|
    check_persisted(description, amount)
  end
end

RSpec.configure do |config|
  config.raise_error_for_unimplemented_steps = true
  config.include ExpenseTurnipSteps, turnip: true, domstride: true
  config.before(:each, turnip: true, domstride: true) do
    ExpenseReference::Expense.delete_all
    start_domstride_scenario(app: Rails.application)
  end
  config.after(:each, turnip: true, domstride: true) do |example|
    finish_domstride_scenario(failed: !example.exception.nil?)
  end
end

require_relative "../../actions"

World(ExpenseBDD)

Before("@domstride") do
  ExpenseReference::Expense.delete_all
  start_domstride_scenario(app: Rails.application)
end

After("@domstride") do |scenario|
  finish_domstride_scenario(failed: scenario.failed?)
end

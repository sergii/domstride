require_relative "../../actions"

World(ExpenseBDD)

Before("@domstride") do
  ExpenseReference::Expense.delete_all
  start_domstride_scenario(app: Rails.application)
end

After("@domstride") do |scenario|
  finish_domstride_scenario(failed: scenario.failed?)
end

if ENV["DOMSTRIDE_BDD_REPORT_DIR"]
  require "domstride/reporting/cucumber"
  InstallPlugin do |config, _registry|
    Domstride::Reporting::Cucumber.install!(config, directory: ENV.fetch("DOMSTRIDE_BDD_REPORT_DIR"), step_text: true)
  end
end

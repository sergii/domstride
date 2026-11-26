require_relative "scenario"

RSpec.describe "Rails reference interaction" do
  it "persists a valid expense and rejects invalid input" do
    expect do
      Domstride::Session.open(app: Rails.application) { |page| ExpenseScenario.run(page) }
    end.to change(ExpenseReference::Expense, :count).by(1)
  end
end

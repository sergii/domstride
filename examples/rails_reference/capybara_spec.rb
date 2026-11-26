require_relative "capybara_scenario"

RSpec.describe "Domstride Capybara driver" do
  let(:page) { Capybara::Session.new(:domstride, Rails.application) }
  after { page.driver.quit }

  it "runs a stateful Rails workflow using Capybara" do
    expect { CapybaraExpenseScenario.run(page) }.to change(ExpenseReference::Expense, :count).by(1)
  end

  it "isolates cookies when reset" do
    CapybaraExpenseScenario.run(page)
    page.reset!
    page.visit("/")
    expect(page).to have_css("#identity", text: "Anonymous")
  end

  it "supports scoped CSS, dynamic text and document HTML" do
    page.visit("/")
    section = page.find(:css, "#expense")
    section.find(:css, "#add").click
    expect(section.find(:css, "#total", exact_text: "25").text).to eq("25")
    expect(page.html).to include("Expense Lab")
  end

  it "rejects coordinate clicks rather than silently ignoring them" do
    page.visit("/")
    expect { page.find(:css, "#add").click(x: 1, y: 1) }.to raise_error(Capybara::NotSupportedByDriverError)
  end

  it "supports standard XPath-based Capybara field and button selectors on jsdom" do
    skip "XPath compatibility not established on Happy DOM" if ENV["DOMSTRIDE_ENGINE"] == "happy-dom"
    page.visit("/")
    page.fill_in("Email", with: "tester@example.test")
    page.fill_in("Password", with: "fixture-password")
    page.click_button("Sign in")
    expect(page).to have_css("#identity", text: "Signed in")
  end
end

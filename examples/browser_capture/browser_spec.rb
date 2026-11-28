require "domstride/reporting/rspec"
require "capybara/rspec"
require "selenium-webdriver"
require "capybara/cuprite"

driver = ENV.fetch("BROWSER_DRIVER")
case driver
when "selenium"
  Capybara.register_driver(:video_browser) do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    options.binary = ENV.fetch("CHROME_PATH")
    options.add_argument("--window-size=800,600")
    options.add_argument("--window-position=0,0")
    options.add_argument("--no-sandbox")
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
  end
when "cuprite"
  Capybara.register_driver(:video_browser) do |app|
    Capybara::Cuprite::Driver.new(app, headless: false, window_size: [800,600],
      browser_path: ENV.fetch("CHROME_PATH"), browser_options: {"no-sandbox" => nil, "window-position" => "0,0"})
  end
else
  raise "Unknown test driver"
end
Capybara.server = :puma, {Silent: true}
Domstride::Reporting::RSpec.install!(directory: ENV.fetch("REPORT_TEST_DIRECTORY"))

RSpec.describe "real browser video" do
  include Capybara::RSpecMatchers
  let(:app) do
    ->(_) { [200, {"content-type"=>"text/html"}, [<<~HTML]] }
      <html><body style="background:#e8f5e9;font:24px sans-serif">
      <h1>Expense</h1><label for="amount">Amount</label><input id="amount" name="amount" type="text">
      <button onclick="document.querySelector('h1').textContent='Saved'">Save</button>
      </body></html>
    HTML
  end
  let(:page) { Capybara::Session.new(:video_browser, app) }

  after do
    page.driver.quit
  end

  def save_expense
    page.visit("/expenses/new")
    page.fill_in("Amount", with: "25")
    page.click_button("Save")
    sleep 0.7 # Ensure multiple real frames in this synthetic recording fixture.
  end

  it("passed case") do
    save_expense
    expect(page).to have_text("Saved")
  end

  it("failed case") do
    save_expense
    expect(page).to have_text("Approved", wait: 0)
  end
end

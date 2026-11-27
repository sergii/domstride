require "domstride"
require "domstride/reporting/rspec"
require "domstride/capybara"
require "capybara/rspec"

Domstride::Reporting::RSpec.install!(directory: ENV.fetch("REPORT_TEST_DIRECTORY"), html: true)

RSpec.describe "report lifecycle" do
  include Capybara::RSpecMatchers
  it("passing example") do
    Domstride::Session.open { |page| page.mount_html("<p>Passed</p>") }
    expect(1).to eq(1)
    expect { expect(1).to eq(2) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
  end
  it("failed example") do
    Domstride::Session.open { |page| page.mount_html("<p>Command succeeded</p>") }
    expect(1).to eq(2)
  end
  it("aggregated failure") do
    aggregate_failures do
      expect(1).to eq(2)
      expect(1).not_to eq(2)
      expect(1).not_to eq(1)
    end
  end
  it("DOM assertion failure") do
    app = ->(_) { [200, {"content-type"=>"text/html"}, ["<p id='result'>Actual</p>"]] }
    page = Capybara::Session.new(:domstride, app)
    begin
      page.visit("/")
      expect(page).to have_selector("#result", text: "Expected", wait: 0)
    ensure
      page.driver.quit
    end
  end
  it("skipped example", skip: true) { raise "must not execute" }
  it("pending example", pending: true) { expect(1).to eq(2) }
  it("fixed pending example", pending: true) { expect(1).to eq(1) }
  context "setup failure" do
    before { raise "private setup error" }
    it("fails before body") { raise "must not execute" }
  end
  context "teardown failure" do
    after { raise "private teardown error" }
    it("fails after body") { expect(true).to eq(true) }
  end
end

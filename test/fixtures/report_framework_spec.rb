require "domstride"
require "domstride/reporting/rspec"

Domstride::Reporting::RSpec.install!(directory: ENV.fetch("REPORT_TEST_DIRECTORY"), html: true)

RSpec.describe "report lifecycle" do
  it("passing example") do
    Domstride::Session.open { |page| page.mount_html("<p>Passed</p>") }
    expect(1).to eq(1)
  end
  it("failed example") do
    Domstride::Session.open { |page| page.mount_html("<p>Command succeeded</p>") }
    expect(1).to eq(2)
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

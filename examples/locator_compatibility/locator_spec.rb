require "specdrive/capybara"
require "json"
require "capybara/cuprite"
require "selenium-webdriver"

target = ENV.fetch("LOCATOR_ENGINE", "jsdom")
Capybara.threadsafe = true
Capybara.server = :puma, { Silent: true }

driver = case target
when "jsdom", "jsdom31", "happy-dom"
  ENV["SPECDRIVE_ENGINE"] = target
  :specdrive
when "selenium"
  Capybara.register_driver(:locator_selenium) do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    options.binary = ENV["CHROME_PATH"] if ENV["CHROME_PATH"]
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
  end
  :locator_selenium
when "cuprite"
  Capybara.register_driver(:locator_cuprite) do |app|
    Capybara::Cuprite::Driver.new(app, headless: true, browser_path: ENV["CHROME_PATH"],
      browser_options: { "no-sandbox" => nil, "disable-dev-shm-usage" => nil })
  end
  :locator_cuprite
else
  raise ArgumentError, "Unknown locator engine: #{target}"
end

RSpec.describe "Locator compatibility (#{target})" do
  let(:html) { File.read(File.join(__dir__, "fixture.html")) }
  let(:app) { ->(_) { [200, { "content-type" => "text/html; charset=utf-8" }, [html]] } }
  let(:page) { Capybara::Session.new(driver, app) }

  before do
    page.config.default_max_wait_time = 1
    page.config.enable_aria_label = false
    page.config.test_id = nil
    page.visit("/")
  end
  after { page.driver.quit }

  it "fills explicit HTML labels" do
    page.fill_in("Pet name", with: "Milo", exact: true)
    expect(page.find(:css, "#pet-name").value).to eq("Milo")
  end

  it "fills wrapping HTML labels" do
    page.fill_in("Notes", with: "Friendly", exact: true)
    expect(page.find(:css, "#pet-notes").value).to eq("Friendly")
  end

  it "locates fields by HTML id and name" do
    page.fill_in("pet-name", with: "Milo", exact: true)
    page.fill_in("pet_name", with: "Luna", exact: true)
    expect(page.find(:css, "#pet-name").value).to eq("Luna")
  end

  it "clicks a native text button" do
    page.click_button("Save", exact: true)
    expect(page.find(:css, "#result").text).to eq("Saved")
  end

  it "does not use aria-label when disabled" do
    expect { page.find_field("Contact phone", exact: true, wait: 0) }.to raise_error(Capybara::ElementNotFound)
    expect { page.find_button("Remove pet", exact: true, wait: 0) }.to raise_error(Capybara::ElementNotFound)
  end

  it "fills an ARIA-only field when enabled" do
    page.config.enable_aria_label = true
    page.fill_in("Contact phone", with: "123", exact: true)
    expect(page.find(:css, "#aria-only").value).to eq("123")
  end

  it "clicks an accessible icon button when enabled" do
    page.config.enable_aria_label = true
    page.click_button("Remove pet", exact: true)
    expect(page.find(:css, "#result").text).to eq("Removed")
  end

  it "observes native label and aria-label lookup without claiming accessible-name precedence" do
    page.config.enable_aria_label = true
    observations = ["Visible name", "Accessible name"].to_h do |label|
      found = page.has_field?(label, exact: true, wait: 0)
      expect(page.find_field(label, exact: true)["id"]).to eq("native-name") if found
      [label, found]
    end
    puts "LOCATOR_PROBE #{JSON.generate(probe: "label_precedence", observed: observations)}"
  end

  it "probes aria-labelledby support without assuming accessible-name computation" do
    page.config.enable_aria_label = true
    supported = page.has_field?("Contact email", exact: true, wait: 0)
    expect(page.find_field("Contact email", exact: true)["id"]).to eq("labelled-by") if supported
    puts "LOCATOR_PROBE #{JSON.generate(probe: "aria_labelledby", supported: supported)}"
    expect(page.find(:css, "#labelled-by")["aria-labelledby"]).to eq("contact-description")
  end

  it "distinguishes explicit role attribute lookup from native button lookup" do
    expect(page.find(:css, '[role="status"]').text).to eq("Ready")
    expect(page.find_button("Save", exact: true)["id"]).to eq("save")
    # CSS role attributes do not compute implicit roles or accessible names.
  end

  it "does not use test IDs when unconfigured" do
    expect { page.find_field("adoption-name", exact: true, wait: 0) }.to raise_error(Capybara::ElementNotFound)
  end

  it "fills configured test IDs" do
    page.config.test_id = "data-testid"
    page.fill_in("adoption-name", with: "Milo", exact: true)
    expect(page.find(:css, "#localized").value).to eq("Milo")
  end

  it "uses a caller-selected custom test ID attribute" do
    page.config.test_id = "data-qa"
    page.fill_in("adoption-custom", with: "Luna", exact: true)
    expect(page.find(:css, "#localized").value).to eq("Luna")
    expect { page.find_field("adoption-name", exact: true, wait: 0) }.to raise_error(Capybara::ElementNotFound)
  end

  it "rejects ambiguous test IDs and resolves scoped matches" do
    page.config.test_id = "data-testid"
    expect { page.find_field("duplicate-name", exact: true, match: :one, wait: 0) }.to raise_error(Capybara::Ambiguous)
    page.find(:css, "#second").fill_in("duplicate-name", with: "Luna", exact: true)
    expect(page.find(:css, "#first-name").value).to eq("")
    expect(page.find(:css, "#second-name").value).to eq("Luna")
  end

  it "does not treat hidden or disabled controls as ordinary actionable fields" do
    page.config.test_id = "data-testid"
    expect { page.find_field("hidden-name-target", exact: true, wait: 0) }.to raise_error(Capybara::ElementNotFound)
    expect { page.find_field("disabled-name-target", exact: true, wait: 0) }.to raise_error(Capybara::ElementNotFound)
    expect(page.find_field("hidden-name-target", exact: true, visible: :all)["id"]).to eq("hidden-name")
    expect(page.find_field("disabled-name-target", exact: true, disabled: true)).to be_disabled
  end

  it "retains test identity when a label is translated" do
    page.config.test_id = "data-testid"
    page.click_button("Translate", exact: true)
    expect { page.find_field("Name", exact: true, wait: 0) }.to raise_error(Capybara::ElementNotFound)
    expect(page.find_field("Nom", exact: true)["id"]).to eq("localized")
    page.fill_in("adoption-name", with: "Milo", exact: true)
    expect(page.find(:css, "#localized").value).to eq("Milo")
  end

  it "finds dynamically inserted controls" do
    page.config.test_id = "data-testid"
    page.click_button("Add field", exact: true)
    page.fill_in("new-name", with: "Milo", exact: true)
    expect(page.find_field("New name", exact: true).value).to eq("Milo")
  end

  it "resolves a fresh target after dynamic replacement" do
    page.config.test_id = "data-testid"
    page.click_button("Replace field", exact: true)
    expect(page.find_field("adoption-name", exact: true).value).to eq("replaced")
    page.fill_in("adoption-name", with: "Fresh", exact: true)
    expect(page.find(:css, "#localized").value).to eq("Fresh")
  end
end

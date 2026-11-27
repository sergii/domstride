require_relative "../../lib/domstride/capybara"

RSpec.describe "Domstride Capybara compatibility contract" do
  let(:html) do
    <<~HTML
      <!doctype html><html><body>
        <section id="scope">
          <label>Name <input id="name" value="initial"></label>
          <label>Notes <textarea id="notes"></textarea></label>
          <label>Accept <input id="accept" type="checkbox"></label>
          <label>Basic <input id="basic" type="radio" name="tier" checked></label>
          <label>Premium <input id="premium" type="radio" name="tier"></label>
          <input id="disabled" disabled>
          <input id="readonly" readonly value="fixed">
          <input id="upload" type="file">
          <p id="hidden" hidden>Hidden</p>
          <p id="text">Visible <span hidden>secret</span> text</p>
          <button id="replace" onclick="document.querySelector('#name').outerHTML = '<input id=name value=replaced>'">Replace</button>
          <button id="async" onclick="setTimeout(() => document.querySelector('#result').textContent = 'Done', 25)">Async</button>
          <output id="result">Pending</output>
          <output id="events"></output>
          <script>
            document.querySelector("#scope").addEventListener("change", e => {
              document.querySelector("#events").textContent += e.target.id + ";";
            });
          </script>
        </section>
      </body></html>
    HTML
  end
  let(:app) { ->(_) { [200, { "content-type" => "text/html" }, [html]] } }
  let(:page) { Capybara::Session.new(:domstride, app) }
  before { page.visit("/") }
  after { page.driver.quit }

  it "supports current URL, document HTML, refresh and scoped CSS" do
    expect(page.current_url).to eq("http://example.test/")
    expect(page.html).to include("Pending")
    page.find(:css, "#scope").find(:css, "#name").set("Changed")
    expect(page.find(:css, "#name").value).to eq("Changed")
    page.refresh
    expect(page.find(:css, "#name").value).to eq("initial")
  end

  it "updates text fields and dispatches change events" do
    page.find(:css, "#name").set("Ada")
    page.find(:css, "#notes").set("Lunch")
    expect(page.find(:css, "#name").value).to eq("Ada")
    expect(page.find(:css, "#notes").value).to eq("Lunch")
    expect(page).to have_css("#events", exact_text: "name;notes;")
  end

  it "sets checkbox state idempotently with native activation events" do
    checkbox = page.find(:css, "#accept")
    expect(checkbox).not_to be_checked
    checkbox.set(true)
    checkbox.set(true)
    expect(checkbox).to be_checked
    checkbox.set(false)
    expect(checkbox).not_to be_checked
    expect(page).to have_css("#events", exact_text: "accept;accept;")
  end

  it "selects radios and preserves group exclusivity" do
    premium = page.find(:css, "#premium")
    premium.set(true)
    expect(premium).to be_checked
    expect(page.find(:css, "#basic")).not_to be_checked
    expect(page).to have_css("#events", exact_text: "premium;")
    expect { premium.set(false) }.to raise_error(Capybara::NotSupportedByDriverError)
  end

  it "preserves visibility, text and disabled state queries" do
    expect(page).to have_css("#hidden", visible: :hidden)
    expect(page).not_to have_css("#hidden", visible: :visible, wait: 0)
    expect(page.find(:css, "#text").text(:all)).to include("secret")
    expect(page.find(:css, "#text").text(:visible)).not_to include("secret")
    expect(page.find(:css, "#disabled")).to be_disabled
    expect { page.find(:css, "#disabled").set("No") }.to raise_error(Domstride::Error)
    expect { page.find(:css, "#readonly").set("No") }.to raise_error(Domstride::Error)
  end

  it "retries asynchronous DOM queries" do
    page.find(:css, "#async").click
    expect(page).to have_css("#result", exact_text: "Done")
  end

  it "rejects a detached raw handle" do
    raw = page.driver.find_css("#name").first
    page.find(:css, "#replace").click
    expect { raw.value }.to raise_error(Domstride::CapybaraAdapter::StaleElement)
    expect(page.find(:css, "#name").value).to eq("replaced")
  end

  it "does not reuse old handles when resetting the worker" do
    raw = page.driver.find_css("#name").first
    page.reset!
    page.visit("/")
    fresh = page.driver.find_css("#name").first
    expect(raw).not_to eq(fresh)
    expect { raw.value }.to raise_error(Domstride::CapybaraAdapter::StaleElement)
    expect { raw.find_css("span") }.to raise_error(Domstride::CapybaraAdapter::StaleElement)
    expect(fresh.value).to eq("initial")
  end

  it "rejects unsupported geometry explicitly" do
    expect { page.find(:css, "#name").obscured? }.to raise_error(Capybara::NotSupportedByDriverError)
    expect { page.find(:css, "#replace").click(x: 1, y: 1) }.to raise_error(Capybara::NotSupportedByDriverError)
  end

  it "supports standard Capybara XPath form locators on jsdom" do
    skip "Happy DOM XPath not established" if page.driver.worker.settings[:engine] == "happy-dom"
    page.fill_in("Name", with: "Ada")
    page.check("Accept")
    page.choose("Premium")
    expect(page).to have_checked_field("Accept")
    expect(page).to have_checked_field("Premium")
    expect(page).to have_field("Name", with: "Ada")
  end
end

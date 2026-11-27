require_relative "capybara_scenario"

RSpec.describe "Query metadata prefetch" do
  let(:page) { Capybara::Session.new(:domstride, Rails.application) }
  let(:worker) { page.driver.worker }
  after { page.driver.quit }

  before do
    worker.mount_html(<<~HTML)
      <main id="scope">
        <p class="item" id="visible">Alpha <span hidden>Invisible</span> Beta</p>
        <p class="item" id="hidden" hidden>Alpha Beta</p>
        <p class="item" id="css-hidden" style="display: none">Other</p>
        <button id="toggle" onclick="document.querySelector('#visible').hidden = true; document.querySelector('#hidden').hidden = false">Toggle</button>
        <button id="remove" onclick="document.querySelector('#visible').remove()">Remove</button>
        <button id="later" onclick="setTimeout(() => document.querySelector('#hidden').hidden = false, 30)">Later</button>
      </main>
      <p class="item" id="outside">Outside</p>
    HTML
  end

  it "preserves scoped CSS and all visibility modes" do
    scope = page.find(:css, "#scope")
    expect(scope.all(:css, ".item", visible: :visible).map { |n| n[:id] }).to eq(["visible"])
    expect(scope.all(:css, ".item", visible: :hidden).map { |n| n[:id] }).to eq(["hidden", "css-hidden"])
    expect(scope.all(:css, ".item", visible: :all).map { |n| n[:id] }).to eq(["visible", "hidden", "css-hidden"])
  end

  it "preserves Ruby exact text, regexp, count and custom filters" do
    expect(page).to have_css(".item", exact_text: "Alpha  Beta", normalize_ws: false, count: 1)
    expect(page).to have_css(".item", text: /Alpha\s+Beta/, count: 1)
    expect(page).to have_css(".item", text: "Invisible", visible: :all, count: 1)
    expect(page.all(:css, ".item", visible: :all) { |node| node[:id] == "outside" }.size).to eq(1)
  end

  it "keeps public visibility reads live after a mutation" do
    element = page.find(:css, "#visible")
    expect(element.visible?).to be(true)
    page.find(:css, "#toggle").click
    expect(element.visible?).to be(false)
    expect(page).to have_css("#hidden", visible: true)
    expect(page).to have_css("#visible", visible: :hidden)
  end

  it "keeps asynchronous query retries" do
    page.find(:css, "#later").click
    expect(page).to have_css("#hidden", visible: true, wait: 1)
  end

  it "rejects detached handles rather than reusing initial visibility" do
    node = page.driver.find_css("#visible", uses_visibility: true).first
    page.find(:css, "#remove").click
    expect { node.visible? }.to raise_error(Domstride::CapybaraAdapter::StaleElement)
  end

  it "prefetches visibility only for queries that request it" do
    node = page.driver.find_css("#visible", uses_visibility: true).first
    if ENV["DOMSTRIDE_QUERY_PREFETCH"] == "1"
      expect(node.initial_cache).to include(visible: true, tag_name: "p")
      expect(page.driver.find_css("#hidden", uses_visibility: true).first.initial_cache).to include(visible: false)
    else
      expect(node.initial_cache).to eq({})
    end
    expect(page.driver.find_css("#hidden").first.initial_cache).not_to have_key(:visible)
  end
end

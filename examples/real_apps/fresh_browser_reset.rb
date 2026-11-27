# Discovery-only workaround for the Chrome CDP wildcard-origin reset error.
# Never load in the product or the first unmodified browser baseline.
require "capybara"
require "selenium-webdriver"
require "capybara/selenium/driver"

module DomstrideDiscoveryFreshBrowserReset
  def reset!
    # A fresh browser profile is stricter isolation than clearing selected storage.
    # Do not swallow assertion failures or errors from quitting the browser.
    quit if @browser
  end
end

Capybara::Selenium::Driver::ChromeDriver.prepend(DomstrideDiscoveryFreshBrowserReset)
warn "Discovery browser retry: fresh Chrome session per test; timings are not comparable."

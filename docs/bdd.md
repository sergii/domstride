# BDD integration

Domstride works with Cucumber and Turnip via the same Capybara driver. Neither framework is a runtime dependency. Keep framework dependency resolution separate in the reference harness (Cucumber 10.2.0, Turnip 4.4.1).

## Cucumber

In features/support/domstride.rb:

```ruby
require "domstride/bdd"

World(Domstride::BDD::World)

Before("@domstride") do
  start_domstride_scenario(app: Rails.application)
end

After("@domstride") do |scenario|
  finish_domstride_scenario(failed: scenario.failed?)
end
```

Tag the scenarios you want to run with this driver. Use domstride_page or wrap an action in domstride_step(kind: :click) { |page| ... }. Each scenario has a separate Capybara session. Existing untagged scenarios are not modified. The application's own database cleaning, fixtures and Rails boot remain its responsibility.

## Turnip / RSpec

```ruby
require "domstride/bdd"

RSpec.configure do |config|
  config.include Domstride::BDD::World, turnip: true, domstride: true
  config.before(:each, turnip: true, domstride: true) do
    start_domstride_scenario(app: Rails.application)
  end
  config.after(:each, turnip: true, domstride: true) do |example|
    finish_domstride_scenario(failed: !example.exception.nil?)
  end
end
```

Load Turnip via -r turnip/rspec and tag the feature @domstride. Use framework-native step definitions and the same Ruby actions. Explicit driver selection via DOMSTRIDE_DRIVER=browser works with an already configured real-browser driver; no automatic retry on failure.

## Reference tests

Both runners use examples/bdd/features/expenses.feature and actions.rb. The two scenarios exercise real Stimulus, Turbo, Rack cookies, CSRF, ActiveRecord validation and persistence, plus session isolation. The runner-specific step definitions are separate. The dedicated CI matrix covers Node/jsdom26, jsdom31 and Happy DOM, checks exactly two passed scenarios per configuration and saves native runner JSON. No cucumber-rails or rspec-rails dependency is required in this example; Rails application boot is explicit.

## Recording foundation

BDD::Scenario optionally accepts on_event: ->(event) { ... }. Explicit step wrappers emit started/finished, sequence, semantic kind, duration and pass/fail. The observer is optional; standard observer errors do not change test results. Metadata contains no step text, field values, selectors or HTML. This is not an automatic Gherkin step recorder or DOM replay. The supplied action wrappers are manually classified and can contain more than one primitive interaction. Scenario names and source locations are not captured by this API yet. Full automatic step mapping, snapshots, target highlights and reporting belong to subsequent batches. Diagnostics can use the existing opt-in failure capture. Only trusted test code.

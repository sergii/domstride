# Batch 013.4 - Real Rails Action View attribution probe

Stacked on #28 without restarting its coverage CI. Isolated Rails 8.1.4.1, Herb 0.11.2, ReActionView 0.6.1 (its tagged gemspec requires Herb >=0.11.2 and Action View >=7). Version-specific configuration verified against https://github.com/marcoroth/reactionview/blob/v0.6.1/lib/reactionview/config.rb and its railtie: use config.engine.visitors.use, not deprecated transform_visitors. Explicit interception only in synthetic test app. No installation in core gem, no production changes, no reactive slots/dev server/debug mode. Validation disabled for this synthetic inline-JS fixture, not a recommendation for customer applications.

Real controller route, Action View collection partial, conditional rendering, ordinary Rails Rack request through Specdrive, existing metadata-only recording. Test both attribution disabled/enabled in fresh processes. Enabled must match exact AST locations and two repeated runtime instances sharing one source; clicked second instance must produce the expected visible result. Disabled must render and click normally without stamps. No manual eval or rewriting Rails templates. This compares attribution on/off inside ReActionView, not stock Erubi parity. Real runtime ambiguity, Turbo replacement, failed actions, source privacy controls, general application compatibility and Viewer integration remain unverified. CI pending.

## Verified first Rails results

[Run 46101459534](https://github.com/sergii/specdrive/actions/runs/46101459534), job 140844616511, passed on 522376c. Attribution disabled: 3/4 observed buttons with zero stamps; enabled: 3/4 observed buttons and 2/3 distinct stamps respectively; both recorded targets correctly map to app/views/pets/_card.html.erb:2:3 in the enabled run. The visible result assertion passed in both modes. [Coverage aggregation run 46101313487](https://github.com/sergii/specdrive/actions/runs/46101313487), job 140844154973, also passed at d6e6fe6.

## Rails evidence export

Reuse the exact #28 offline aggregator and HTML renderer with the verified Rails mapping, assert expected metrics, and export rails-mapping.json, coverage.json and coverage.html. Attribution disabled is a negative control, not zero-percent source coverage; emit no coverage report in that mode. Report only the scoped static button candidates and one pre-action checkpoint per run. No unmatched nodes in this fixture; broader runtime mapping and actual dynamic/ambiguous cases remain future. CI pending for the new export. No production dependencies or Fast Mode changes.

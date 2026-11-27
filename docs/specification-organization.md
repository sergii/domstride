# Specification organization v1

Project structure agnostic: acceptance tests stay in the host project's native test tree. Cucumber uses features/, Turnip often spec/acceptance/, RSpec and Minitest retain their existing spec/system or test/system paths. Living Documentation is generated output, not another test category.

Default recommended Gherkin organization: features/<domain>/<capability>/<behavior>.feature. Lowercase snake_case, verb + object filename; normally 2-3 folders, split by stable business capability rather than model names or actor roles. Example: features/marketplace/listings/publish_listing.feature. One canonical file per behavior. Stable @feature and @scenario IDs preserve history across moves. Metadata @domain:marketplace, @capability:listings, @actor:seller, @actor:buyer, @web, @documentation, @replay; platform tags mean applicability, not verification. Journey relationships may live in optional metadata. Optional _domain.yml / _capability.yml hold IDs, titles, descriptions and owners, validated against feature metadata. Avoid duplicated descriptions or conflicting tags.

Studio navigation should group the same canonical specification by domain/capability, actor, platform (separate actual verification), or journey. No copying files. Include search and stable links; source URI and source revision remain provenance.

Proposed configuration (not implemented API):
```yaml
version: 1
specification:
  paths:
    - features/**/*.feature
artifacts:
  directory: tmp/domstride/artifacts
documentation:
  enabled: true
  output: tmp/domstride/documentation
  group_by: domain
  include_tags: ["@documentation"]
replay:
  enabled: true
  include_tags: ["@replay"]
execution:
  default_mode: fast
```

Support multiple configured glob paths in monorepos; do not force Rails directory conventions onto other stacks. Generated artifacts are ignored by default. Public examples use only public applications and synthetic fixtures. The Petstore app owns the canonical feature; the Domstride reference adapter consumes it directly from a pinned public checkout. Future Rails Ruby and browser adapters run the same feature without duplicating its source.

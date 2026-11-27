# Executable Specification v1

Status: proposed conventions for implementation, not a new Gherkin dialect. Use official Gherkin AST and Cucumber Messages, not a custom parser. Specification, implementation and execution evidence are separate layers.

## Authoring

Feature descriptions contain Overview, Business value, Actors and Preconditions as plain text headings (e.g. Overview:). Lines beginning with # are Gherkin comments and do not appear in the AST description. Descriptive preconditions do not execute; Given/Background must establish or verify actual state. Rule expresses a business rule. Scenario describes a business use case. Scenario Outline/Examples are parameterized cases. Data Tables and Doc Strings are structured inputs. Preserve source text, original keyword (including And/But), descriptions, source URI/line and resolved example values. Keep selectors and technical actions in step definitions. Use simple English. Negative paths can pass when the expected rejection happens.

## Metadata

Feature and scenario stable business IDs are required for published documentation. Tags are conventions rather than Cucumber semantics:
- @feature:LST-001, @scenario:LST-001-01
- @domain:marketplace, @capability:listings, @priority:critical, @happy_path / @negative_path
- @web, @ios, @android (applicability only)
- @documentation, @replay (publication/capture selection)
- Optional @jira:DEMO-123, @actor:seller, @actor:buyer, @smoke, @regression, @risk:validation.

Stable business IDs survive title/path changes. Generated AST IDs are only source/run mapping keys. Validate uniqueness, required tags, sidecar references and conflicting metadata. Outline rows need distinct stable example keys (production explicit IDs), retries distinct attempt IDs. Do not infer verified platform from a tag. Complex policy (owner, audience, visibility, dependencies, layout, checkpoints) belongs in optional sidecar YAML keyed by stable IDs, without duplicating feature text. No credentials, PII or private application data.

## Mapping

GherkinDocument -> Pickle and PickleStep.astNodeIds -> TestCase and TestStep -> TestCaseStarted -> TestStepStarted/Finished. Group events by testCaseStartedId; use testStepId for runtime step identity. Preserve Background separately and hooks/failures in evidence, including undefined/skipped/pending cases. One business step may have multiple primitive actions/assertions; evidence is not inferred from video. Keep raw NDJSON and normalize to existing case protocol. Standard parser/runner handles Gherkin; adapters implement only normalization and policy.

Reference: [Petstore reference](../examples/petstore/README.md), [Gherkin reference](https://cucumber.io/docs/gherkin/reference/), [Cucumber Messages](https://github.com/cucumber/messages).

See [specification organization](specification-organization.md) for domain paths, roles, navigation and configuration.

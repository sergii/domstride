# Core extraction and packaging: phase 1

Scope: reusable documentation model and static Markdown/MDX exporter, shipped via the existing Ruby gem lib/ packaging. No changes to engine, runtime cache, capture, Viewer, or default test execution. The implementation uses Node built-ins only; no npm install or Rails server required to export an existing run.

```sh
domstride docs export --synthetic-reference /absolute/path/to/guided-run
```

Requires explicitly approved trusted synthetic reference artifacts in the existing paired Chromium run format. This is not a general untrusted-artifact ingestion or production publication API. No upload, no automatic redaction, no new recording. Existing output format, framework importers and UI stay unchanged. Duplicate scenario/media IDs and symlink inputs rejected; no overwrite of an existing export directory. Failed export may leave a partial generated directory; remove it explicitly before retrying. Local input must be controlled by the caller; full security/schema validation and atomic export are later gates.

The Petstore example delegates to the packaged model/exporter. CLI and installed-gem smoke use separate synthetic library-domain fixtures; actual Petstore CI still exercises real recorded media and both documentation sites. Later phases: reusable Cucumber Messages normalizer, separate Playwright recorder API, stable schema and retry/example mapping, generic platform and publication policies, framework adapters. Core performance A/B remains separate. No release publication.

Status: implementation candidate; CI pending.

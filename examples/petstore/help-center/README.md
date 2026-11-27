# Petstore Help Center (Astro Starlight)

Reference integration using generated MDX, native Steps, sidebar and table of contents, local verified media and ordinary HTML5 video. No test execution at build time. Root-path deployment only in this reference. No external hosting, storage or production plugin API.

From a fresh checkout with the approved synthetic static-export already available:

```sh
cd examples/petstore
npm install
npx playwright install chromium
cd help-center
npm install
npm run import -- /absolute/path/to/static-export
npm run build
npm run preview
# In another shell:
npm run smoke
```

The adapter checks manifest provenance, media integrity and explicit generated paths, imports only the portable publication, and refuses to overwrite existing generated content. To regenerate, remove the generated directories explicitly. The source Gherkin stays in Petstore. Build and browser smoke are required before treating this reference as verified. The published site must contain only dist, not raw test artifacts.

## Verified build

CI [45980012782](https://github.com/sergii/domstride/actions/runs/45980012782) passed build and browser smoke. Download the site artifact, unzip, then serve the included dist directory from the root of a local static server (for example, `python3 -m http.server 4321 --directory dist`). Open http://localhost:4321/generated/lst-001-01/. No Rails, npm install, or tests required for the built site.

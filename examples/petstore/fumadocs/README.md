# Fumadocs reference

Imports the exact same approved static-export as Starlight via a shared importer. Native Steps, MDX, sidebar and TOC; static Next.js output in `out/`, root paths only. Search is intentionally disabled in this initial static reference. No Rails or test execution at build time, no hosted deployment.

```sh
npm install
npm run import -- /absolute/path/to/static-export
npm run build
python3 -m http.server 4322 --directory out
# In a second terminal (parent Petstore Playwright installed):
npm run smoke
```

Direct Fumadocs packages pinned; Next/React/Tailwind ranges still need a verified lockfile. The input is trusted synthetic reference MDX, not arbitrary untrusted executable content. CI build and smoke required for verification.

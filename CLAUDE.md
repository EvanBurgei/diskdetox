# DiskDetox — diskdetox.com

Free, 100% client-side Windows disk-cleanup web tool. Single static HTML file, zero network calls, deployed to Cloudflare Pages.

- **Brand:** diskdetox (tokens at `C:\Users\egbur\OneDrive\Documents\Claude\Context\01_Core\Brand_Tokens\diskdetox.md`)
- **Docs:** code-only project — design notes live in this repo (this file + `README.md`). No separate `03_Projects` docs folder (Operating Doc mount exception).
- **Origin:** built 2026-06-15 from the v1 reference at `C:\Users\egbur\OneDrive\Documents\Claude\Context\03_Projects\Compute_Health\`.

## Hard requirements (do not regress)
1. **Zero network calls — ever.** No CDNs, web fonts, analytics, or page-fetched images. Inline everything. Must work from `file://` and offline. This is the entire security promise.
2. **Read-only scan** — collects sizes + folder/program names only, never file contents. Keep the `-Redact` switch and `-Attributes !Offline` (skips cloud-only OneDrive files; hang-resistance on full drives).
3. **Resilient parsing** — accept `disk-health/v1` JSON whether arrays come through as arrays or single objects (PowerShell `ConvertTo-Json` collapses single-element arrays). Render only sections present, so the schema can grow without breaking old data.
4. **Risk badges on every fix** (Safe / Review / Advanced). Never auto-run anything; copy-to-clipboard only.

## Files
- `index.html` — the entire app (self-contained, zero deps).
- `404.html` — branded not-found page (Pages serves it with a real 404 for unknown paths).
- `diskdetox-scan.ps1` — the read-only scan (also embedded in the page's "Copy command" box).
- `favicon.svg` — canonical brand mark (also inlined as a data-URI favicon in `index.html`).
- `_headers` — Cloudflare Pages response headers (CSP + frame-ancestors/nosniff/no-referrer).
- `functions/_middleware.js` — Pages Function: 301 `www` → apex.
- `og.html` → `og.png` — social-share card (build asset; not fetched by the live page).
- `deploy.ps1` — clean deploy (stages public files only).
- `README.md` — usage, security model, deploy notes, JSON schema.

## Deploy
Static + one tiny Pages Function — no build step. **Run `.\deploy.ps1`** — it stages only the public files (plus `functions/`) and runs `wrangler pages deploy` (Pages ignores `.gitignore`/`.assetsignore`, so deploying the repo root directly would publish `CLAUDE.md`/`README.md`). **LIVE at https://diskdetox.com** (+ `www` 301→apex via `functions/_middleware.js`; also diskdetox.pages.dev). Cloudflare Pages project `diskdetox`, both custom domains Active/SSL. Unknown paths → real 404 (`404.html`). See `README.md`.

## JSON schema: `disk-health/v1`
`{ schema, generated, machine, redacted, drives[{id,totalGB,freeGB,pctFree}], profileFolders[{name,gb}], appDataLocal[{name,gb}], programs[{name,mb}], caches[{name,gb,path,safe}], games[{name,gb,path}], system{hiberfilGB,pagefileGB,driverStoreGB} }`

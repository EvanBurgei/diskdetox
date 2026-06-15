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
Deployed site = the **`public/`** folder (Pages serves only this; dev files stay at root, never published):
- `public/index.html` — the entire app (self-contained, zero deps).
- `public/404.html` — branded not-found page (real 404 for unknown paths).
- `public/favicon.svg` — canonical brand mark (also inlined as a data-URI favicon in `index.html`).
- `public/og.png` — social-share card (referenced by OG meta; scraper-fetched only).
- `public/diskdetox-scan.ps1` — the read-only scan (also embedded in the page's "Copy command" box).
- `public/_headers` — Pages response headers (CSP + frame-ancestors/nosniff/no-referrer).
- `public/functions/_middleware.js` — Pages Function: 301 `www` → apex.
- Root (not deployed): `og.html` (renders `public/og.png`), `deploy.ps1`, `.github/workflows/deploy.yml`, `README.md`, `CLAUDE.md`.

## Deploy
Site = `public/`; static + one tiny Pages Function, no build step. **LIVE at https://diskdetox.com** (+ `www` 301→apex via `public/functions/_middleware.js`; also diskdetox.pages.dev). Cloudflare Pages project `diskdetox` (Direct Upload), both custom domains Active/SSL. Unknown paths → real 404.
- **Auto-deploy:** `.github/workflows/deploy.yml` deploys `public/` on push to `main`. Needs repo secrets `CLOUDFLARE_API_TOKEN` (Pages:Edit) + `CLOUDFLARE_ACCOUNT_ID`.
- **Manual:** `.\deploy.ps1` → `wrangler pages deploy public …` (already clean since the site is `public/`).
- GitHub: https://github.com/EvanBurgei/diskdetox (public). See `README.md`.

## JSON schema: `disk-health/v1`
`{ schema, generated, machine, redacted, drives[{id,totalGB,freeGB,pctFree}], profileFolders[{name,gb}], appDataLocal[{name,gb}], programs[{name,mb}], caches[{name,gb,path,safe}], games[{name,gb,path}], system{hiberfilGB,pagefileGB,driverStoreGB} }`

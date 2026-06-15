# DiskDetox (diskdetox.com)

A free, generic, shareable, **100% client-side** web tool that shows what's eating a Windows drive and gives ranked, copy-and-run fixes. Tagline: *Free up space on your Windows PC.* Single static HTML file, zero dependencies, **zero network calls** — deployed to Cloudflare Pages at [diskdetox.com](https://diskdetox.com).

## Files

The deployed site is the **`public/`** folder — Cloudflare Pages serves only this, so dev files never leak:

- `public/index.html` — the entire app in one file. No dependencies, no build step, no external requests. Self-contained brand: teal/green "detox" palette, inline data-URI favicon, inline SVG logo.
- `public/404.html` — branded "page not found"; Pages serves it with a real `404` status for unknown paths.
- `public/favicon.svg` — canonical brand mark (also inlined into `index.html` as a data URI).
- `public/og.png` — social-share card (1200×630), referenced by `index.html`'s OG meta. Fetched only by social scrapers, never by the live page.
- `public/diskdetox-scan.ps1` — the read-only PowerShell scan (also embedded in the page's "Copy command" box, so users don't strictly need this file).
- `public/_headers` — Cloudflare Pages response headers (CSP + `frame-ancestors`/`nosniff`/`no-referrer`).
- `public/functions/_middleware.js` — Pages Function that 301-redirects `www.diskdetox.com` → apex.

Dev / build files (**not** deployed): `og.html` (renders `public/og.png`), `deploy.ps1`, `.github/workflows/deploy.yml`, `README.md`, `CLAUDE.md`.

## How it works (user flow)

1. Open the page. It shows **demo data** so the empty state looks complete.
2. Copy the PowerShell command from **Step 1** (optional "Redact" toggle strips paths + machine name).
3. Run it in Windows PowerShell. It's **read-only** — measures sizes and reads folder/program *names* only, never file contents. It writes `disk-health.json` to the Desktop and copies it to the clipboard.
4. Back on the page, **Paste data** or **Load file…**. Everything is parsed and rendered in the browser.
5. Data persists in `localStorage` (this browser) until "Clear my data". Or load from a JSON file each time.

## Security model

- The page is a **static shell**. Hosting it publicly is safe because it contains no data.
- **Zero network calls** — no servers, CDNs, web fonts, or analytics. The user's scan output never leaves their machine; there's nothing to exfiltrate to.
- Only potentially sensitive content is folder *names*; the **Redact** toggle removes paths and machine name from the output for users who want it.
- Works offline and from a `file://` path.

## What the scan collects

Drive totals/free space · top user-profile folders by size · biggest `AppData\Local` caches · largest installed programs (from the uninstall registry) · cleanable caches (Temp, Windows Temp, Windows Update cache, Downloads, Recycle Bin) · installed games in common launcher roots · system files (hiberfil, pagefile, DriverStore). It does **not** read file contents and skips cloud-only OneDrive files (so they aren't counted or slow the scan).

## Deploy (Cloudflare Pages)

**Live:** https://diskdetox.com (apex; `www` 301-redirects here via the Pages Function) — also https://diskdetox.pages.dev. Project `diskdetox` (Direct Upload), production branch `main`. The site is the `public/` folder; static + one tiny Function, no build step. `_headers` ships strict security headers (a CSP that enforces the zero-network promise, plus `frame-ancestors 'none'`, `nosniff`, `no-referrer`); the same CSP is inlined as a `<meta>` tag, so the guarantee holds even from `file://`. Unknown paths get a real `404`.

### Auto-deploy (git push)

`.github/workflows/deploy.yml` deploys `public/` to the Pages project on every push to `main` (and via the **Run workflow** button). It needs two repo secrets — **Settings → Secrets and variables → Actions**:

- `CLOUDFLARE_API_TOKEN` — **you create this** (it's a credential): dash.cloudflare.com → My Profile → API Tokens → Create → use the "Edit Cloudflare Workers" template, or a custom token with **Account › Cloudflare Pages › Edit**.
- `CLOUDFLARE_ACCOUNT_ID` — `952e883090709e56962f92fc5fdf40f0` (set as a secret for convenience; not actually sensitive).

### Manual deploy

    .\deploy.ps1

Runs `wrangler pages deploy public --project-name diskdetox --branch main`. Because the site lives in `public/`, the deploy is already clean — no dev files are uploaded.

### Custom domain

**Done** — `diskdetox.com` and `www.diskdetox.com` are attached to the Pages project (both Active, SSL on). `www` 301-redirects to the apex via `public/functions/_middleware.js`.

### Regenerating the share image

`public/og.png` (1200×630) is rendered from `og.html` with headless Edge — re-run after any brand/copy change, from the repo root in PowerShell:

    & "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=1200,630 --screenshot="$PWD\public\og.png" "file:///$(($PWD.Path) -replace '\\','/')/og.html"

## JSON schema (`disk-health/v1`)

```
{ schema, generated, machine, redacted,
  drives:[{id,totalGB,freeGB,pctFree}],
  profileFolders:[{name,gb}], appDataLocal:[{name,gb}],
  programs:[{name,mb}],
  caches:[{name,gb,path,safe}],
  games:[{name,gb,path}],
  system:{hiberfilGB,pagefileGB,driverStoreGB} }
```

The dashboard renders whatever sections are present, so the schema can grow without breaking older data.

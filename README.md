# DiskDetox (diskdetox.com)

A free, generic, shareable, **100% client-side** web tool that shows what's eating a Windows drive and gives ranked, copy-and-run fixes. Tagline: *Free up space on your Windows PC.* Single static HTML file, zero dependencies, **zero network calls** — deployed to Cloudflare Pages at [diskdetox.com](https://diskdetox.com).

## Files

- `index.html` — the entire app in one file. No dependencies, no build step, no external requests. Self-contained brand: teal/green "detox" palette, inline data-URI favicon, inline SVG logo.
- `diskdetox-scan.ps1` — the read-only PowerShell scan (also embedded inside the page's "Copy command" box, so users don't strictly need this file).
- `favicon.svg` — canonical brand mark (also inlined into `index.html` as a data URI).
- `og.html` → `og.png` — the social-share card. `og.html` is a build asset rendered once to `og.png` (1200×630), which `index.html` references for link previews. Neither is fetched by the live page.
- `README.md` — this file.

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

**Live:** https://diskdetox.pages.dev — project `diskdetox`, production branch `main`. Static, no build step. The `_headers` file ships strict security headers (a CSP that enforces the zero-network promise, plus `frame-ancestors 'none'`, `nosniff`, `no-referrer`); the same CSP is inlined as a `<meta>` tag, so the guarantee holds even from `file://`.

### Redeploy

    .\deploy.ps1

`deploy.ps1` stages a temp folder with **only the public files** (`index.html`, `og.png`, `favicon.svg`, `diskdetox-scan.ps1`, `_headers`) and runs `wrangler pages deploy`.

> ⚠️ Don't run `wrangler pages deploy .` directly, and don't point a git-connected Pages build at the repo root — Cloudflare Pages uploads **every** file and ignores `.gitignore`/`.assetsignore`, so it would publish `CLAUDE.md` and `README.md` too. `deploy.ps1` is the clean path. (To later use git-integration auto-deploys, move the public files into a `public/` subdir and set that as the output directory.)

### Custom domain

Register `diskdetox.com` via Cloudflare Registrar, then Pages project → **Custom domains** → add `diskdetox.com` (one click, since the zone is already on Cloudflare).

### Regenerating the share image

`og.png` (1200×630) is rendered from `og.html` with headless Edge — re-run after any brand/copy change, from the repo root in PowerShell:

    & "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --window-size=1200,630 --screenshot="$PWD\og.png" "file:///$(($PWD.Path) -replace '\\','/')/og.html"

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

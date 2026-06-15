# DiskDetox (diskdetox.com)

A generic, shareable, **fully client-side** web tool that shows what's eating a Windows drive and gives ranked, copy-and-run fixes. Tagline: *Free up space on your Windows PC.* Built as a working v1 / reference spec — safe to rebuild or extend in Claude Code.

## Files

- `disk-health-dashboard.html` — the entire app in one file. No dependencies, no build step, no external requests.
- `disk-health-scan.ps1` — the read-only PowerShell scan (also embedded inside the HTML's "Copy command" box, so users don't strictly need this file).
- `README-disk-health.md` — this file.

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

## Deploying the public page (pick one)

All three are free and serve a single static HTML file:

- **Cloudflare Pages** — drag-and-drop the HTML, or connect a repo. Pairs with a custom domain on Cloudflare.
- **GitHub Pages** — commit the HTML to a repo, enable Pages in settings.
- **Netlify** — drag-and-drop deploy.

Point your chosen domain at it. Because the app is one file, deployment is just "upload this HTML."

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

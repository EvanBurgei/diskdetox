# DiskDetox — diskdetox.com

Free, 100% client-side Windows disk-cleanup web tool. Single static HTML file, zero network calls, deployed to Cloudflare Pages.

- **Brand:** Evan (personal brand applied 2026-06-15 via brand-apply — tokens at `…\Brand_Tokens\Evan.md`). Deep-navy/paper-cream + petrol accent, rust for primary CTAs, system serif headings (no web fonts — zero-network). Day/night toggle defaults to OS, persists to `localStorage` (`diskDetoxTheme`). The original `diskdetox.md` teal/green sub-brand tokens are superseded for the live site.
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
- `functions/_middleware.js` — Pages Function at the **repo root** (beside `public/`; `wrangler pages deploy public` resolves `functions/` at the project root, NOT inside the output dir — don't nest it in `public/`): 301 `www` → apex.
- Root (not deployed): `og.html` (renders `public/og.png`), `deploy.ps1`, `README.md`, `CLAUDE.md`.

## Deploy
Site = `public/`; static + one tiny Pages Function (`functions/` at repo root), no build step. **LIVE at https://diskdetox.com** (+ `www` 301→apex via `functions/_middleware.js`; also diskdetox.pages.dev). Cloudflare Pages project `diskdetox` (Direct Upload), both custom domains Active/SSL. Unknown paths → real 404.
- **Deploy:** `.\deploy.ps1` → `wrangler pages deploy public …` (uses the machine's wrangler OAuth; already clean since the site is `public/`).
- **Source:** https://github.com/EvanBurgei/diskdetox (public). `git push` publishes source; `.\deploy.ps1` ships the site. No CI auto-deploy — chose PowerShell-only over a CF API token.

## JSON schema: `disk-health/v1`
`{ schema, generated, machine, redacted, drives[{id,totalGB,freeGB,pctFree}], profileFolders[{name,gb}], appDataLocal[{name,gb}], programs[{name,mb}], caches[{name,gb,path,safe}], games[{name,gb,path}], largestFiles[{name,gb,path,ext}], driveFolders[{drive,folders:[{name,gb}]}], startup[{name,source,command,exe,signed?,signer?,sha256?,loc?,taskPath?,svc?}], processes[{name,ramMB,count}], security{defender{present,realtime,avEnabled,sigAgeDays,quickScanAgeDays,fullScanAgeDays,tamper},firewall[{name,enabled}],bitlocker,lastUpdate,threats[{name,severity,status}]}, system{hiberfilGB,pagefileGB,driverStoreGB} }`
Scan also emits browser caches (Chrome/Edge) + `Windows.old` as `caches` entries. Schema stays `disk-health/v1` (additive; page renders only sections present). `largestFiles` skips AppData; redaction strips path + reduces name to "(a .ext file)". v2 adds `startup[]` (Run keys, Startup folders, logon scheduled tasks, third-party auto services; redaction nulls `command`, keeps name/source/exe) and `processes[]` (top 20 by RAM, grouped by name). Bloatware flagging and system-process filtering are render-time heuristics in the page (`BLOAT_HINTS` / `SYS_PROC`), NOT in the scan, so the scan stays factual and the judgment can change without re-scanning. Startup actions are reversible + risk-badged (Windows Startup-apps toggle / Task Manager; `Disable-ScheduledTask`; `Set-Service -StartupType Manual`); never auto-applied. v2.6 adds a read-only `security` posture object (Defender real-time / signature-age / scan-age via `Get-MpComputerStatus`, firewall per profile, BitLocker, last update via `Get-HotFix`, Defender threat log via `Get-MpThreat`) + per-startup `signed`/`signer`/`sha256`/`loc` (`Get-AuthenticodeSignature` + `Get-FileHash` + path categorization). It is NOT an antivirus — it surfaces posture + suspicion signals (unsigned / Temp-Downloads-AppData startup) + SHA-256 for manual VirusTotal + copy-to-run real scans (`Start-MpScan`, `Update-MpSignature`, `sfc`/`DISM`). GOTCHA: `QuickScanAge`/`FullScanAge` return UInt32-max (4294967295) for "never scanned" — the scan maps `>36500` to null. UI consolidation (v2.6): How-to walkthrough + Learn FAQ are folded into the **Scan tab** (sibling sections sharing `data-panel="scan"`, so `activateTab` shows them together) → 8 tabs. `.ps1` download button on the Scan tab (Blob, honors Redact). `.badge.safe`/`.adv` text uses `color-mix(60% toward --txt)` for AA.

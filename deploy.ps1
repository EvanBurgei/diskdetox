# DiskDetox -> Cloudflare Pages. Deploys the public/ folder (the live site root).
# Manual / local deploy. There is no CI auto-deploy (PowerShell-only by design):
# `git push` publishes source to GitHub; THIS script ships the site to Cloudflare.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
npx wrangler pages deploy public --project-name diskdetox --branch main --commit-dirty=true

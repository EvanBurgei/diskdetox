# DiskDetox -> Cloudflare Pages. Deploys the public/ folder (the live site root).
# Manual / local deploy. CI also deploys public/ on every push to main
# (.github/workflows/deploy.yml), so day to day you can just `git push`.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
npx wrangler pages deploy public --project-name diskdetox --branch main --commit-dirty=true

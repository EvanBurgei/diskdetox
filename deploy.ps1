# DiskDetox -> Cloudflare Pages — clean deploy.
#
# Uploads ONLY the public files. Cloudflare Pages uploads every file in the deploy
# directory and ignores .gitignore / .assetsignore, so deploying the repo root directly
# would publish CLAUDE.md and README.md (which contain local paths / dev notes). We stage
# a temp folder with just the public set to avoid that.
#
# Usage (PowerShell, from the repo):  .\deploy.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$public = 'index.html', 'og.png', 'favicon.svg', 'diskdetox-scan.ps1', '_headers'
$stage  = Join-Path $env:TEMP 'diskdetox-pub'

Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item -Path $public -Destination $stage

npx wrangler pages deploy $stage --project-name diskdetox --branch main --commit-dirty=true

Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue

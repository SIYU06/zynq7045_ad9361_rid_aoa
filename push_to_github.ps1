# Run from PowerShell after authenticating the SIYU06 account.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
& gh auth status
if ($LASTEXITCODE -ne 0) { throw 'Run: gh auth login --hostname github.com --git-protocol https --web' }
& gh auth setup-git
if ($LASTEXITCODE -ne 0) { throw 'GitHub credential setup failed.' }
& git -C $repo -c http.sslBackend=openssl push -u origin main
if ($LASTEXITCODE -ne 0) { throw 'Push failed; check account permission and remote branch state. No force push was attempted.' }

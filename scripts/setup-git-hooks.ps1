$ErrorActionPreference = "Stop"

Write-Host "Configuring repository-local Git hooks..."
git config core.hooksPath .githooks
Write-Host "Done. Git hooks now run from .githooks/."

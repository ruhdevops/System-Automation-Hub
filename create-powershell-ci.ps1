[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
<#
.SYNOPSIS
    Generates the PowerShell CI GitHub Actions workflow file.

.DESCRIPTION
    Creates (or overwrites) .github\workflows\powershell-ci.yml with a
    multi-OS CI pipeline that:

      - Triggers on pushes and pull requests to the main branch, and also
        supports manual dispatch (workflow_dispatch).
      - Runs on a 3-OS matrix: ubuntu-latest, windows-latest, macos-latest.
      - Installs PSScriptAnalyzer and Pester from the PowerShell Gallery.
      - Executes a PSScriptAnalyzer security scan (Error/Warning severity,
        security rules only) and fails the job if any issues are detected.
      - Runs Pester tests from the ./tests directory (if present) and fails
        the job if any tests fail.

    The .github\workflows directory is created automatically if absent.

.PARAMETER (none)
    This script accepts no parameters.

.EXAMPLE
    .\create-powershell-ci.ps1
    # Writes powershell-ci.yml and prints the file path on success.

.NOTES
    - Run from the repository root so the workflow path resolves correctly.
    - This script generates only powershell-ci.yml.  Use
      create-download-cert.ps1 to also generate download-cert.yml.
    - Existing files with the same name will be overwritten silently.
    - PSAvoidUsingWriteHost is suppressed intentionally for status output.
#>
param()

# Workflow folder
$workflowDir = ".github\workflows"
if (-not (Test-Path $workflowDir)) {
    New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
}

# powershell-ci.yml
$powershellCiYaml = @'
name: PowerShell CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  powershell-ci:
    name: PowerShell CI (${{ matrix.os }})
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install Modules
        shell: pwsh
        run: |
          Set-PSRepository PSGallery -InstallationPolicy Trusted
          Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
          Install-Module Pester -Force -Scope CurrentUser -SkipPublisherCheck

      - name: Run PSScriptAnalyzer (Security Scan)
        shell: pwsh
        run: |
          $results = Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning |
                     Where-Object { $_.RuleName -like "*Security*" }

          if ($results) {
              $results | Format-Table
              Write-Host "::error title=Security Scan [Run #$($env:GITHUB_RUN_NUMBER)]::Potential security issues found in PowerShell scripts."
              throw "Security issues detected by PSScriptAnalyzer"
          } else {
              Write-Host "::notice title=Security Scan [Run #$($env:GITHUB_RUN_NUMBER)]::No common security issues found."
          }

      - name: Run Pester Tests
        shell: pwsh
        run: |
          if (Test-Path ./tests) {
              $results = Invoke-Pester -Path ./tests -PassThru
              if ($results.FailedCount -gt 0) {
                  Write-Host "::error title=Pester Tests [Run #$($env:GITHUB_RUN_NUMBER)]::$($results.FailedCount) tests failed."
                  throw "Pester tests failed."
              } else {
                  Write-Host "::notice title=Pester Tests [Run #$($env:GITHUB_RUN_NUMBER)]::All tests passed successfully."
              }
          } else {
              Write-Host "::notice title=Pester Tests [Run #$($env:GITHUB_RUN_NUMBER)]::No Pester tests found in ./tests."
          }
'@

$powershellCiFile = Join-Path $workflowDir "powershell-ci.yml"
$powershellCiYaml | Set-Content -Path $powershellCiFile -Force
Write-Host "$powershellCiFile created successfully."
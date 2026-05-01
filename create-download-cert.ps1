[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
<#
.SYNOPSIS
    Generates GitHub Actions workflow files for certificate downloading and
    PowerShell CI into .github\workflows\.

.DESCRIPTION
    Creates (or overwrites) two workflow YAML files:

    1. download-cert.yml  – A manually-triggered (workflow_dispatch) workflow
       that accepts a certificate URL and filename as inputs, downloads the
       certificate with curl, and uploads it as a build artifact.

    2. powershell-ci.yml  – A push/PR/manual CI workflow that runs on a
       3-OS matrix (ubuntu-latest, windows-latest, macos-latest).  Each job:
         a. Installs PSScriptAnalyzer and Pester from the PSGallery.
         b. Runs PSScriptAnalyzer at Error/Warning severity, filtering for
            security-related rules.
         c. Executes Pester tests found in ./tests (if the directory exists).

    The .github\workflows directory is created if it does not already exist.

.PARAMETER (none)
    This script accepts no parameters.

.EXAMPLE
    .\create-download-cert.ps1
    # Writes both workflow files and confirms their paths on success.

.NOTES
    - Run from the repository root.
    - Existing workflow files with the same names will be overwritten silently.
    - PSAvoidUsingWriteHost is suppressed intentionally for status output.
#>
param()
# Workflow folder
$workflowDir = ".github\workflows"
if (-not (Test-Path $workflowDir)) {
    New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
}

# 1. download-cert.yml
$downloadCertYaml = @'
name: Download Certificate

on:
  workflow_dispatch:
    inputs:
      certUrl:
        description: 'URL of the certificate to download'
        required: true
      certName:
        description: 'Name for the downloaded certificate'
        required: true

jobs:
  download:
    runs-on: ubuntu-latest
    steps:
      - name: Download Certificate
        run: |
          curl -L "${{ github.event.inputs.certUrl }}" -o "${{ github.event.inputs.certName }}"
          echo "Certificate downloaded: ${{ github.event.inputs.certName }}"

      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ github.event.inputs.certName }}
          path: ${{ github.event.inputs.certName }}
'@

$downloadCertFile = Join-Path $workflowDir "download-cert.yml"
$downloadCertYaml | Set-Content -Path $downloadCertFile -Force
Write-Host "$downloadCertFile created successfully."

# 2. powershell-ci.yml
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

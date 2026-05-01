[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
<#
.SYNOPSIS
    Manually triggers a GitHub Actions workflow via the repository dispatch API.

.DESCRIPTION
    Lists all *.yml workflow files found in .github/workflows, prompts the
    operator to choose one, then uses the GitHub REST API
    (POST /repos/{owner}/{repo}/actions/workflows/{workflow}/dispatches)
    to trigger a workflow_dispatch event on the main branch.

    Authentication is handled through the GITHUB_TOKEN environment variable,
    which must hold a Personal Access Token (PAT) with the repo and workflow
    scopes.

.PARAMETER (none)
    This script accepts no parameters; all inputs are collected interactively
    at runtime.

.EXAMPLE
    $env:GITHUB_TOKEN = "ghp_..."
    .\run-workflow-manually.ps1
    # Lists available workflows, prompts for selection and confirmation,
    # then dispatches the chosen workflow on the main branch.

.NOTES
    - GITHUB_TOKEN must be set before running this script.
    - The target repository is hard-coded as Ruh-Al-Tarikh/System-Automation-Hub.
      Update $owner and $repo variables to target a different repository.
    - The workflow must define a workflow_dispatch trigger; otherwise GitHub
      will return a 422 Unprocessable Entity error.
    - PSAvoidUsingWriteHost is suppressed intentionally for interactive output.
#>
param()

# Hardcoded GitHub Personal Access Token (with repo/workflows scope)
$token = $env:GITHUB_TOKEN

# GitHub repo info
$owner = "Ruh-Al-Tarikh"
$repo  = "System-Automation-Hub"

# Get list of workflow files
$workflowDir = ".github/workflows"
if (Test-Path $workflowDir) {
    $workflows = Get-ChildItem $workflowDir -Filter *.yml | Select-Object -ExpandProperty Name
} else {
    $workflows = @()
}

Write-Host "Available workflows to run:"
if ($workflows.Count -eq 0) {
    Write-Host "No workflows found in $workflowDir" -ForegroundColor Yellow
    return
}

$workflows | ForEach-Object { Write-Host "- $_" }

# Prompt user to choose workflow
$workflowFile = Read-Host "Enter the workflow file to trigger (e.g., ci.yml)"

if (-not ($workflows -contains $workflowFile)) {
    Write-Host "Workflow file not found!" -ForegroundColor Red
    return
}

# Confirm before dispatch
$answer = Read-Host "Trigger workflow '$workflowFile'? (Y/N)"
if ($answer -ne 'Y') {
    Write-Host "Cancelled."
    return
}

# GitHub API endpoint
$uri = "https://api.github.com/repos/$owner/$repo/actions/workflows/$workflowFile/dispatches"

# Prepare request headers
$headers = @{
    Authorization = "Bearer $token"
    "User-Agent"  = "PowerShell"
    Accept        = "application/vnd.github+json"
}

# Body with branch (main) to run workflow on
$body = @{ ref = "main" } | ConvertTo-Json

# Trigger the workflow
try {
    Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $body
    Write-Host "Workflow '$workflowFile' dispatched successfully!"
    Write-Host "Check https://github.com/$owner/$repo/actions for status."
} catch {
    Write-Host "Error triggering workflow: $($_.Exception.Message)" -ForegroundColor Red
}
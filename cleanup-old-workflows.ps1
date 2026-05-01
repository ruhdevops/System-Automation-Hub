[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
<#
.SYNOPSIS
    Interactively removes stale GitHub Actions workflow files from the
    repository.

.DESCRIPTION
    Iterates over a predefined list of file paths (relative to the repository
    root) that are no longer needed.  Glob patterns are supported, so entries
    like "*.bak" match multiple files.

    For each matched file the script prompts the operator for confirmation
    before deletion, ensuring no files are removed without explicit consent.

.PARAMETER (none)
    This script accepts no parameters.

.EXAMPLE
    .\cleanup-old-workflows.ps1
    # Prompts for each stale workflow file and deletes those confirmed with "Y".

.NOTES
    - Run from the repository root so that relative paths resolve correctly.
    - Files not found on disk are reported but do not cause an error.
    - PSAvoidUsingWriteHost is suppressed intentionally for interactive output.
#>
param()
# Files to remove (relative to repo root)
$filesToDelete = @(
    ".github\workflows\create-powershell-ci.ps1",
    ".github\workflows\download-cert.yml",
    ".github\workflows\powershell-ci.yml.*.bak"
)

foreach ($file in $filesToDelete) {
    # Expand wildcard if any
    $foundFiles = Get-ChildItem -Path $file -ErrorAction SilentlyContinue
    if ($foundFiles) {
        foreach ($match in $foundFiles) {
            $answer = Read-Host "Do you want to delete '$($match.FullName)'? (Y/N)"
            if ($answer -eq 'Y') {
                Remove-Item -Path $match.FullName -Force
                Write-Host "Deleted: $($match.FullName)"
            } else {
                Write-Host "Skipped: $($match.FullName)"
            }
        }
    } else {
        Write-Host "File not found: $file"
    }
}

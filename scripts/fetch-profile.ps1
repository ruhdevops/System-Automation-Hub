[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
<#
.SYNOPSIS
    Fetches and displays a GitHub user's public profile information.

.DESCRIPTION
    Calls the GitHub REST API (GET /users/{username}) and prints a formatted
    summary of the account's public data including login, name, bio, public
    repository count, follower/following counts, and profile URL.

    No authentication is required; the script uses the unauthenticated public
    endpoint, which is subject to GitHub's unauthenticated rate limit
    (60 requests per hour per IP).

.PARAMETER Username
    The GitHub username to look up.  Defaults to "octocat" when not supplied.

.EXAMPLE
    .\scripts\fetch-profile.ps1
    # Fetches the profile for the default user "octocat".

.EXAMPLE
    .\scripts\fetch-profile.ps1 -Username "torvalds"
    # Fetches the public profile for the user "torvalds".

.NOTES
    Outputs coloured text via Write-Host for readability in interactive
    terminals.  PSAvoidUsingWriteHost is suppressed intentionally.
#>
param (
    [Parameter(Mandatory=$false)]
    [string]$Username = "octocat"
)

Write-Host "🔍 Fetching GitHub profile for: $Username..." -ForegroundColor Cyan

try {
    $uri = "https://api.github.com/users/$Username"
    $githubProfile = Invoke-RestMethod -Uri $uri -Method Get

    Write-Host "`n👤 Profile Information:" -ForegroundColor Green
    Write-Host "---------------------------"
    Write-Host "Login:      $($githubProfile.login)"
    Write-Host "Name:       $($githubProfile.name)"
    Write-Host "Bio:        $($githubProfile.bio)"
    Write-Host "Repos:      $($githubProfile.public_repos)"
    Write-Host "Followers:  $($githubProfile.followers)"
    Write-Host "Following:  $($githubProfile.following)"
    Write-Host "URL:        $($githubProfile.html_url)"
    Write-Host "---------------------------"
} catch {
    Write-Host "❌ Error: Could not fetch profile for '$Username'. Details: $($_.Exception.Message)" -ForegroundColor Red
}

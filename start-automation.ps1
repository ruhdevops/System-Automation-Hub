[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
<#
.SYNOPSIS
    Launches the System Automation Hub: starts the webhook listener and opens
    an ngrok tunnel.

.DESCRIPTION
    Orchestrates the two main components of the System Automation Hub:

    1. Webhook Listener  – spawns a new PowerShell window running
       webhooks\listener.ps1 on port 9000.
    2. ngrok tunnel      – starts ngrok in the background, waits 3 seconds for
       it to initialise, then queries the local ngrok API
       (http://127.0.0.1:4040/api/tunnels) to retrieve the public HTTPS URL.

    Once both components are running, the script prints the public ngrok URL
    that should be registered as a webhook endpoint in GitHub (or another
    event source).

.PARAMETER (none)
    This script accepts no parameters.

.EXAMPLE
    .\start-automation.ps1
    # Starts the listener and ngrok, then prints the public webhook URL.

.NOTES
    - ngrok must be installed and available on the system PATH.
    - If ngrok fails to start or the API is unreachable within 3 seconds, the
      script falls back to instructing the user to open the ngrok dashboard
      manually at http://127.0.0.1:4040.
    - PSUseShouldProcessForStateChangingFunctions is suppressed because the
      internal helper functions do not support -WhatIf/-Confirm (they rely on
      Start-Process which has its own confirmation semantics).
#>
param()
# =============================================
# System Automation Hub Launcher
# =============================================

# --- Config ---
$port = 9000
$listenerScript = ".\webhooks\listener.ps1"

# --- Function to start listener ---
function Start-Listener {
    <#
    .SYNOPSIS
        Spawns the webhook listener in a separate PowerShell process.
    .DESCRIPTION
        Launches webhooks\listener.ps1 in a new pwsh window with -NoExit so
        the window stays open and log output remains visible after each event.
    #>
    Start-Process pwsh -ArgumentList "-NoExit -Command `"$listenerScript`""
    Write-Host "✅ Listener started on port $port"
}

# --- Function to start ngrok and display public URL ---
function Start-Ngrok {
    <#
    .SYNOPSIS
        Starts an ngrok HTTP tunnel on the configured port and returns the
        public URL.
    .DESCRIPTION
        Launches ngrok as a minimised background process, waits 3 seconds for
        it to establish a tunnel, then queries the local ngrok REST API to
        retrieve the first available public URL.
    .OUTPUTS
        [string] The public ngrok URL, or $null if the URL could not be
        retrieved automatically.
    #>
    $ngrokPath = "ngrok"  # Make sure ngrok is in PATH
    $null = Start-Process $ngrokPath -ArgumentList "http $port" -NoNewWindow -PassThru -WindowStyle Minimized
    Start-Sleep -Seconds 3

    # Fetch the public URL
    try {
        $ngrokApi = Invoke-RestMethod http://127.0.0.1:4040/api/tunnels
        $publicUrl = $ngrokApi.tunnels[0].public_url
        Write-Host "🌐 ngrok tunnel started: $publicUrl"
        return $publicUrl
    } catch {
        Write-Host "⚠️ Could not fetch ngrok URL automatically. Open http://127.0.0.1:4040 for details."
    }
}

# --- Main ---
Write-Host "🚀 Starting System Automation Hub..."

Start-Listener
$ngrokUrl = Start-Ngrok

Write-Host "`n✅ All set! You can now add this webhook URL to GitHub:"
if ($ngrokUrl) { Write-Host $ngrokUrl } else { Write-Host "Use ngrok dashboard to get URL." }
Write-Host "Make a push to your repository to see automation logs."

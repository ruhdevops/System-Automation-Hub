[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
<#
.SYNOPSIS
    HTTP webhook listener for the System Automation Hub.

.DESCRIPTION
    Starts a .NET HttpListener on port 9000 (http://localhost:9000/) and
    processes incoming HTTP requests in a synchronous loop.

    For each request the listener:
      1. Reads the request body (if present).
      2. Immediately sends a fixed acknowledgement response to minimise latency
         for the caller (e.g. GitHub Webhooks expects a fast 200 OK).
      3. Logs the timestamp, HTTP method, source IP, and request body to the
         console.  JSON payloads are pretty-printed; other content types are
         logged verbatim.

    The listener detects whether a request originates from GitHub by inspecting
    the User-Agent header for the "GitHub-Hookshot" substring and decorates the
    log output accordingly.

    Run start-automation.ps1 instead of invoking this script directly; that
    launcher script also starts an ngrok tunnel and provides the public URL to
    register as a GitHub webhook endpoint.

.PARAMETER (none)
    This script accepts no parameters.

.EXAMPLE
    # Start the listener directly (interactive testing):
    .\webhooks\listener.ps1

    # Send a test event with curl:
    curl -X POST http://localhost:9000/ -d '{"test":"hello"}' -H 'Content-Type: application/json'

.NOTES
    - Requires PowerShell 5.1+ or PowerShell 7+.
    - The HttpListener binds to localhost only; use ngrok or a reverse proxy
      to expose it to the internet.
    - PSAvoidUsingWriteHost is suppressed intentionally for coloured console
      output in interactive sessions.
    - The early-response optimisation (sending the HTTP response before logging)
      is deliberate; do not move the response write after the logging block.
#>
param()

$port = 9000
$endpoint = "http://localhost:$port/"

# Performance: Pre-calculate encoding and response buffer to avoid redundant allocations in the loop
$utf8 = [System.Text.Encoding]::UTF8
$responseBytes = $utf8.GetBytes("System Automation Hub: Event Received")

# Ensure we don't try to start another listener if one is already running in this session
if ($null -ne $listener) {
    try { $listener.Stop() } catch { Write-Verbose "Listener already stopped." }
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($endpoint)

try {
    $listener.Start()
    Write-Host "🚀 Listener started on $endpoint" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop.`n" -ForegroundColor DarkGray

    Write-Host "💡 To test locally, run:" -ForegroundColor Green
    Write-Host "curl -X POST $endpoint -d '{\"test\": \"hello\"}' -H 'Content-Type: application/json'" -ForegroundColor DarkGray
    Write-Host "`nWaiting for events..." -ForegroundColor Cyan

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        # Performance: Use .NET [DateTime]::Now for faster timestamp generation than Get-Date cmdlet
        $timestamp = [DateTime]::Now.ToString('HH:mm:ss')
        $method = $request.HttpMethod
        $remote = $request.RemoteEndPoint
        $userAgent = $request.UserAgent
        $isGitHub = $userAgent -match "GitHub-Hookshot"

        $sourceIcon = if ($isGitHub) { "🐙 GitHub " } else { "🔗 Web " }

        # Read body if available
        $body = $null
        if ($request.HasEntityBody) {
            # Performance: Use constructor directly and ensure proper disposal of the stream reader
            $reader = [System.IO.StreamReader]::new($request.InputStream, $utf8)
            $body = $reader.ReadToEnd()
            $reader.Dispose()
        }

        # ⚡ BOLT OPTIMIZATION: Early Response
        # We send the response IMMEDIATELY after reading the body to minimize latency for the sender (e.g. GitHub).
        # Expensive operations like JSON pretty-printing and console logging happen AFTER the connection is closed.
        $response.ContentLength64 = $responseBytes.Length
        $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
        $response.Close()

        Write-Host "[$timestamp] " -ForegroundColor Gray -NoNewline
        Write-Host "$sourceIcon" -ForegroundColor Magenta -NoNewline
        Write-Host "$method " -ForegroundColor Yellow -NoNewline
        Write-Host "from " -ForegroundColor Gray -NoNewline
        Write-Host "$remote" -ForegroundColor White

        if ($null -ne $body) {
            try {
                if ($request.ContentType -match "application/json") {
                    # Performance: Use -InputObject parameter instead of pipeline for faster processing
                    $jsonObj = ConvertFrom-Json -InputObject $body
                    $prettyBody = ConvertTo-Json -InputObject $jsonObj -Depth 10
                    Write-Host "Payload (JSON):" -ForegroundColor Cyan
                    Write-Host $prettyBody -ForegroundColor DarkGray
                } else {
                    Write-Host "Payload:" -ForegroundColor Cyan
                    Write-Host $body -ForegroundColor DarkGray
                }
            } catch {
                Write-Host "Payload (Raw):" -ForegroundColor Cyan
                Write-Host $body -ForegroundColor DarkGray
            }
        }

        Write-Host "Done.`n" -ForegroundColor DarkGray
    }
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($null -ne $listener) {
        $listener.Stop()
    }
}

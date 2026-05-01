[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
<#
.SYNOPSIS
    Initialises the System Automation Hub environment.

.DESCRIPTION
    Prints a startup banner confirming that the Automation Hub has been
    initialised, along with the machine name and operator username.
    Intended to be dot-sourced or invoked at the beginning of an automation
    session to provide a clear, consistent startup message.

.EXAMPLE
    .\scripts\init.ps1
    # Output:
    # Automation Hub Initialized
    # Machine: RIZWAN
    # User:    ruhal

.NOTES
    PSAvoidUsingWriteHost is suppressed intentionally; this script targets
    interactive console sessions where Write-Host colour output is desirable.
#>
param()
Write-Host 'Automation Hub Initialized' -ForegroundColor Cyan
Write-Host 'Machine:' RIZWAN
Write-Host 'User:' ruhal

<#
.SYNOPSIS
    Pester test suite for the System Automation Hub repository.

.DESCRIPTION
    Contains two Describe blocks:

    1. "System Automation Hub Structure"
       Verifies that the key entry-point files expected by the project exist
       on disk:
         - start-automation.ps1 (main launcher)
         - webhooks/listener.ps1 (HTTP webhook listener)
         - At least one *.ps1 file inside scripts/

    2. "PowerShell Script Syntax Verification"
       Discovers all *.ps1 files in the repository (recursively from the
       parent of the tests directory) and validates each one with the
       PowerShell AST parser ([System.Management.Automation.Language.Parser]).
       Any file containing syntax errors causes its test case to fail with a
       descriptive message including the error text and line/column numbers.

.NOTES
    - Run with Pester 5+:  Invoke-Pester -Path ./tests
    - No external module dependencies beyond Pester itself are required for
      the syntax check; the built-in PowerShell parser is used directly.
    - The test suite is executed automatically by the PowerShell CI workflow
      (.github/workflows/powershell-ci.yml) on every push and pull request
      to the main branch.
#>

Describe "System Automation Hub Structure" {
    It "Should have the main entry point (start-automation.ps1)" {
        Test-Path "./start-automation.ps1" | Should -Be $true
    }

    It "Should have the webhooks/listener.ps1 script" {
        Test-Path "./webhooks/listener.ps1" | Should -Be $true
    }

    It "Should have at least one script in the scripts/ directory" {
        (Get-ChildItem "./scripts/*.ps1").Count | Should -BeGreaterOrEqual 1
    }
}

Describe "PowerShell Script Syntax Verification" {
    Context "Checking all .ps1 files" {
        $psFiles = Get-ChildItem -Path $PSScriptRoot/.. -Include *.ps1 -Recurse

        It "Should have valid syntax for <Name>" -ForEach $psFiles {
            $errors = $null
            $tokens = $null
            # Use the built-in Parser to verify syntax without external module dependencies
            [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null

            if ($errors) {
                $errorMessages = $errors | ForEach-Object { "$($_.Message) at line $($_.Extent.StartLineNumber):$($_.Extent.StartColumnNumber)" }
                throw "Syntax errors found in $($_.Name):`n$($errorMessages -join "`n")"
            }
        }
    }
}

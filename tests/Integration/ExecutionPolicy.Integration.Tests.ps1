$script:dscModuleName   = 'PSDesiredStateConfiguration' # Need something that is already present
$script:dscResourceName = 'NoResource'

try
{
    Import-Module -Name DscResource.Test -Force
}
catch [System.IO.FileNotFoundException]
{
    throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
}

Write-Verbose -Message ("Execution Policy before Initialize-TestEnvironment:`r`n{0}" -f (Get-ExecutionPolicy -List | Out-String)) -Verbose

$script:testEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:dscModuleName `
    -DSCResourceName $script:dscResourceName `
    -ResourceType 'Mof' `
    -TestType 'Integration' `
    -Verbose

Write-Verbose -Message ("Execution Policy after Initialize-TestEnvironment:`r`n{0}" -f (Get-ExecutionPolicy -List | Out-String)) -Verbose

try
{
    Describe 'Empty test' {
        It 'Should pass' {
            $true | Should -BeTrue
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment -Verbose

    Write-Verbose -Message ("Execution Policy after Restore-TestEnvironment:`r`n{0}" -f (Get-ExecutionPolicy -List | Out-String)) -Verbose
}

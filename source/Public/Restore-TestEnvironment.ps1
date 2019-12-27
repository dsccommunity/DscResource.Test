<#
    .SYNOPSIS
        Restores the environment after running unit or integration tests
        on a DSC resource.

        This restores the following changes made by calling
        Initialize-TestEnvironment:
        1. Restores the $env:PSModulePath if it was changed.
        2. Restores the PowerShell execution policy.
        3. Resets the DSC LCM if running Integration tests.

    .PARAMETER TestEnvironment
        The hashtable created by the Initialize-TestEnvironment.

    .EXAMPLE
        Restore-TestEnvironment -TestEnvironment $TestEnvironment
#>
function Restore-TestEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]
        $TestEnvironment
    )

    Write-Verbose -Message "Cleaning up Test Environment after $($TestEnvironment.TestType) testing of $($TestEnvironment.DSCResourceName) in module $($TestEnvironment.DSCModuleName)."

    if ($TestEnvironment.TestType -ieq 'Integration')
    {
        # Clear the DSC LCM & Configurations
        Clear-DscLcmConfiguration
    }

    # Restore PSModulePath
    if ($TestEnvironment.OldPSModulePath -ne $env:PSModulePath)
    {
        Set-PSModulePath -Path $TestEnvironment.OldPSModulePath

        if ($TestEnvironment.TestType -eq 'Integration')
        {
            # Restore the machine PSModulePath for integration tests.
            Set-PSModulePath -Path $TestEnvironment.OldPSModulePath -Machine
        }
    }

    # Restore the Execution Policy
    if ($TestEnvironment.OldExecutionPolicy -ne (Get-ExecutionPolicy))
    {
        Set-ExecutionPolicy -ExecutionPolicy $TestEnvironment.OldExecutionPolicy -Scope 'Process' -Force
    }

    if ($script:MachineOldPSModulePath)
    {
        [System.Environment]::SetEnvironmentVariable('PSModulePath', $script:MachineOldPSModulePath, 'Machine')
    }

    if ($script:MachineOldExecutionPolicy)
    {
        Set-ExecutionPolicy -ExecutionPolicy $script:MachineOldExecutionPolicy -Scope LocalMachine -Force -ErrorAction Stop

        $script:MachineOldExecutionPolicy = $null
    }
}

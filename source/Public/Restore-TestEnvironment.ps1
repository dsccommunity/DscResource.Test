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
        [System.Collections.Hashtable]
        $TestEnvironment,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $KeepNewMachinePSModulePath
    )

    Write-Verbose -Message "Cleaning up Test Environment after $($TestEnvironment.TestType) testing of $($TestEnvironment.DSCResourceName) in module $($TestEnvironment.DSCModuleName)."

    if ($TestEnvironment.TestType -in ('Integration','All'))
    {
        # Clear the DSC LCM & Configurations
        Clear-DscLcmConfiguration

        if ($script:machineOldPSModulePath)
        {
            if ($KeepNewMachinePSModulePath.IsPresent)
            {
                $currentMachinePSModulePath = [System.Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')

                if ($currentMachinePSModulePath)
                {
                    $script:machineOldPSModulePath = Join-PSModulePath -Path $script:machineOldPSModulePath -NewPath $currentMachinePSModulePath
                }
            }

            <#
                Restore the machine PSModulePath. The variable $script:machineOldPSModulePath
                is also used in suffix.ps1.
            #>
            Set-PSModulePath -Path $script:machineOldPSModulePath -Machine -ErrorAction 'Stop'

            $script:machineOldPSModulePath = $null
        }
    }

    # Restore PSModulePath
    if ($TestEnvironment.OldPSModulePath -ne $env:PSModulePath)
    {
        Set-PSModulePath -Path $TestEnvironment.OldPSModulePath
    }

    # Restore the Execution Policy
    if ($TestEnvironment.OldExecutionPolicy -ne (Get-ExecutionPolicy))
    {
        Set-ExecutionPolicy -ExecutionPolicy $TestEnvironment.OldExecutionPolicy -Scope 'Process' -Force
    }

    if ($script:MachineOldExecutionPolicy)
    {
        Set-ExecutionPolicy -ExecutionPolicy $script:MachineOldExecutionPolicy -Scope LocalMachine -Force -ErrorAction Stop

        $script:MachineOldExecutionPolicy = $null
    }
}

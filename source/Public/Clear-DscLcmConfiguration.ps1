<#
    .SYNOPSIS
        Clear the DSC LCM by performing the following functions:
        1. Cancel any currently executing DSC LCM operations
        2. Remove any DSC configurations that:
            - are currently applied
            - are pending application
            - have been previously applied

        The purpose of this function is to ensure the DSC LCM is in a known
        and idle state before an integration test is performed that will
        apply a configuration.

        This is to prevent an integration test from being performed but failing
        because the DSC LCM is applying a previous configuration.

        This function should be called after each Describe block in an integration
        test to ensure the DSC LCM is reset before another test DSC configuration
        is applied.

    .EXAMPLE
        Clear-DscLcmConfiguration

        This command will Stop the DSC LCM and clear out any DSC configurations.
#>
function Clear-DscLcmConfiguration
{
    [CmdletBinding()]
    param ()

    if ($PSVersionTable.PSVersion.Major -gt 5)
    {
        Write-Verbose "The LCM is a Windows PowerShell version only"
        return
    }

    Write-Verbose -Message 'Stopping current LCM configuration and Clearing the DSC Configuration Documents'
    Stop-DscConfiguration -ErrorAction 'SilentlyContinue' -Force
    Remove-DscConfigurationDocument -Stage 'Current' -Force
    Remove-DscConfigurationDocument -Stage 'Pending' -Force
    Remove-DscConfigurationDocument -Stage 'Previous' -Force
}

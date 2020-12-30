<#
    .SYNOPSIS
        Waits for LCM to become idle.

    .PARAMETER Clear
        If specified, the LCM will also be cleared of DSC configurations.

    .NOTES
        Used in integration test where integration tests run to quickly before
        LCM have time to cool down.
#>
function Wait-ForIdleLcm
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Clear
    )

    while ((Get-DscLocalConfigurationManager).LCMState -ne 'Idle')
    {
        Write-Verbose -Message 'Waiting for the LCM to become idle'

        Start-Sleep -Seconds 2
    }

    if ($Clear)
    {
        Clear-DscLcmConfiguration
    }
}

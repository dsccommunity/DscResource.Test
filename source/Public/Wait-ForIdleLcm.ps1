<#
    .SYNOPSIS
        Waits for LCM to return from busy state.

    .PARAMETER Clear
        If specified, the LCM will also be cleared of DSC configurations.

    .PARAMETER Timeout
        Specifies the timeout in seconds when the command returns regardless of
        state. If not specified it waits indefinitely for LCM to change `LCMState`
        from 'Busy'.

    .NOTES
        Used in integration test where integration tests run to quickly before
        LCM have time to cool down.

        It will return if the LCM state is other than 'Busy'. The other states are
        'Idle', 'PendingConfiguration', or 'PendingReboot'.
#>
function Wait-ForIdleLcm
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Clear,

        [Parameter()]
        [System.TimeSpan]
        $Timeout
    )

    $timer = $null

    if ($PSBoundParameters.ContainsKey('Timeout'))
    {
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
    }

    <#
        When LCM is:

        Running - LCMState is set to 'Busy'
        Successful - LCMState is set to 'Idle' (eventually)
        Failed - LCMState is set to 'PendingConfiguration'
        Requires restart - LCMState is set to 'PendingReboot'
    #>
    while ((Get-DscLocalConfigurationManager).LCMState -eq 'Busy')
    {
        Write-Verbose -Message 'Waiting for the LCM to become idle'

        if ($timer -and $timer.Elapsed -ge $Timeout)
        {
            break
        }

        Start-Sleep -Seconds 2
    }

    if ($timer)
    {
        $timer.Stop()
    }

    if ($Clear)
    {
        Clear-DscLcmConfiguration
    }
}

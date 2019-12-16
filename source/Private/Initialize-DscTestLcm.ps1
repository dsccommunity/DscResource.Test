
<#
    .SYNOPSIS
        This command will initialize the Local Configuration Manager for Integration tests.
        It's meant to be used before running tests.

    .PARAMETER DisableConsistency
        This will switch off monitoring (consistency) for the Local Configuration
        Manager (LCM), setting ConfigurationMode to 'ApplyOnly', on the node
        running tests.

    .PARAMETER Encrypt
        This will switch on encryption for the Local Configuration
        Manager (LCM), setting CertificateId to the thumbprint stored in
        $env:DscCertificateThumbprint, on the node running tests.

        When using this parameter any configuration used for an integration
        test must have CertificateFile pointing to path stored in
        $env:DscPublicCertificatePath.
#>
function Initialize-DscTestLcm
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [Switch]
        $DisableConsistency,

        [Parameter()]
        [Switch]
        $Encrypt
    )

    $disableConsistencyMofPath = Join-Path -Path $env:temp -ChildPath 'DscTestLCMConfiguration'
    if (-not (Test-Path -Path $disableConsistencyMofPath))
    {
        $null = New-Item -Path $disableConsistencyMofPath -ItemType Directory -Force
    }

    # Start of the metadata configuration
    $configurationMetadata = '
        Configuration LocalConfigurationManagerConfiguration
        {
            LocalConfigurationManager
            {
    '

    if ($DisableConsistency.IsPresent)
    {
        Write-Verbose -Message 'Setting Local Configuration Manager property ConfigurationMode to ''ApplyOnly'', disabling consistency check.'
        # Have LCM Apply only once.
        $configurationMetadata += '
            ConfigurationMode = ''ApplyOnly''
        '
    }

    if ($Encrypt.IsPresent)
    {
        Write-Verbose -Message ('Setting Local Configuration Manager property CertificateId to ''{0}'', enabling decryption of credentials.' -f $env:DscCertificateThumbprint)
        # Should use encryption.
        $configurationMetadata += ('
            CertificateId = ''{0}''
        ' -f $env:DscCertificateThumbprint)
    }

    # End of the metadata configuration
    $configurationMetadata += '
            }
        }
    '

    Invoke-Command -ScriptBlock ([scriptblock]::Create($configurationMetadata)) -NoNewScope

    $null = LocalConfigurationManagerConfiguration -OutputPath $disableConsistencyMofPath

    Set-DscLocalConfigurationManager -Path $disableConsistencyMofPath -Force -Verbose
    $null = Remove-Item -LiteralPath $disableConsistencyMofPath -Recurse -Force -Confirm:$false
}

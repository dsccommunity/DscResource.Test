
<#
    .SYNOPSIS
        This command will create a new self-signed certificate to be used to
        compile configurations.

    .OUTPUTS
        Returns the created certificate. Writes the path to the public
        certificate in the machine environment variable $env:DscPublicCertificatePath,
        and the certificate thumbprint in the machine environment variable
        $env:DscCertificateThumbprint.

    .NOTES
        If a certificate with subject 'DscEncryptionCert' already exists, that
        certificate will be returned instead of creating a new, and will assume
        that the existing certificate was created with this command.
#>
function New-DscSelfSignedCertificate
{
    $dscPublicCertificatePath = Join-Path -Path $env:temp -ChildPath 'DscPublicKey.cer'

    $certificateSubject = 'TestDscEncryptionCert'

    # Look if there already is an existing certificate.
    $certificate = Get-ChildItem -Path 'cert:\LocalMachine\My' |
        Where-Object -FilterScript {
            $_.Subject -eq "CN=$certificateSubject"
        } | Select-Object -First 1

    if (-not $certificate)
    {
        $getCommandParameters = @{
            Name        = 'New-SelfSignedCertificate'
            ErrorAction = 'SilentlyContinue'
        }

        $newSelfSignedCertificateCommand = Get-Command @getCommandParameters

        $hasNewSelfSignedCertificateCommand = $newSelfSignedCertificateCommand `
            -and $newSelfSignedCertificateCommand.Parameters.Keys -contains 'Type'

        if ($hasNewSelfSignedCertificateCommand)
        {
            $newSelfSignedCertificateParameters = @{
                Type          = 'DocumentEncryptionCertLegacyCsp'
                DnsName       = $certificateSubject
                HashAlgorithm = 'SHA256'
            }

            $certificate = New-SelfSignedCertificate @newSelfSignedCertificateParameters
        }
        else
        {
            <#
                There are build workers still on Windows Server 2012 R2 so let's
                use the alternate method of New-SelfSignedCertificate.
            #>
            # If you use this, declare PSPKI in RequiredModules, or install it
            Import-Module -Name PSPKI -ErrorAction Stop

            $newSelfSignedCertificateExParameters = @{
                Subject            = "CN=$certificateSubject"
                EKU                = 'Document Encryption'
                KeyUsage           = 'KeyEncipherment, DataEncipherment'
                SAN                = "dns:$certificateSubject"
                FriendlyName       = 'DSC Credential Encryption certificate'
                Exportable         = $true
                StoreLocation      = 'LocalMachine'
                KeyLength          = 2048
                ProviderName       = 'Microsoft Enhanced Cryptographic Provider v1.0'
                AlgorithmName      = 'RSA'
                SignatureAlgorithm = 'SHA256'
            }

            $certificate = New-SelfSignedCertificateEx @newSelfSignedCertificateExParameters
        }

        Write-Verbose -Message ('Created self-signed certificate ''{0}'' with thumbprint ''{1}''.' -f $certificate.Subject, $certificate.Thumbprint)
    }
    else
    {
        Write-Verbose -Message ('Using self-signed certificate ''{0}'' with thumbprint ''{1}''.' -f $certificate.Subject, $certificate.Thumbprint)
    }

    # Export the public key certificate
    Export-Certificate -Cert $certificate -FilePath $dscPublicCertificatePath -Force

    # Update a machine and session environment variable with the path to the public certificate.
    Set-EnvironmentVariable -Name 'DscPublicCertificatePath' -Value $dscPublicCertificatePath -Machine
    Write-Verbose -Message ('Environment variable $env:DscPublicCertificatePath set to ''{0}''' -f $env:DscPublicCertificatePath)

    # Update a machine and session environment variable with the thumbprint of the certificate.
    Set-EnvironmentVariable -Name 'DscCertificateThumbprint' -Value $certificate.Thumbprint -Machine
    Write-Verbose -Message ('Environment variable $env:DscCertificateThumbprint set to ''{0}''' -f $env:DscCertificateThumbprint)

    return $certificate
}

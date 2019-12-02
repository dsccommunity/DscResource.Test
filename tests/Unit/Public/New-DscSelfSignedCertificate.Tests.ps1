$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'New-DscSelfSignedCertificate' -Tag WindowsOnly {
        BeforeAll {
            $mockCertificateDNSNames = @('TestDscEncryptionCert')
            $mockCertificateKeyUsage = @('KeyEncipherment', 'DataEncipherment')
            $mockCertificateEKU = @('Document Encryption')
            $mockCertificateSubject = 'TestDscEncryptionCert'
            $mockCertificateFriendlyName = 'TestDscEncryptionCert'
            $mockCertificateThumbprint = '1111111111111111111111111111111111111111'

            $validCertificate = New-Object -TypeName PSObject -Property @{
                Thumbprint        = $mockCertificateThumbprint
                Subject           = "CN=$mockCertificateSubject"
                Issuer            = "CN=$mockCertificateSubject"
                FriendlyName      = $mockCertificateFriendlyName
                DnsNameList       = @(
                    @{ Unicode = $mockCertificateDNSNames[0] }
                )
                Extensions        = @(
                    @{ EnhancedKeyUsages = ($mockCertificateKeyUsage -join ', ') }
                )
                EnhancedKeyUsages = @(
                    @{ FriendlyName = $mockCertificateEKU[0] }
                    @{ FriendlyName = $mockCertificateEKU[1] }
                )
                NotBefore         = (Get-Date).AddDays(-30) # Issued on
                NotAfter          = (Get-Date).AddDays(31) # Expires after
            }

            <#
                This stub is needed because the real Export-Certificate's $cert
                parameter requires an actual [X509Certificate2] object.
            #>
            function Export-Certificate
            {
            }
        }

        Context 'When creating a self-signed certificate for Windows Server 2012 R2' {
            BeforeAll {
                <#
                    Stub to have something to mock on since we can't wait for
                    the Expand-Archive to create the stub that is dot-sourced
                    on runtime.
                #>
                function New-SelfSignedCertificateEx
                {
                }

                Mock -CommandName Get-ChildItem
                Mock -CommandName Get-Command
                Mock -CommandName Import-Module
                Mock -CommandName Export-Certificate
                Mock -CommandName Set-EnvironmentVariable
                Mock -CommandName New-SelfSignedCertificateEx -MockWith {
                    return $validCertificate
                }
            }

            It 'Should return a certificate and call the correct mocks' -skip:($PSversionTable.PSVersion.Major -gt 5) {
                $result = New-DscSelfSignedCertificate
                $result.Thumbprint | Should -Be $mockCertificateThumbprint
                $result.Subject | Should -Be "CN=$mockCertificateSubject"

                Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 1
                Assert-MockCalled -CommandName Get-Command -Exactly -Times 1
                Assert-MockCalled -CommandName Import-Module -Exactly -Times 1
                Assert-MockCalled -CommandName New-SelfSignedCertificateEx -Exactly -Times 1

                Assert-MockCalled -CommandName Set-EnvironmentVariable -ParameterFilter {
                    $Name -eq 'DscPublicCertificatePath' `
                        -and $Value -eq (Join-Path -Path $env:temp -ChildPath 'DscPublicKey.cer')
                } -Exactly -Times 1

                Assert-MockCalled -CommandName Set-EnvironmentVariable -ParameterFilter {
                    $Name -eq 'DscCertificateThumbprint' `
                        -and $Value -eq $mockCertificateThumbprint
                } -Exactly -Times 1
            }
        }

        Context 'When creating a self-signed certificate for Windows Server 2016' {
            BeforeAll {
                <#
                    Stub is needed if tests is run on operating system older
                    than Windows 10 and Windows Server 2016.
                #>
                function New-SelfSignedCertificate
                {
                }

                Mock -CommandName Get-ChildItem
                Mock -CommandName Get-Command -MockWith {
                    return @{
                        Parameters = @{
                            Keys = @('Type')
                        }
                    }
                }

                Mock -CommandName Export-Certificate
                Mock -CommandName Set-EnvironmentVariable
                Mock -CommandName New-SelfSignedCertificate -MockWith {
                    return $validCertificate
                }
            }

            It 'Should return a certificate and call the correct cmdlets' -skip:($PSversionTable.PSVersion.Major -gt 5) {
                $result = New-DscSelfSignedCertificate
                $result.Thumbprint | Should -Be $mockCertificateThumbprint
                $result.Subject | Should -Be "CN=$mockCertificateSubject"

                Assert-MockCalled -CommandName Get-ChildItem -Exactly -Times 1
                Assert-MockCalled -CommandName Get-Command -Exactly -Times 1
                Assert-MockCalled -CommandName New-SelfSignedCertificate -Exactly -Times 1
                Assert-MockCalled -CommandName Set-EnvironmentVariable -ParameterFilter {
                    $Name -eq 'DscPublicCertificatePath' `
                        -and $Value -eq (Join-Path -Path $env:temp -ChildPath 'DscPublicKey.cer')
                } -Exactly -Times 1

                Assert-MockCalled -CommandName Set-EnvironmentVariable -ParameterFilter {
                    $Name -eq 'DscCertificateThumbprint' `
                        -and $Value -eq $mockCertificateThumbprint
                } -Exactly -Times 1
            }
        }

        Context 'When a self-signed certificate already exists' {
            BeforeAll {
                Mock -CommandName Get-ChildItem -MockWith {
                    return $validCertificate
                }

                <#
                    Stub to have something to mock on since we can't wait for
                    the Expand-Archive to create the stub that is dot-sourced
                    on runtime.
                #>
                function New-SelfSignedCertificateEx
                {
                }

                Mock -CommandName New-SelfSignedCertificateEx
                Mock -CommandName New-SelfSignedCertificate
                Mock -CommandName Set-EnvironmentVariable
                Mock -CommandName Import-Module
                Mock -CommandName Export-Certificate
            }

            It 'Should return a certificate and call the correct cmdlets' -skip:($PSversionTable.PSVersion.Major -gt 5) {
                $result = New-DscSelfSignedCertificate
                $result.Thumbprint | Should -Be $mockCertificateThumbprint
                $result.Subject | Should -Be "CN=$mockCertificateSubject"

                Assert-MockCalled -CommandName New-SelfSignedCertificate -Exactly -Times 0
                Assert-MockCalled -CommandName New-SelfSignedCertificateEx -Exactly -Times 0
                Assert-MockCalled -CommandName Set-EnvironmentVariable -ParameterFilter {
                    $Name -eq 'DscPublicCertificatePath' `
                        -and $Value -eq (Join-Path -Path $env:temp -ChildPath 'DscPublicKey.cer')
                } -Exactly -Times 1

                Assert-MockCalled -CommandName Set-EnvironmentVariable -ParameterFilter {
                    $Name -eq 'DscCertificateThumbprint' `
                        -and $Value -eq $mockCertificateThumbprint
                } -Exactly -Times 1
                Assert-MockCalled -CommandName Import-Module -Exactly -Times 0
                Assert-MockCalled -CommandName Export-Certificate -Exactly -Times 1
            }
        }
    }
}

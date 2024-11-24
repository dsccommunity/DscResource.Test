[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param ()

BeforeDiscovery {
    try
    {
        if (-not (Get-Module -Name 'DscResource.Test'))
        {
            # Assumes dependencies has been resolved, so if this module is not available, run 'noop' task.
            if (-not (Get-Module -Name 'DscResource.Test' -ListAvailable))
            {
                # Redirect all streams to $null, except the error stream (stream 2)
                & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 3>&1 4>&1 5>&1 6>&1 > $null
            }

            # If the dependencies has not been resolved, this will throw an error.
            Import-Module -Name 'DscResource.Test' -Force -ErrorAction 'Stop'
        }
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -ResolveDependency -Tasks build" first.'
    }
}

BeforeAll {
    $script:moduleName = 'DscResource.Test'

    # Make sure there are not other modules imported that will conflict with mocks.
    Get-Module -Name $script:moduleName -All | Remove-Module -Force

    # Re-import the module using force to get any code changes between runs.
    Import-Module -Name $script:moduleName -Force -ErrorAction 'Stop'

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:moduleName
}

AfterAll {
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'New-DscSelfSignedCertificate' -Tag WindowsOnly -Skip:($PSVersionTable.PSVersion.Major -gt 5) {
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

        InModuleScope -ScriptBlock {
            function script:New-SelfSignedCertificateEx
            {
            }

            function script:Export-Certificate
            {
            }
        }
    }

    Context 'When creating a self-signed certificate for Windows Server 2012 R2' {
        BeforeAll {
            Mock -CommandName Get-ChildItem
            Mock -CommandName Get-Command
            Mock -CommandName Import-Module
            Mock -CommandName Export-Certificate
            Mock -CommandName Set-EnvironmentVariable
            Mock -CommandName New-SelfSignedCertificateEx -MockWith {
                return $validCertificate
            }
        }

        It 'Should return a certificate and call the correct mocks' {
            $result = New-DscSelfSignedCertificate
            $result.Thumbprint | Should -Be $mockCertificateThumbprint
            $result.Subject | Should -Be "CN=$mockCertificateSubject"

            Should -Invoke -CommandName Get-ChildItem -Exactly -Times 1
            Should -Invoke -CommandName Get-Command -Exactly -Times 1
            Should -Invoke -CommandName Import-Module -Exactly -Times 1
            Should -Invoke -CommandName New-SelfSignedCertificateEx -Exactly -Times 1

            Should -Invoke -CommandName Set-EnvironmentVariable -ParameterFilter {
                $Name -eq 'DscPublicCertificatePath' `
                    -and $Value -eq (Join-Path -Path $env:temp -ChildPath 'DscPublicKey.cer')
            } -Exactly -Times 1

            Should -Invoke -CommandName Set-EnvironmentVariable -ParameterFilter {
                $Name -eq 'DscCertificateThumbprint' `
                    -and $Value -eq $mockCertificateThumbprint
            } -Exactly -Times 1
        }
    }

    Context 'When creating a self-signed certificate for Windows Server 2016' {
        BeforeAll {
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

        It 'Should return a certificate and call the correct cmdlets' {
            $result = New-DscSelfSignedCertificate
            $result.Thumbprint | Should -Be $mockCertificateThumbprint
            $result.Subject | Should -Be "CN=$mockCertificateSubject"

            Should -Invoke -CommandName Get-ChildItem -Exactly -Times 1
            Should -Invoke -CommandName Get-Command -Exactly -Times 1
            Should -Invoke -CommandName New-SelfSignedCertificate -Exactly -Times 1
            Should -Invoke -CommandName Set-EnvironmentVariable -ParameterFilter {
                $Name -eq 'DscPublicCertificatePath' `
                    -and $Value -eq (Join-Path -Path $env:temp -ChildPath 'DscPublicKey.cer')
            } -Exactly -Times 1

            Should -Invoke -CommandName Set-EnvironmentVariable -ParameterFilter {
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

            Mock -CommandName New-SelfSignedCertificateEx
            Mock -CommandName New-SelfSignedCertificate
            Mock -CommandName Set-EnvironmentVariable
            Mock -CommandName Import-Module
            Mock -CommandName Export-Certificate
        }

        It 'Should return a certificate and call the correct cmdlets' {
            $result = New-DscSelfSignedCertificate
            $result.Thumbprint | Should -Be $mockCertificateThumbprint
            $result.Subject | Should -Be "CN=$mockCertificateSubject"

            Should -Invoke -CommandName New-SelfSignedCertificate -Exactly -Times 0
            Should -Invoke -CommandName New-SelfSignedCertificateEx -Exactly -Times 0
            Should -Invoke -CommandName Set-EnvironmentVariable -ParameterFilter {
                $Name -eq 'DscPublicCertificatePath' `
                    -and $Value -eq (Join-Path -Path $env:temp -ChildPath 'DscPublicKey.cer')
            } -Exactly -Times 1

            Should -Invoke -CommandName Set-EnvironmentVariable -ParameterFilter {
                $Name -eq 'DscCertificateThumbprint' `
                    -and $Value -eq $mockCertificateThumbprint
            } -Exactly -Times 1
            Should -Invoke -CommandName Import-Module -Exactly -Times 0
            Should -Invoke -CommandName Export-Certificate -Exactly -Times 1
        }
    }
}

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
                & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 2>&1 4>&1 5>&1 6>&1 > $null
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

Describe 'Get-StructuredObjectFromFile' -Tag 'Private' {
    BeforeAll {
        Mock -CommandName Import-PowerShellDataFile
        Mock -CommandName Get-Content
        Mock -CommandName Import-Module
        Import-Module powershell-yaml -Force -ErrorAction Stop
        Mock -CommandName ConvertFrom-Yaml
        Mock -CommandName ConvertFrom-Json
    }

    It 'Should Import a PowerShell DataFile when path extension is PSD1' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $null = Get-StructuredObjectFromFile -Path 'TestDrive:\tests.psd1'
        }

        Should -Invoke -CommandName Import-PowerShellDataFile -Exactly -Times 1 -Scope It
    }


    It 'Should ConvertFrom-Json when path extension is JSON' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $null = Get-StructuredObjectFromFile -Path 'TestDrive:\tests.json'
        }

        Should -Invoke -CommandName ConvertFrom-Json -Exactly -Times 1 -Scope It
    }

    It 'Should Import module & ConvertFrom-Yaml when path extension is Yaml' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $null = Get-StructuredObjectFromFile -Path 'TestDrive:\tests.yaml'
        }

        Should -Invoke -CommandName Import-Module -Exactly -Times 1 -Scope It
        Should -Invoke -CommandName ConvertFrom-Yaml -Exactly -Times 1 -Scope It
    }


    It 'Should throw when extension not one of the above' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            { Get-StructuredObjectFromFile -Path 'TestDrive:\tests.txt' } | Should -Throw
        }
    }
}

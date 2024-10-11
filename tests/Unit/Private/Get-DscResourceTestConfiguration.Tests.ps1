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

Describe 'Get-DscResourceTestConfiguration' {
    BeforeAll {
        Mock Get-StructuredObjectFromFile -MockWith { Param($Path) $Path }
        Mock ConvertTo-OrderedDictionary -MockWith { Param($Configuration) $Configuration }
        Mock Write-Debug
    }

    It 'Should have correct code path when passing IDictionary' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $null = Get-DscResourceTestConfiguration -Configuration @{ }
        }

        Should -Invoke -CommandName Write-Debug -Scope it -ParameterFilter { $message -eq 'Configuration Object is a Dictionary' }
        Should -Invoke -CommandName ConvertTo-OrderedDictionary -Scope It
    }

    It 'Should have correct code path when passing PSCustomObject' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $null = Get-DscResourceTestConfiguration -Configuration ([PSCustomObject]@{ })
        }

        Should -Invoke -CommandName Write-Debug -Scope it -ParameterFilter { $message -eq 'Configuration Object is a PSCustomObject' }
        Should -Invoke -CommandName ConvertTo-OrderedDictionary -Scope It
    }

    It 'Should have correct code path when passing a path' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $null = Get-DscResourceTestConfiguration -Configuration 'TestDrive:\.MetaOptIn.json'
        }

        Should -Invoke -CommandName Write-Debug -Scope it -ParameterFilter { $message -eq 'Configuration Object is a String, probably a Path' }
        Should -Invoke -CommandName Get-StructuredObjectFromFile -Scope It
        Should -Invoke -CommandName ConvertTo-OrderedDictionary -Scope It
    }

    It 'Should use MetaOptIn file by default' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $null = Get-DscResourceTestConfiguration
        }

        Should -Invoke -CommandName Write-Debug -Scope it -ParameterFilter { $message -eq 'Configuration Object is a String, probably a Path' }
        Should -Invoke -CommandName Get-StructuredObjectFromFile -Scope It
        Should -Invoke -CommandName ConvertTo-OrderedDictionary -Scope It
    }

    It 'Should throw when called passing int' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            { Get-DscResourceTestConfiguration -Configuration 2 } | Should -Throw
        }
    }
}

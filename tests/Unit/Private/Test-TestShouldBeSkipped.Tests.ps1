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

Describe 'Test-TestShouldBeSkipped' -Tag 'Private' {
    BeforeDiscovery {
        #Skip if any TestNames is excluded or TAG is used and not in the TestNames
        $Cases = @(
            @{
                TestNames     = @('Test1', 'Test 1')
                Tag           = @('Test1')
                ExcludeTag    = @()
                ShouldExclude = $false
                Description   = 'Should Test1 be skipped when I only want Test1 = $false'
            },
            @{
                TestNames     = @('Test1', 'Test 1')
                Tag           = @()
                ExcludeTag    = @('Test 1')
                ShouldExclude = $true
                Description   = 'Should Test1 be skipped when I exclude Test 1 = $true'
            },
            @{
                TestNames     = @('Test1', 'Test 1')
                Tag           = @()
                ExcludeTag    = @('Test 2')
                ShouldExclude = $false
                Description   = 'Should Test1 be skipped when I exclude Test2 = $false'
            },
            @{
                TestNames     = @('Test1', 'Test 1')
                Tag           = @()
                ExcludeTag    = @()
                ShouldExclude = $false
                Description   = 'Should Test1 be skipped when I dont specify = $false'
            }
        )
    }

    It 'Skip:<ShouldExclude> the specified test <testNames>' -TestCases $Cases {
        InModuleScope -Parameters $_ -ScriptBlock {
            Set-StrictMode -Version 1.0

            Test-TestShouldBeSkipped -TestNames $TestNames -Tag $Tag -ExcludeTag $ExcludeTag | Should -be $ShouldExclude
        }
    }
}

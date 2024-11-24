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

Describe 'Get-ModuleScriptResourceName' -Tag 'Private' {
    BeforeAll {
            $resourceName1 = 'TestResource1'
            $resourceName2 = 'TestResource2'
            $resourcesPath = Join-Path -Path $TestDrive -ChildPath 'DscResources'
            $testResourcePath1 = (Join-Path -Path $resourcesPath -ChildPath $resourceName1)
            $testResourcePath2 = (Join-Path -Path $resourcesPath -ChildPath $resourceName2)

            New-Item -Path $resourcesPath -ItemType Directory
            New-Item -Path $testResourcePath1 -ItemType Directory
            New-Item -Path $testResourcePath2 -ItemType Directory

            'resource_schema1' | Out-File -FilePath ('{0}.schema.mof' -f $testResourcePath1) -Encoding ascii
            'resource_schema2' | Out-File -FilePath ('{0}.schema.mof' -f $testResourcePath2) -Encoding ascii
    }

    Context 'When a module contains resources' {
        It 'Should return all the resource names' {
            InModuleScope -Parameters @{
                TestDrive = $TestDrive
                resourceName1 = $resourceName1
                resourceName2 = $resourceName2
            } -ScriptBlock {
                Set-StrictMode -Version 1.0

                $result = Get-ModuleScriptResourceName -ModulePath $TestDrive
                $result.Count | Should -Be 2
                $result[0] | Should -Be $resourceName1
                $result[1] | Should -Be $resourceName2
            }
        }
    }
}

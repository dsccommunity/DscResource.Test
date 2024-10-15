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

Describe 'Get-RelativePathFromModuleRoot' -Tag 'Private' {
    Context 'When to get the relative path from module root' {
        BeforeAll {
                $relativePath = 'Modules'
                $filePath = Join-Path $TestDrive -ChildPath $relativePath
                $moduleRootPath = $TestDrive

                # Adds a backslash to make sure it gets trimmed.
                $filePath += [io.path]::DirectorySeparatorChar
            }

        It 'Should return the correct relative path' {
            InModuleScope -Parameters @{
                filePath = $filePath
                moduleRootPath = $moduleRootPath
                relativePath = $relativePath
            } -ScriptBlock {
                Set-StrictMode -Version 1.0

                $mockGetParameters = @{
                    FilePath           = $filePath
                    ModuleRootFilePath = $moduleRootPath
                }

                $result = Get-RelativePathFromModuleRoot @mockGetParameters

                $result | Should -Be $relativePath
            }
        }
    }
}

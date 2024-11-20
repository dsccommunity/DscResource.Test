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

Describe 'Set-EnvironmentVariable' -Tag 'Private' {
    # BeforeAll {
    #     Mock -CommandName Set-Item
    # }

    # Context 'When setting a ''Machine'' variable' -Skip:(-not(
    # ($Principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())) -and
    #     $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    # )) {
    #     It 'Should set the correct EnvironmentVariable' {
    #         InModuleScope -ScriptBlock {
    #             Set-StrictMode -Version 1.0

    #             $setEnvironmentVariableParams = @{
    #                 Name = 'MyTestVariable'
    #                 Value = 'MyTestVariable'
    #                 Machine = $true
    #             }

    #             Set-EnvironmentVariable @setEnvironmentVariableParams
    #         }

    #         Should -Invoke -CommandName Set-Item -Exactly -Times 1 -Scope It
    #     }
    # }

    # Context 'When not setting a ''User'' variable' {
    #     It 'Should set the correct EnvironmentVariable' {
    #         InModuleScope -ScriptBlock {
    #             Set-StrictMode -Version 1.0

    #             $setEnvironmentVariableParams = @{
    #                 Name = 'MyTestVariable'
    #                 Value = 'MyTestVariable'
    #             }

    #             Set-EnvironmentVariable @setEnvironmentVariableParams
    #         }

    #         Should -Invoke -CommandName Set-Item -Exactly -Times 1 -Scope It
    #     }
    # }
}

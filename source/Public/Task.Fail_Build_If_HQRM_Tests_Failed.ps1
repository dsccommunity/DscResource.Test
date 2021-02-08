<#
    .SYNOPSIS
        This is the alias to the build task Invoke_HQRM_Tests's script file.

    .DESCRIPTION
        This makes available the alias 'Task.Invoke_HQRM_Tests' that is exported
        in the module manifest so that the build task can be correctly imported
        using for example Invoke-Build.

    .NOTES
        This is using the pattern lined out in the Invoke-Build repository
        https://github.com/nightroman/Invoke-Build/tree/master/Tasks/Import.
#>

Set-Alias -Name 'Task.Invoke_HQRM_Tests' -Value "$PSScriptRoot/tasks/Invoke_HQRM_Tests.build.ps1"

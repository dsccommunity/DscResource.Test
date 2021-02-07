<#
    .SYNOPSIS
        This is the alias to the build task Fail_Build_If_HQRM_Tests_Failed's
        script file.

    .DESCRIPTION
        This makes available the alias 'Task.Fail_Build_If_HQRM_Tests_Failed' that
        is exported in the module manifest so that the build task can be correctly
        imported using for example Invoke-Build.

    .NOTES
        This is using the pattern lined out in the Invoke-Build repository
        https://github.com/nightroman/Invoke-Build/tree/master/Tasks/Import.
#>

Set-Alias -Name 'Task.Fail_Build_If_HQRM_Tests_Failed' -Value "$PSScriptRoot/tasks/Fail_Build_If_HQRM_Tests_Failed.build.ps1"

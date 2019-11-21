<#
    .SYNOPSIS
        Common tests for all resource modules in the DSC Resource Kit.
#>
# Suppressing this because we need to generate a mocked credentials that will be passed along to the examples that are needed in the tests.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param()

Set-StrictMode -Version 'Latest'
$errorActionPreference = 'Stop'


$moduleRootFilePath = Split-Path -Path $PSScriptRoot -Parent

<#
    This is a workaround to be able to run these common test on DscResource.Tests
    module, for testing itself.
#>
if (Test-IsRepositoryDscResourceTests)
{
    $moduleRootFilePath = $PSScriptRoot

    <#
        Because the repository name of 'DscResource.Tests' has punctuation in
        the name, AppVeyor replaces that with a dash when it creates the folder
        structure, so the folder name becomes 'dscresource-tests'.
        This sets the module name to the correct name.
        If the name can be detected in a better way, for DscResource.Tests
        and all other modules, then this could be removed.
    #>
    $moduleName = 'DscResource.Tests'
}
else
{
    $moduleName = (Get-Item -Path $moduleRootFilePath).Name
}

$dscResourcesFolderFilePath = Join-Path -Path $moduleRootFilePath -ChildPath 'DscResources'

# Identify the repository root path of the resource module
$repoRootPath = $moduleRootFilePath
$repoRootPathFound = $false
while (-not $repoRootPathFound `
        -and -not ([String]::IsNullOrEmpty((Split-Path -Path $repoRootPath -Parent))))
{
    if (Get-ChildItem -Path $repoRootPath -Filter '.git' -Directory -Force)
    {
        $repoRootPathFound = $true
        break
    }
    else
    {
        $repoRootPath = Split-Path -Path $repoRootPath -Parent
    }
}
if (-not $repoRootPathFound)
{
    Write-Warning -Message ('The root folder of the DSC Resource repository could ' + `
            'not be located. This may prevent some markdown files from being checked for ' + `
            'errors. Please ensure this repository has been cloned using Git.')
    $repoRootPath = $moduleRootFilePath
}

$testOptInFilePath = Join-Path -Path $repoRootPath -ChildPath '.MetaTestOptIn.json'
# .MetaTestOptIn.json should be in the following format
# [
#     "Common Tests - Validate Module Files",
#     "Common Tests - Validate Markdown Files",
#     "Common Tests - Validate Example Files",
#     "Common Tests - Validate Script Files"
# ]

$optIns = @()
if (Test-Path $testOptInFilePath)
{
    $optIns = Get-Content -LiteralPath $testOptInFilePath | ConvertFrom-Json
}

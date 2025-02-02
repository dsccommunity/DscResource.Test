<#
    .NOTES
        To run manually:

        $dscResourceModuleName = 'FileSystemDsc'
        $pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

        $container = New-PesterContainer -Path "$pathToHQRMTests/RelativePathLength.common.*.Tests.ps1" -Data @{
            ModuleBase = "./output/$dscResourceModuleName/*"
        }

        Invoke-Pester -Container $container -Output Detailed
#>
param
(
    [Parameter(Mandatory = $true)]
    [System.String]
    $ModuleBase,

    [Parameter(ValueFromRemainingArguments = $true)]
    $Args
)

# This test _must_ be outside the BeforeDiscovery-block since Pester 4 does not recognizes it.
$isPesterMinimum5 = (Get-Module -Name Pester).Version -ge '5.1.0'

# Only run if Pester 5.1 or higher.
if (-not $isPesterMinimum5)
{
    Write-Verbose -Message 'Repository is using old Pester version, new HQRM tests for Pester v5 and v6 are skipped.' -Verbose
    return
}

<#
    This _must_ be outside any Pester blocks for correct script parsing. Sets It
    and Context block's default parameter value to handle Pester v6's ForEach change,
    to keep same behavior as with Pester v5. The default parameter is removed at
    the end of the script to avoid affecting other tests.
#>
$PSDefaultParameterValues['Context:AllowNullOrEmptyForEach'] = $true
$PSDefaultParameterValues['It:AllowNullOrEmptyForEach'] = $true

BeforeDiscovery {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force

    <#
        Expand the path if it is a relative path so Get-RelativePathFromModuleRoot
        will work correctly.
    #>
    $moduleBaseFullPath = Resolve-Path -Path $ModuleBase

    <#
        This must test the entire built module and _cannot_ exclude any files.
        There is no need to test SourcePath since only those files that are
        in the built module will be downloaded to Azure Automation.
    #>
    $allModuleFiles = Get-ChildItem -Path $moduleBaseFullPath -Recurse

    $moduleFileToTest = @()

    $allModuleFiles | ForEach-Object -Process {
        $moduleFileToTest += @{
            RelativePath = Get-RelativePathFromModuleRoot -FilePath $_.FullName -ModuleRootFilePath $moduleBaseFullPath
        }
    }
}

AfterAll {
    # Re-import just the public functions.
    Import-Module -Name 'DscResource.Test' -Force
}

Describe 'Common Tests - Relative Path Length' -Tag 'Common Tests - Relative Path Length' {
    Context 'When the resource should be used to compile a configuration in Azure Automation' {
        BeforeAll {
            <#
                129 characters is the current maximum for a relative path to be
                able to compile configurations in Azure Automation.
            #>
            $relativePathHardLimit = 129
        }

        It 'The length of the relative path <RelativePath> should not exceed the max hard limit' -ForEach $moduleFileToTest {
            $RelativePath.Length | Should -Not -BeGreaterThan $relativePathHardLimit -Because ('for the module to be able to be downloaded and used in Azure Automation the max lengths of the relative paths of the modules files much not be greater than {0} characters including path separators' -f $fullPathHardLimit)
        }
    }
}

$PSDefaultParameterValues.Remove('Context:AllowNullOrEmptyForEach')
$PSDefaultParameterValues.Remove('It:AllowNullOrEmptyForEach')

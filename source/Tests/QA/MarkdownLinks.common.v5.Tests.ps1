<#
    .NOTES
        To run manually:

        $dscResourceModuleName = 'FileSystemDsc'
        $pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

        $container = New-PesterContainer -Path "$pathToHQRMTests/MarkdownLinks.common.*.Tests.ps1" -Data @{
            $ProjectPath = '.'
            ModuleBase = "./output/$dscResourceModuleName/*"
            # SourcePath = './source'
            # ExcludeModuleFile = @('Modules/DscResource.Common')
            # ExcludeSourceFile = @('Examples')
        }

        Invoke-Pester -Container $container -Output Detailed
#>
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param
(
    [Parameter()]
    [System.String]
    $ProjectPath,

    [Parameter()]
    [System.String]
    $ModuleBase,

    [Parameter(Mandatory = $true)]
    [System.String]
    $SourcePath,

    [Parameter()]
    [System.String[]]
    $ExcludeSourceFile,

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
    This _must_ be outside any Pester blocks for correct script parsing.
    Sets Context block's default parameter value to handle Pester v6's ForEach
    change, to keep same behavior as with Pester v5. The default parameter is
    removed at the end of the script to avoid affecting other tests.
#>
$PSDefaultParameterValues['Context:AllowNullOrEmptyForEach'] = $true

BeforeDiscovery {
    if (-not $ProjectPath)
    {
        Write-Verbose -Message 'The Markdown links check only applies when testing a Source repository'
        return
    }

    <#
        This check need to be done in discovery otherwise the tests will
        fail when pester does "Run" on the missing cmdlet Get-MarkdownLink.
        Attempt was made to let discovery happen to indicate how many tests
        that was meant to run, and then skip all. A way to do that without
        Pester throwing was not found.
    #>
    if (-not (Get-Module -Name 'MarkdownLinkCheck' -ListAvailable))
    {
        Write-Warning -Message 'Required module MarkdownLinkCheck not found. Please add to RequiredModules.psd1'

        return
    }

    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force

    $markdownFileFilter = '*.md'

    # This will fetch files in the root of the project (repository) folder.
    $markdownFiles = [System.Collections.Generic.List[System.Object]]::new()
    $markdownFiles.AddRange(@(Get-ChildItem -Path $ProjectPath -Filter $markdownFileFilter))

    # This will recursively fetch all files in the source folder.
    $markdownFiles.AddRange(@(Get-ChildItem -Path $SourcePath -Recurse -Filter $markdownFileFilter | WhereSourceFileNotExcluded))

    # Expand the project folder if it is a relative path.
    $resolvedProjectPath = (Resolve-Path -Path $ProjectPath).Path

    #region Setup text file test cases.
    $markdownFileToTest = foreach ($file in $markdownFiles)
    {
        @{
            File            = $file
            # Use the root of the source folder to extrapolate relative path.
            DescriptiveName = (Get-RelativePathFromModuleRoot -FilePath $file.FullName -ModuleRootFilePath $resolvedProjectPath)
        }
    }
}

AfterAll {
    # Re-import just the public functions.
    Import-Module -Name 'DscResource.Test' -Force
}

Describe 'Common Tests - Validate Markdown Links' -Tag 'Common Tests - Validate Markdown Links' {
    Context 'When markdown file ''<DescriptiveName>'' exist' -ForEach $markdownFileToTest {
        It 'Should not contain any broken links' {
            $getMarkdownLinkParameters = @{
                BrokenOnly = $true
                Path       = $File.FullName
            }

            # Make sure it always returns an array even if Get-MarkdownLink returns $null.
            $brokenLinks = @(Get-MarkdownLink @getMarkdownLinkParameters)

            if ($brokenLinks.Count -gt 0)
            {
                # Write out all the errors so the contributor can resolve.
                $report = $brokenLinks |
                    Format-Table -AutoSize -Wrap -Property Line, Text, Url |
                    Out-String -Width 110

                $brokenLinks.Count | Should -Be 0 -Because "broken markdown links:`r`n`r`n $report`r`n `r`n ,"
            }
        }
    }
}

$PSDefaultParameterValues.Remove('Context:AllowNullOrEmptyForEach')

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
param
(
    [Parameter()]
    [System.String]
    $ProjectPath,

    [Parameter(Mandatory = $true)]
    [System.String]
    $ModuleBase,

    [Parameter()]
    [System.String]
    $SourcePath,

    [Parameter()]
    [System.String[]]
    $ExcludeModuleFile,

    [Parameter()]
    [System.String[]]
    $ExcludeSourceFile,

    [Parameter(ValueFromRemainingArguments = $true)]
    $Args
)

# This test _must_ be outside the BeforeDiscovery-block since Pester 4 does not recognizes it.
$isPester5 = (Get-Module -Name Pester).Version -ge '5.1.0'

# Only run if Pester 5.1.
if (-not $isPester5)
{
    Write-Verbose -Message 'Repository is using old Pester version, new HQRM tests for Pester 5 are skipped.' -Verbose
    return
}

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
    $markdownFiles = Get-ChildItem -Path $ProjectPath -Filter $markdownFileFilter

    # This will recursively fetch all files in the built module's folder.
    $markdownFiles += Get-ChildItem -Path $ModuleBase -Recurse -Filter $markdownFileFilter | `
        WhereModuleFileNotExcluded

    if ($SourcePath)
    {
        # This will recursively fetch all files in the source folder.
        $markdownFiles += Get-ChildItem -Path $SourcePath -Recurse -Filter $markdownFileFilter | `
            WhereSourceFileNotExcluded
    }

    # Expand the project folder if it is a relative path.
    $resolvedProjectPath = (Resolve-Path -Path $ProjectPath).Path

    #region Setup text file test cases.
    $markdownFileToTest = @()

    foreach ($file in $markdownFiles)
    {
        # Use the root of the source folder to extrapolate relative path.
        $descriptiveName = Get-RelativePathFromModuleRoot -FilePath $file.FullName -ModuleRootFilePath $resolvedProjectPath

        $markdownFileToTest += @(
            @{
                File            = $file
                DescriptiveName = $descriptiveName
            }
        )
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
                    Select-Object Line, Text, Url |
                    Format-Table -AutoSize -Wrap |
                    Out-String -Width 110

                $brokenLinks.Count | Should -Be 0 -Because "broken markdown links:`r`n`r`n $report`r`n `r`n ,"
            }
        }
    }
}

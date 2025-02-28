[Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ParameterBlockParameterAttribute', '', Scope='Function', Target='*')]
param (
    $ModuleName,
    $ModuleBase,
    $ModuleManifest,
    $ProjectPath,
    $SourcePath,
    $SourceManifest,
    $Tag,
    $ExcludeTag,
    $ExcludeSourceFile,
    $MainGitBranch
)

$isPester5 = (Get-Module -Name Pester).Version -lt '5.0.0'

# Only run if _not_ Pester 5.
if (-not $isPester5)
{
    return
}

if (!(Get-Module -Name 'MarkdownLinkCheck' -ListAvailable))
{
    Write-Warning -Message 'Required module MarkdownLinkCheck not found. Please add to RequiredModules.psd1'
    return
}

Describe 'Common Tests - Validate Markdown Links' -Tag 'Common Tests - Validate Markdown Links' {
    $markdownFileFilter = '*.md'

    $markdownFiles = @(
        (Get-ChildItem -Path $ProjectPath -File -Filter $markdownFileFilter)
        (Get-ChildItem -Path $SourcePath -File -Recurse -Filter $markdownFileFilter | WhereSourceFileNotExcluded)
    )

    foreach ($markdownFile in $markdownFiles)
    {
        $contextDescriptiveName = Join-Path -Path (Split-Path $markdownFile.Directory -Leaf) `
            -ChildPath (Split-Path $markdownFile -Leaf)

        Context $contextDescriptiveName {
            It 'Should not contain any broken links' {
                $getMarkdownLinkParameters = @{
                    BrokenOnly = $true
                    Path       = $markdownFile.FullName
                }

                # Make sure it always returns an array even if Get-MarkdownLink returns $null.
                $brokenLinks = @(Get-MarkdownLink @getMarkdownLinkParameters)

                if ($brokenLinks.Count -gt 0)
                {
                    # Write out all the errors so the contributor can resolve.
                    $report = $brokenLinks | Select-Object Line, Text, Url | Format-Table -AutoSize -Wrap | `
                        Out-String -Width 110
                    $brokenLinks.Count | Should -Be 0 -Because "broken markdown links:`r`n`r`n $report`r`n `r`n ,"
                }
            }
        }
    }
}

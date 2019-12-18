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
    $ExcludeModuleFile,
    $ExcludeSourceFile
)

Describe 'Common Tests - Validate Markdown Links' -Tag 'Common Tests - Validate Markdown Links' {

    $dependencyModuleName = 'MarkdownLinkCheck'
    $uninstallMarkdownLinkCheck = $false

    $markdownFileExtensions = @('.md')

    $markdownFiles = Get-TextFilesList $ModuleBase | `
        Where-Object -FilterScript { $markdownFileExtensions -contains $_.Extension }

    foreach ($markdownFileToValidate in $markdownFiles)
    {
        $contextDescriptiveName = Join-Path -Path (Split-Path $markdownFileToValidate.Directory -Leaf) -ChildPath (Split-Path $markdownFileToValidate -Leaf)

        Context -Name $contextDescriptiveName {
            It "Should not contain any broken links" {
                $getMarkdownLinkParameters = @{
                    BrokenOnly = $true
                    Path       = $markdownFileToValidate.FullName
                }

                # Make sure it always returns an array even if Get-MarkdownLink returns $null.
                $brokenLinks = @(Get-MarkdownLink @getMarkdownLinkParameters)

                if ($brokenLinks.Count -gt 0)
                {
                    # Write out all the errors so the contributor can resolve.
                    $report = $brokenLinks | Select-Object Line, Text, Url | Format-Table -AutoSize -Wrap | Out-String -Width 110
                    $brokenLinks.Count | Should -Be 0 -Because "broken markdown links:`r`n`r`n $report`r`n `r`n ,"
                }
            }
        }
    }
}

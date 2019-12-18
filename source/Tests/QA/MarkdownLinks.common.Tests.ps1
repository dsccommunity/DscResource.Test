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

    Context 'When installing markdown link validation dependencies' {
        It "Should not throw an error when installing and importing the module MarkdownLinkCheck" {
            {
                if (-not (Get-Module -Name $dependencyModuleName -ListAvailable))
                {
                    # Remember that we installed the module, so that it gets uninstalled.
                    $uninstallMarkdownLinkCheck = $true
                    Install-Module -Name $dependencyModuleName -Force -Scope 'CurrentUser' -ErrorAction Stop
                }

                Import-Module -Name $dependencyModuleName -Force
            } | Should -Not -Throw
        }
    }

    $markdownFileExtensions = @('.md')

    $markdownFiles = Get-TextFilesList $ModuleBase |
    Where-Object -FilterScript {
        $markdownFileExtensions -contains $_.Extension
    }

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
                    foreach ($brokenLink in $brokenLinks)
                    {
                        $message = 'Line {0}: [{1}] has broken URL "{2}"' -f $brokenLink.Line, $brokenLink.Text, $brokenLink.Url
                        Write-Host -BackgroundColor Yellow -ForegroundColor Black -Object $message
                    }
                }

                $brokenLinks.Count | Should -Be 0
            }
        }
    }

    if ($uninstallMarkdownLinkCheck)
    {
        Context 'When uninstalling markdown link validation dependencies' {
            It "Should not throw an error when uninstalling the module MarkdownLinkCheck" {
                {
                    <#
                        Remove the module from the current session as
                        Uninstall-Module does not do that.
                    #>
                    Remove-Module -Name $dependencyModuleName -Force
                    Uninstall-Module -Name $dependencyModuleName -Force -ErrorAction Stop
                } | Should -Not -Throw
            }
        }
    }
}

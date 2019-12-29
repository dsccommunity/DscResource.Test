[Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ParameterBlockParameterAttribute', '', Scope='Function', Target='*')]
param
(
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

if (-not $ProjectPath)
{
    # Invoke-DscResourceTest is only looking at a built module, skipping this test file.
    Write-Verbose "No Project path set: $ProjectPath. Skipping changelog checks."

    return
}
else
{
    Write-Verbose "Pushing location $ProjectPath on Stack ProjectTest"

    Push-Location -StackName ProjectTest -Path $ProjectPath
}

try
{
    Describe 'Changelog Management' -Tag 'Changelog' {
        $skipTest = -not (
                [System.Boolean] (Get-Command -Name 'git' -ErrorAction 'SilentlyContinue') `
                -and [System.Boolean] (& (Get-Process -Id $PID).Path -NoProfile -Command 'git rev-parse --is-inside-work-tree 2>$null')
            )

        It 'Changelog has been updated' -Skip:$skipTest {
            # Get the list of changed files compared with master
            $headCommit = & git rev-parse HEAD
            $masterCommit = & git rev-parse origin/master
            $filesChanged = & git diff $masterCommit...$headCommit --name-only

            if ($headCommit -ne $masterCommit)
            {
                 # if we're not testing same commit (i.e. master..master)
                $filesChanged.Where{
                    (Split-Path -Path $_ -Leaf) -match '^changelog.md'
                } | Should -Not -BeNullOrEmpty -Because 'the changelog should have at least one entry for every pull request'
            }
        }

        $skipTest = -not [System.Boolean] (Get-Command -Name 'git' -ErrorAction 'SilentlyContinue') `
            -or -not (Import-Module -Name ChangelogManagement -ErrorAction 'SilentlyContinue' -PassThru)

        It 'Changelog format compliant with keepachangelog format' -Skip:$skipTest {
            { Get-ChangelogData -Path (Join-Path -Path $ProjectPath -ChildPath 'CHANGELOG.md') -ErrorAction 'Stop' } | Should -Not -Throw
        }
    }
}
finally
{
    Write-Debug "Poping location on Stack ProjectTest"

    Pop-Location -StackName ProjectTest
}

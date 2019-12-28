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

if (!$ProjectPath)
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

        It 'Changelog has been updated' -skip:(
            !([bool](Get-Command git -EA SilentlyContinue) -and
              [bool](&(Get-Process -id $PID).Path -NoProfile -Command 'git rev-parse --is-inside-work-tree 2>$null'))
            ) {
            # Get the list of changed files compared with master
            $HeadCommit = &git rev-parse HEAD
            $MasterCommit = &git rev-parse origin/master
            $filesChanged = &git diff $MasterCommit...$HeadCommit --name-only

            if ($HeadCommit -ne $MasterCommit)
            {
                 # if we're not testing same commit (i.e. master..master)
                $filesChanged.Where{
                    (Split-Path $_ -Leaf) -match '^changelog'
                } | Should -Not -BeNullOrEmpty
            }
        }

        It 'Changelog format compliant with keepachangelog format' -skip:(
            ![bool](Get-Command git -EA SilentlyContinue) -or
            !(Import-Module -Name ChangelogManagement -ErrorAction SilentlyContinue -PassThru)
            ) {
            { Get-ChangelogData (Join-Path $ProjectPath 'CHANGELOG.md') -ErrorAction Stop } | Should -Not -Throw
        }
    }
}
finally
{
    Write-Debug "Poping location on Stack ProjectTest"
    Pop-Location -StackName ProjectTest
}

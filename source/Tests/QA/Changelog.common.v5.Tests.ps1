<#
    .NOTES
        To run manually:

        $defaultBranch = 'main'
        $pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

        $container = New-PesterContainer -Path "$pathToHQRMTests/Changelog.common.*.Tests.ps1" -Data @{
            ProjectPath = '.'
            MainGitBranch = $defaultBranch
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
    $MainGitBranch,

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
        # Invoke-DscResourceTest is only looking at a built module, skipping this test file.
        Write-Verbose "No Project path set: $ProjectPath. Skipping changelog checks."

        return
    }
    else
    {
        Write-Verbose "Pushing location $ProjectPath on Stack ProjectTest"

        Push-Location -StackName ProjectTest -Path $ProjectPath
    }
}

AfterAll {
    Write-Debug "Poping location on Stack ProjectTest"

    Pop-Location -StackName ProjectTest
}

Describe 'Changelog Management' -Tag 'Changelog' {
    Context 'When there is a git diff' {
        BeforeAll {
            $skipTest = -not (
                [System.Boolean] (Get-Command -Name 'git' -ErrorAction 'SilentlyContinue') `
                    -and [System.Boolean] (& (Get-Process -Id $PID).Path -NoProfile -Command 'git rev-parse --is-inside-work-tree 2>$null')
            )
        }

        It 'Should have CHANGELOG.md in the diff' -Skip:$skipTest {
            # Get the list of changed files compared with main
            $headCommit = & git rev-parse HEAD
            $mainCommit = & git @('rev-parse', "origin/$MainGitBranch")
            $filesChanged = & git @('diff', "$mainCommit...$headCommit", '--name-only')

            if ($headCommit -ne $mainCommit)
            {
                # if we're not testing same commit (i.e. main..main)
                $filesChanged.Where{
                    (Split-Path -Path $_ -Leaf) -match '^changelog.md'
                } | Should -Not -BeNullOrEmpty -Because 'the changelog should have at least one entry for every pull request'
            }
        }
    }

    Context 'When there is an CHANGELOG.md' {
        BeforeAll {
            $skipTest = -not [System.Boolean] (Get-Command -Name 'git' -ErrorAction 'SilentlyContinue') `
                -or -not (Import-Module -Name ChangelogManagement -ErrorAction 'SilentlyContinue' -PassThru)

            $pathToChangeLog = Join-Path -Path $ProjectPath -ChildPath 'CHANGELOG.md'
        }

        It 'Should have the change log entries compliant with keepachangelog format' -Skip:$skipTest {
            { Get-ChangelogData -Path $pathToChangeLog -ErrorAction 'Stop' } | Should -Not -Throw
        }

        It 'Should have an Unreleased header in the CHANGELOG.md' -Skip:$skipTest {
            (Get-ChangelogData -Path $pathToChangeLog -ErrorAction 'Stop').Unreleased.RawData | Should -Not -BeNullOrEmpty
        }
    }
}

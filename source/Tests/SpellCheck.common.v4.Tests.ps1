param
(
    $ModuleName,
    $ModuleBase,
    $ModuleManifest,
    $ProjectPath,
    $SourceManifest
)

$isPester5 = (Get-Module -Name Pester).Version -lt '5.0.0'

# Only run if _not_ Pester 5.
if (-not $isPester5)
{
    return
}

Describe 'Common Tests - Spellcheck Files' -Tag 'Spellcheck','Common Tests - Spellcheck Files' {
    BeforeAll {
        $npmParametersForStartProcess = @{
            FilePath         = 'npm'
            ArgumentList     = ''
            WorkingDirectory = $ProjectPath
            Wait             = $true
            WindowStyle      = 'Hidden'
        }
    }

    if ((Get-Command -Name 'npm' -ErrorAction SilentlyContinue))
    {
        $skipDependency = $false
    }
    else
    {
        Write-Warning -Message ('Unable to run cSpell to spellcheck markdown files. Please ' + `
            'be sure that you have installed nodejs and npm in order ' + `
            'to have this text execute.')

        $skipDependency = $true
    }

    Context 'When installing spellcheck dependencies' {
        It 'Should not throw an error when installing package cSpell in global scope' -Skip:$skipDependency {
            {
                # More information about cSpell: https://www.npmjs.com/package/cspell
                $npmParametersForStartProcess['ArgumentList'] = 'install -g cspell'
                Start-Process @npmParametersForStartProcess
            } | Should -Not -Throw
        }
    }

    # If npm wasn't installed then we can't run this test.

    Context 'When there are markdown files' {
        $errorFileName = 'SpellingErrors.txt'

        It 'Should not have spelling errors in any markdown files' -Skip:($skipDependency) {
            $spellcheckSettingsFilePath = Join-Path -Path $ProjectPath -ChildPath '.vscode\cSpell.json'

            if (Test-Path -Path $spellcheckSettingsFilePath)
            {
                Write-Info -Message ('Using spellcheck settings file ''{0}''.' -f $spellcheckSettingsFilePath)
            }
            else
            {
                $spellcheckSettingsFilePath = $null
            }

            $cSpellArgumentList = @(
                '"**/*.md"',
                '--no-color'
            )

            if ($spellcheckSettingsFilePath)
            {
                $cSpellArgumentList += @(
                    '--config',
                    $spellcheckSettingsFilePath
                )
            }

            # This must be last, we send output to the error file.
            $cSpellArgumentList += @(
                ('>{0}' -f $errorFileName)
            )

            $startProcessParameters = @{
                FilePath = 'cspell'
                ArgumentList = $cSpellArgumentList
                Wait = $true
                PassThru = $true
                NoNewWindow = $true
            }

            $process = Start-Process @startProcessParameters
            $process.ExitCode | Should -Be 0
        } -ErrorVariable itBlockError

        # If the It-block did not pass the test, output the spelling errors.
        if ($itBlockError.Count -ne 0)
        {
            $message = @"
There were spelling errors. If these are false negatives, then please add the
word or phrase to the settings file '/.vscode/cSpell.json' in the repository.
See this section for more information.
https://github.com/PowerShell/DscResource.Tests/#common-tests-spellcheck-markdownfiles

"@

            Write-Host -BackgroundColor Yellow -ForegroundColor Black -Object $message
            Write-Host -ForegroundColor White -Object ''

            $misspelledErrors = Get-Content -Path $errorFileName -ErrorAction SilentlyContinue

            foreach ($misspelledError in $misspelledErrors)
            {
                $message = '{0}' -f $misspelledError
                Write-Host -BackgroundColor Yellow -ForegroundColor Black -Object $message
            }
        }

        # Make sure we always remove the file if it exist.
        if (Test-Path $errorFileName)
        {
            Remove-Item -Path $errorFileName -Force | Out-Null
        }
    }

    Context 'When uninstalling spellcheck dependencies' {
        It 'Should not throw an error when uninstalling package cSpell in global scope' -Skip:$skipDependency {
            {
                $npmParametersForStartProcess['ArgumentList'] = 'uninstall -g cspell'
                Start-Process @npmParametersForStartProcess
            } | Should -Not -Throw
        }
    }
}

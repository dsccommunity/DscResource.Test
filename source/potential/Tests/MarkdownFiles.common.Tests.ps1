param (
    $ModuleName,
    $ModuleBase,
    $ModuleManifest,
    $ProjectPath,
    $SourceManifest
)

Describe 'Common Tests - Validate Markdown Files' -Tag 'Markdown','Common Tests - Validate Markdown Files' {

    if (Get-Command -Name 'npm' -ErrorAction SilentlyContinue)
    {
        $npmParametersForStartProcess = @{
            FilePath         = 'npm'
            ArgumentList     = ''
            WorkingDirectory = $ProjectPath
            Wait             = $true
            WindowStyle      = 'Hidden'
        }

        Context 'When installing markdown validation dependencies' {
            It 'Should not throw an error when installing package Gulp in global scope' {
                {
                    <#
                        gulp; gulp is a toolkit that helps you automate painful or time-consuming tasks in your development workflow.
                        gulp must be installed globally to be able to be called through Start-Process
                    #>
                    $npmParametersForStartProcess['ArgumentList'] = 'install -g gulp'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when installing package Gulp in local scope' {
                {
                    # gulp must also be installed locally to be able to be referenced in the javascript file.
                    $npmParametersForStartProcess['ArgumentList'] = 'install gulp'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when installing package through2' {
                {
                    # Used in gulpfile.js; A tiny wrapper around Node streams2 Transform to avoid explicit sub classing noise
                    $npmParametersForStartProcess['ArgumentList'] = 'install through2'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when installing package markdownlint' {
                {
                    # Used in gulpfile.js; A Node.js style checker and lint tool for Markdown/CommonMark files.
                    $npmParametersForStartProcess['ArgumentList'] = 'install markdownlint'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when installing package gulp-concat as a dev-dependency' {
                {
                    # gulp-concat is installed as devDependencies. Used in gulpfile.js; Concatenates files
                    $npmParametersForStartProcess['ArgumentList'] = 'install gulp-concat -D'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }
        }

        Context 'When there are markdown files' {
            if (Test-Path -Path (Join-Path -Path $repoRootPath -ChildPath '.markdownlint.json'))
            {
                Write-Verbose -Message ('Using markdownlint settings file from repository folder ''{0}''.' -f $repoRootPath) -Verbose
                $markdownlintSettingsFilePath = Join-Path -Path $repoRootPath -ChildPath '.markdownlint.json'
            }
            else
            {
                Write-Verbose -Message 'Using markdownlint settings file from DscResource.Test repository.' -Verbose
                $markdownlintSettingsFilePath = $null
            }

            It "Should not have errors in any markdown files" {

                $mdErrors = 0
                try
                {

                    $gulpArgumentList = @(
                        'test-mdsyntax',
                        '--silent',
                        '--rootpath',
                        $repoRootPath,
                        '--dscresourcespath',
                        $dscResourcesFolderFilePath
                    )

                    if ($markdownlintSettingsFilePath)
                    {
                        $gulpArgumentList += @(
                            '--settingspath',
                            $markdownlintSettingsFilePath
                        )
                    }

                    Start-Process -FilePath 'gulp' -ArgumentList $gulpArgumentList `
                        -Wait -WorkingDirectory $PSScriptRoot -PassThru -NoNewWindow
                    Start-Sleep -Seconds 3
                    $mdIssuesPath = Join-Path -Path $PSScriptRoot -ChildPath 'markdownissues.txt'

                    if ((Test-Path -Path $mdIssuesPath) -eq $true)
                    {
                        Get-Content -Path $mdIssuesPath | ForEach-Object -Process {
                            if ([string]::IsNullOrEmpty($_) -eq $false)
                            {
                                Write-Warning -Message $_
                                $mdErrors ++
                            }
                        }
                    }
                    Remove-Item -Path $mdIssuesPath -Force -ErrorAction SilentlyContinue
                }
                catch [System.Exception]
                {
                    Write-Warning -Message ('Unable to run gulp to test markdown files. Please ' + `
                            'be sure that you have installed nodejs and have ' + `
                            'run ''npm install -g gulp'' in order to have this ' + `
                            'test execute.')
                }


                $mdErrors | Should -Be 0

            }
        }

        <#
            We're uninstalling the dependencies, in reverse order, so that the
            node_modules folder do not linger on a users computer if run locally.
            Also, this fixes so that when there is a apostrophe in the path for
            $PSScriptRoot, the node_modules folder is correctly removed.
        #>
        Context 'When uninstalling markdown validation dependencies' {
            It 'Should not throw an error when uninstalling package gulp-concat as a dev-dependency' {
                {
                    # gulp-concat is installed as devDependencies. Used in gulpfile.js; Concatenates files
                    $npmParametersForStartProcess['ArgumentList'] = 'uninstall gulp-concat -D'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when uninstalling package markdownlint' {
                {
                    # Used in gulpfile.js; A Node.js style checker and lint tool for Markdown/CommonMark files.
                    $npmParametersForStartProcess['ArgumentList'] = 'uninstall markdownlint'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when uninstalling package through2' {
                {
                    # Used in gulpfile.js; A tiny wrapper around Node streams2 Transform to avoid explicit sub classing noise
                    $npmParametersForStartProcess['ArgumentList'] = 'uninstall through2'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when uninstalling package Gulp in local scope' {
                {
                    # gulp must also be installed locally to be able to be referenced in the javascript file.
                    $npmParametersForStartProcess['ArgumentList'] = 'uninstall gulp'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when uninstalling package Gulp in global scope' {
                {
                    <#
                        gulp; gulp is a toolkit that helps you automate painful or time-consuming tasks in your development workflow.
                        gulp must be installed globally to be able to be called through Start-Process
                    #>
                    $npmParametersForStartProcess['ArgumentList'] = 'uninstall -g gulp'
                    Start-Process @npmParametersForStartProcess
                } | Should -Not -Throw
            }

            It 'Should not throw an error when removing the node_modules folder' {
                {
                    # Remove folder node_modules that npm created.
                    $npmNodeModulesPath = (Join-Path -Path $PSScriptRoot -ChildPath 'node_modules')
                    if ( Test-Path -Path $npmNodeModulesPath)
                    {
                        Remove-Item -Path $npmNodeModulesPath -Recurse -Force
                    }
                } | Should -Not -Throw
            }
        }
    }
    else
    {
        Write-Warning -Message ('Unable to run gulp to test markdown files. Please ' + `
                'be sure that you have installed nodejs and npm in order ' + `
                'to have this text execute.')
    }
}


Describe 'Common Tests - Validate Example Files To Be Published' -Tag 'Examples' {
    $optIn = Get-PesterDescribeOptInStatus -OptIns $optIns
    $examplesPath = Join-Path -Path $moduleRootFilePath -ChildPath 'Examples'

    # Due to speed, only run these test if opt-in and the examples folder exist.
    if ($optIn -and (Test-Path -Path $examplesPath))
    {
        # We need helper functions from this module.
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'DscResource.GalleryDeploy')

        <#
            For Appveyor builds copy the module to the system modules directory so it falls in to a PSModulePath folder and is
            picked up correctly.
            For a user to run the test, they need to make sure that the module exists in one of the paths in env:PSModulePath, i.e.
            '%USERPROFILE%\Documents\WindowsPowerShell\Modules'.
            No copying is done when a user runs the test, because that could potentially be destructive.
        #>
        if ($env:APPVEYOR -eq $true)
        {
            $powershellModulePath = Copy-ResourceModuleToPSModulePath -ResourceModuleName $moduleName -ModuleRootPath $moduleRootFilePath
        }

        Context 'When there are examples that should be published' {
            $exampleScriptFiles = Get-ChildItem -Path (Join-Path -Path $examplesPath -ChildPath '*Config.ps1')

            It 'Should not contain any duplicate GUID is script file metadata' -Skip:(!$optIn) {
                $exampleScriptMetadata = $exampleScriptFiles | ForEach-Object -Process {
                    <#
                        The cmdlet Test-ScriptFileInfo ignores the parameter ErrorAction and $ErrorActionPreference.
                        Instead a try-catch need to be used to ignore files that does not have the correct metadata.
                    #>
                    try
                    {
                        Test-ScriptFileInfo -Path $_.FullName
                    }
                    catch
                    {
                        # Intentionally left blank. Files with missing metadata will be caught in the next test.
                    }
                }

                $duplicateGuid = $exampleScriptMetadata |
                    Group-Object -Property Guid |
                    Where-Object { $_.Count -gt 1 }

                if ($duplicateGuid -and $duplicateGuid.Count -gt 0)
                {
                    $duplicateGuid |
                        ForEach-Object -Process {
                            Write-Warning -Message ('Guid {0} is duplicated in the files ''{1}''' -f $_.Name, ($_.Group.Name -join ', '))
                        }
                }

                $duplicateGuid | Should -BeNullOrEmpty
            }

            foreach ($exampleToValidate in $exampleScriptFiles)
            {
                $exampleDescriptiveName = Join-Path -Path (Split-Path -Path $exampleToValidate.Directory -Leaf) `
                                                    -ChildPath (Split-Path -Path $exampleToValidate -Leaf)

                Context "When publishing example '$exampleDescriptiveName'" {
                    It 'Should pass testing of script file metadata' -Skip:(!$optIn) {
                        {
                            Test-ScriptFileInfo -Path $exampleToValidate.FullName
                        } | Should -Not -Throw
                    }

                    It 'Should have the correct naming convention, and the same file name as the configuration name' -Skip:(!$optIn) {
                        $result = Test-ConfigurationName -Path $exampleToValidate.FullName
                        $result | Should -BeTrue
                    }
                }
            }
        }

        if ($env:APPVEYOR -eq $true)
        {
            Remove-item -Path $powershellModulePath -Recurse -Force -Confirm:$false

            # Restore the load of the module to ensure future tests have access to it
            Import-Module -Name (Join-Path -Path $moduleRootFilePath `
                    -ChildPath "$moduleName.psd1") `
                -Global
        }
    }
}

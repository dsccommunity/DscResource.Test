
Describe 'Common Tests - Validate Example Files' -Tag 'Examples' {

    $optIn = Get-PesterDescribeOptInStatus -OptIns $optIns

    $examplesPath = Join-Path -Path $moduleRootFilePath -ChildPath 'Examples'
    if (Test-Path -Path $examplesPath)
    {
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

        $exampleFile = Get-ChildItem -Path (Join-Path -Path $moduleRootFilePath -ChildPath 'Examples') -Filter '*.ps1' -Recurse
        foreach ($exampleToValidate in $exampleFile)
        {
            $exampleDescriptiveName = Join-Path -Path (Split-Path $exampleToValidate.Directory -Leaf) -ChildPath (Split-Path $exampleToValidate -Leaf)

            Context $exampleDescriptiveName {
                It "Should compile MOFs for example correctly" -Skip:(!$optIn) {
                    {
                        $mockPassword = ConvertTo-SecureString '&iPm%M5q3K$Hhq=wcEK' -AsPlainText -Force
                        $mockCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @('username', $mockPassword)
                        $mockConfigurationData = @{
                            AllNodes = @(
                                @{
                                    NodeName        = 'localhost'
                                    CertificateFile = $env:DscPublicCertificatePath
                                }
                            )
                        }

                        try
                        {
                            <#
                                Set this first because it is used in the final block,
                                and must be set otherwise it fails on not being assigned.
                            #>
                            $existingCommandName = $null

                            # Get the list of additional modules required by the example
                            $requiredModules = Get-ResourceModulesInConfiguration -ConfigurationPath $exampleToValidate.FullName |
                                Where-Object -Property Name -ne $moduleName

                            if ($requiredModules)
                            {
                                Install-DependentModule -Module $requiredModules
                            }

                            . $exampleToValidate.FullName

                            <#
                                Test for either a configuration named 'Example',
                                or parse the name from the filename and try that
                                as the configuration name (requirement for Azure
                                Automation).
                            #>
                            $commandName = @('Example')
                            $azureCommandName = Get-PublishFileName -Path $exampleToValidate.FullName
                            $commandName += $azureCommandName

                            # Get the first one that matches.
                            $existingCommand = Get-ChildItem -Path 'function:' |
                                Where-Object { $_.Name -in $commandName } |
                                Select-Object -First 1

                            if ($existingCommand)
                            {
                                $existingCommandName = $existingCommand.Name

                                $exampleCommand = Get-Command -Name $existingCommandName -ErrorAction SilentlyContinue
                                if ($exampleCommand)
                                {
                                    $exampleParameters = @{}

                                    # Remove any common parameters that are available.
                                    $commandParameters = $exampleCommand.Parameters.Keys | Where-Object -FilterScript {
                                        ($_ -notin [System.Management.Automation.PSCmdlet]::CommonParameters) -and `
                                        ($_ -notin [System.Management.Automation.PSCmdlet]::OptionalCommonParameters)
                                    }

                                    foreach ($parameterName in $commandParameters)
                                    {
                                        $parameterType = $exampleCommand.Parameters[$parameterName].ParameterType.FullName

                                        <#
                                            Each credential parameter in the Example function is assigned the
                                            mocked credential. 'PsDscRunAsCredential' is not assigned because
                                            that brakes the example.
                                        #>
                                        if ($parameterName -ne 'PsDscRunAsCredential' `
                                                -and $parameterType -eq 'System.Management.Automation.PSCredential')
                                        {
                                            $exampleParameters.Add($parameterName, $mockCredential)
                                        }
                                        else
                                        {
                                            <#
                                                Check for mandatory parameters.
                                                Assume the parameters are all in the 'all' parameter set.
                                            #>
                                            $isParameterMandatory = $exampleCommand.Parameters[$parameterName].ParameterSets['__AllParameterSets'].IsMandatory
                                            if ($isParameterMandatory)
                                            {
                                                <#
                                                    Convert '1' to the type that the parameter expects.
                                                    Using '1' since it can be converted to String, Numeric
                                                    and Boolean.
                                                #>
                                                $exampleParameters.Add($parameterName, ('1' -as $parameterType))
                                            }
                                        }
                                    }

                                    <#
                                        If there is a $ConfigurationData variable that was dot-sources.
                                        Then use that as the configuration data instead of the mocked configuration data.
                                    #>
                                    if (Get-Item -Path variable:ConfigurationData -ErrorAction SilentlyContinue)
                                    {
                                        # Adding certificate to the examples configuration data.
                                        foreach ($node in $ConfigurationData.AllNodes.GetEnumerator())
                                        {
                                            if ($node.ContainsKey('PSDscAllowPlainTextPassword') -eq $true -and $node.PSDscAllowPlainTextPassword -eq $true)
                                            {
                                                Write-Warning -Message ('The example ''{0}'' is using PSDscAllowPlainTextPassword = $true in the configuration data for node name ''{1}'', this should be removed so the example is secure. PSDscAllowPlainTextPassword was overridden in the tests so the example can be tested securely.' -f $exampleDescriptiveName, $node.NodeName)

                                                # Override PSDscAllowPlainTextPassword.
                                                $node.PSDscAllowPlainTextPassword = $false
                                            }

                                            $node.CertificateFile = $env:DscPublicCertificatePath
                                        }

                                        $mockConfigurationData = $ConfigurationData
                                    }

                                    & $exampleCommand.Name @exampleParameters -ConfigurationData $mockConfigurationData -OutputPath 'TestDrive:\' -ErrorAction Continue -WarningAction SilentlyContinue | Out-Null
                                }
                            }
                            else
                            {
                                throw "The example '$exampleDescriptiveName' does not contain a configuration named 'Example' or '$azureCommandName'."
                            }

                        }
                        finally
                        {
                            # Remove the function we dot-sourced so next example file doesn't use the previous Example-function.
                            if ($existingCommandName)
                            {
                                Remove-Item -Path "function:$existingCommandName" -ErrorAction SilentlyContinue
                            }

                            # Remove the variable $ConfigurationData if it existed in the file we dot-sourced so next example file doesn't use the previous examples configuration.
                            Remove-Item -Path variable:ConfigurationData -ErrorAction SilentlyContinue
                        }
                    } | Should -Not -Throw
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

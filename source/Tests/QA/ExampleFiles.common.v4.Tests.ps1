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
    $ExcludeSourceFile,

    [Parameter(ValueFromRemainingArguments = $true)]
    $Args
)

$isPester5 = (Get-Module -Name Pester).Version -lt '5.0.0'

# Only run if _not_ Pester 5.
if (-not $isPester5)
{
    return
}

# Do not run on PowerShell Core / PowerShell 6+.
if ($PSEdition -ne 'Desktop')
{
    return
}

Describe 'Common Tests - Validate Example Files' -Tag 'Common Tests - Validate Example Files' {

    $examplesPath = Join-Path -Path $SourcePath -ChildPath 'Examples'
    if (Test-Path -Path $examplesPath)
    {
        $examples = Get-ChildItem -Path $examplesPath -Filter '*.ps1' -Recurse | WhereSourceFileNotExcluded -ExcludeSourceFile $ExcludeSourceFile
        foreach ($example in $examples)
        {
            $exampleDescriptiveName = Join-Path -Path (Split-Path $example.Directory -Leaf) -ChildPath (Split-Path $example -Leaf)

            Context $exampleDescriptiveName {
                It 'Should compile MOFs for example correctly' {
                    {
                        $mockPassword = ConvertTo-SecureString '&iPm%M5q3K$Hhq=wcEK' -AsPlainText -Force
                        $mockCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @('username', $mockPassword)
                        $mockConfigurationData = @{
                            AllNodes = @(
                                @{
                                    NodeName                    = 'localhost'
                                    PsDscAllowPlainTextPassword = $true
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

                            . $example.FullName

                            <#
                                Test for either a configuration named 'Example',
                                or parse the name from the filename and try that
                                as the configuration name (requirement for Azure
                                Automation).
                            #>
                            $commandName = @('Example')
                            $azureCommandName = Get-PublishFileName -Path $example.FullName
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
                                            that breaks the example.
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
                                        If there is a $ConfigurationData variable that was dot-sourced
                                        then use that as the configuration data instead of the mocked configuration data.
                                    #>
                                    if (Get-Item -Path variable:ConfigurationData -ErrorAction SilentlyContinue)
                                    {
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
    }
}

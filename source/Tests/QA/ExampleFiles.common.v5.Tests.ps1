<#
    .NOTES
        To run manually:

        $pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

        $container = New-PesterContainer -Path "$pathToHQRMTests/ExampleFiles.common.*.Tests.ps1" -Data @{
            SourcePath = './source'
            # ExcludeSourceFile = @('MyExample.ps1')
        }

        Invoke-Pester -Container $container -Output Detailed
#>
param
(
    [Parameter()]
    [System.String]
    $SourcePath,

    [Parameter()]
    [System.String[]]
    $ExcludeSourceFile,

    [Parameter(ValueFromRemainingArguments = $true)]
    $Args
)

# This test _must_ be outside the BeforeDiscovery-block since Pester 4 does not recognizes it.
$isPesterMinimum5 = (Get-Module -Name Pester).Version -ge '5.1.0'

# Only run if Pester 5.1 or higher.
if (-not $isPesterMinimum5)
{
    Write-Verbose -Message 'Repository is using old Pester version, new HQRM tests for Pester v5 and v6 are skipped.' -Verbose
    return
}

<#
    This _must_ be outside any Pester blocks for correct script parsing.
    Sets Context block's default parameter value to handle Pester v6's ForEach
    change, to keep same behavior as with Pester v5. The default parameter is
    removed at the end of the script to avoid affecting other tests.
#>
$PSDefaultParameterValues['Context:AllowNullOrEmptyForEach'] = $true

BeforeDiscovery {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force

    if (-not $SourcePath)
    {
        return
    }

    $examplesPath = Join-Path -Path $SourcePath -ChildPath 'Examples'

    # If there are no Examples folder, exit.
    if (-not (Test-Path -Path $examplesPath))
    {
        return
    }

    $exampleFiles = @(Get-ChildItem -Path $examplesPath -Filter '*.ps1' -Recurse | WhereSourceFileNotExcluded -ExcludeSourceFile $ExcludeSourceFile)

    $exampleToTest = @()

    foreach ($exampleFile in $exampleFiles)
    {
        $exampleToTest += @{
            ExampleFile            = $exampleFile
            ExampleDescriptiveName = Join-Path -Path (Split-Path $exampleFile.Directory -Leaf) -ChildPath (Split-Path $exampleFile -Leaf)
        }
    }
}

BeforeAll {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force
}

AfterAll {
    # Re-import just the public functions.
    Import-Module -Name 'DscResource.Test' -Force
}

Describe 'Common Tests - Validate Example Files' -Tag 'Common Tests - Validate Example Files' {
    Context 'When the example ''<ExampleDescriptiveName>'' exist' -ForEach $exampleToTest {
        It 'Should compile the MOF schema for the example correctly' {
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

                <#
                    Set this first because it is used in the final block,
                    and must be set otherwise it fails on not being assigned.
                #>
                $existingCommandName = $null

                try
                {
                    . $ExampleFile.FullName

                    <#
                        Test for either a configuration named 'Example',
                        or parse the name from the filename and try that
                        as the configuration name (requirement for Azure
                        Automation).
                    #>
                    $commandName = @(
                        'Example',
                        (Get-PublishFileName -Path $ExampleFile.FullName)
                    )

                    # Get the first one that matches.
                    $existingCommand = Get-ChildItem -Path 'function:' |
                        Where-Object { $_.Name -in $commandName } |
                        Select-Object -First 1

                    if ($existingCommand)
                    {
                        $existingCommandName = $existingCommand.Name

                        $exampleCommand = Get-Command -Name $existingCommandName -ErrorAction 'SilentlyContinue'

                        if ($exampleCommand)
                        {
                            $exampleParameters = @{}

                            # Remove any common parameters that are available.
                            $commandParameters = $exampleCommand.Parameters.Keys |
                                Where-Object -FilterScript {
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
                                then use that as the configuration data instead of the mocked
                                configuration data.
                            #>
                            if (Get-Item -Path variable:ConfigurationData -ErrorAction 'SilentlyContinue')
                            {
                                $mockConfigurationData = $ConfigurationData
                            }

                            & $exampleCommand.Name @exampleParameters -ConfigurationData $mockConfigurationData -OutputPath 'TestDrive:\' -ErrorAction 'Continue' -WarningAction 'SilentlyContinue' | Out-Null
                        }
                    }
                    else
                    {
                        throw ('The example ''{0}'' does not contain a configuration named ''{1}''.' -f $exampleDescriptiveName, ($commandName -join "', or '"))
                    }

                }
                finally
                {
                    <#
                        Remove the function we dot-sourced so next example file
                        doesn't use the previous Example-function. Using recurse
                        since it saw child functions when copied in helper functions
                        during debugging, it resulted in an interactive prompt.
                    #>
                    Remove-Item -Path "function:$existingCommandName" -ErrorAction 'SilentlyContinue' -Recurse -Force

                    <#
                        Remove the variable $ConfigurationData if it existed in
                        the file we dot-sourced so next example file doesn't use
                        the previous examples configuration.
                    #>
                    Remove-Item -Path 'variable:ConfigurationData' -ErrorAction 'SilentlyContinue'
                }
            } | Should -Not -Throw
        }
    }
}

$PSDefaultParameterValues.Remove('Context:AllowNullOrEmptyForEach')

<#
    .SYNOPSIS
        This is a build task that generates conceptual help.

    .PARAMETER ProjectPath
        The root path to the project. Defaults to $BuildRoot.

    .PARAMETER OutputDirectory
        The base directory of all output. Defaults to folder 'output' relative to
        the $BuildRoot.

    .PARAMETER ProjectName
        The project name.

    .PARAMETER SourcePath
        The path to the source folder name.

    .PARAMETER BuildInfo
        The build info object from ModuleBuilder. Defaults to an empty hashtable.

    .NOTES
        This is a build task that is primarily meant to be run by Invoke-Build but
        wrapped by the Sampler project's build.ps1 (https://github.com/gaelcolas/Sampler).
#>
param
(
    # Project path
    [Parameter()]
    [System.String]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [Parameter()]
    # Base directory of all output (default to 'output')
    [System.String]
    $OutputDirectory = (property OutputDirectory (Join-Path -Path $BuildRoot -ChildPath 'output')),

    [Parameter()]
    [System.String]
    $BuiltModuleSubdirectory = (property BuiltModuleSubdirectory ''),

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $VersionedOutputDirectory = (property VersionedOutputDirectory $true),

    [Parameter()]
    [System.String]
    $ProjectName = (property ProjectName $(Get-SamplerProjectName -BuildRoot $BuildRoot)),

    [Parameter()]
    [System.String]
    $SourcePath = (property SourcePath $(Get-SamplerSourcePath -BuildRoot $BuildRoot)),

    [Parameter()]
    [System.String]
    $DscTestOutputFolder = (property DscTestOutputFolder 'testResults'),

    [Parameter()]
    [System.String]
    $BuildModuleOutput = (property BuildModuleOutput (Join-Path -Path $BuildRoot -ChildPath 'output')),

    # [Parameter()]
    # [System.String]
    # $DscTestPesterOutputFormat = (property DscTestPesterOutputFormat ''),

    # [Parameter()]
    # [System.String[]]
    # $DscTestPesterScript = (property DscTestPesterScript ''),

    # [Parameter()]
    # [System.String[]]
    # $DscTestPesterTag = (property DscTestPesterTag @()),

    # [Parameter()]
    # [System.String[]]
    # $DscTestPesterExcludeTag = (property DscTestPesterExcludeTag @()),

    # Build Configuration object
    [Parameter()]
    [System.Collections.Hashtable]
    $BuildInfo = (property BuildInfo @{ })
)

# Synopsis: Making sure the Module meets some quality standard (help, tests)
task Invoke_HQRM_Tests {
    # Get the values for task variables
    . Set-SamplerTaskVariable

    "`tProject Path          = $ProjectPath"

    if (-not (Split-Path -IsAbsolute $DscTestOutputFolder))
    {
        $DscTestOutputFolder = Join-Path -Path $OutputDirectory -ChildPath $DscTestOutputFolder
    }

    $getModuleVersionParameters = @{
        OutputDirectory = $OutputDirectory
        ProjectName     = $ProjectName
    }

    if (-not (Test-Path -Path $DscTestOutputFolder))
    {
        Write-Build -Color 'Yellow' -Text "Creating folder $DscTestOutputFolder"

        $null = New-Item -Path $DscTestOutputFolder -ItemType Directory -Force -ErrorAction 'Stop'
    }

    # $DscTestPesterScript = $DscTestPesterScript.Where{ -not [System.String]::IsNullOrEmpty($_) }
    # $DscTestPesterTag = $DscTestPesterTag.Where{ -not [System.String]::IsNullOrEmpty($_) }
    # $DscTestPesterExcludeTag = $DscTestPesterExcludeTag.Where{ -not [System.String]::IsNullOrEmpty($_) }

    Import-Module -Name 'Pester' -MinimumVersion 5.1 -ErrorAction 'Stop'

    # Default parameters for test scripts.
    $defaultScriptParameters = @{
        # None for now.
    }

    if ($BuildInfo.DscTest -and $BuildInfo.DscTest.Script)
    {
        <#
            This will build the DscTestScript<parameterName> variables
            (e.g. DscTestScriptExcludeSourceFile) in this scope that are used in
            the rest of the code.

            It will use values for the variables in the following order:

            1. Skip creating the variable if a variable is already available because
               it was already set in a passed parameter (DscTestScript<parameterName>).
            2. Use the value from a property in the build.yaml under the key 'DscTest:'.
        #>
        foreach ($propertyName in $BuildInfo.DscTest.Script.Keys)
        {
            $taskParameterName = "DscTestScript$propertyName"
            $taskParameterValue = Get-Variable -Name $taskParameterName -ValueOnly -ErrorAction 'SilentlyContinue'

            if ($taskParameterValue)
            {
                Write-Build -Color 'DarkGray' -Text "Using $taskParameterName from Build Invocation Parameters"
            }
            else
            {
                $taskParameterValue = $BuildInfo.DscTest.Script.($propertyName)

                if ($taskParameterValue)
                {
                    # Use the value from build.yaml.
                    Write-Build -Color 'DarkGray' -Text "Using $taskParameterName from Build Config"

                    Set-Variable -Name $taskParameterName -Value $taskParameterValue
                }
            }
        }
    }
    # else
    # {
    #     throw 'Missing the key ''DscTest:'' or the child key ''Script:'' in the build configuration file build.yaml.'
    # }

    <#
        Default values for the Pester 5 parameters that are valid
        for all parameter sets.
    #>
    $defaultPesterParameters = @{
        # None.
    }

    if ($BuildInfo.DscTest -and $BuildInfo.DscTest.Pester)
    {
        <#
            This is the parameters that will be passed to Invoke-Pester for
            either all Pester parameter sets of for the Pester default (Simple)
            parameter set.
        #>

        $pesterParameterConfigurationKeys = $BuildInfo.DscTest.Pester.Keys |
            Where-Object -FilterScript {
                $_ -notin 'Configuration'
            }

        <#
            This will build the DscTestPester<parameterName> variables (e.g.
            DscTestPesterExcludeTagFilter) in this scope that are used in the
            rest of the code.

            It will use values for the variables in the following order:

            1. Skip creating the variable if a variable is already available because
               it was already set in a passed parameter (DscTestPester<parameterName>).
            2. Use the value from a property in the build.yaml under the key 'DscTest:'.
        #>
        foreach ($propertyName in $pesterParameterConfigurationKeys)
        {
            $taskParameterName = "DscTestPester$propertyName"
            $taskParameterValue = Get-Variable -Name $taskParameterName -ValueOnly -ErrorAction 'SilentlyContinue'

            if ($taskParameterValue)
            {
                Write-Build -Color 'DarkGray' -Text "Using $taskParameterName from Build Invocation Parameters"
            }
            else
            {
                $taskParameterValue = $BuildInfo.DscTest.Pester.($propertyName)

                if ($taskParameterValue)
                {
                    # Use the value from build.yaml.
                    Write-Build -Color 'DarkGray' -Text "Using $taskParameterName from Build Config"

                    Set-Variable -Name $taskParameterName -Value $taskParameterValue
                }
            }
        }

        if ($BuildInfo.DscTest.Pester.Configuration)
        {
            <#
                Pester default values for the Pester 5 configuration.
            #>
            $pesterConfiguration = [PesterConfiguration]::Default

            $pesterConfigurationSectionNames = ($pesterConfiguration | Get-Member -Type 'Properties').Name

            foreach ($sectionName in $pesterConfigurationSectionNames)
            {
                if ($BuildInfo.DscTest.Pester.Configuration.$sectionName)
                {
                    $propertyNames = ($pesterConfiguration.$sectionName | Get-Member -Type 'Properties').Name

                    <#
                        This will build the DscTestPester<parameterName> variables (e.g.
                        DscTestPesterExcludeTagFilter) in this scope that are used in the
                        rest of the code.

                        It will use values for the variables in the following order:

                        1. Skip creating the variable if a variable is already available because
                            it was already set in a passed parameter (DscTestPester<parameterName>).
                        2. Use the value from a property in the build.yaml under the key 'DscTest:'.
                    #>
                    foreach ($propertyName in $propertyNames)
                    {
                        $taskParameterName = 'DscTestPesterConfiguration{0}{1}' -f $sectionName, $propertyName

                        $taskParameterValue = Get-Variable -Name $taskParameterName -ValueOnly -ErrorAction 'SilentlyContinue'

                        if ($taskParameterValue)
                        {
                            Write-Build -Color 'DarkGray' -Text "Using $taskParameterName from Build Invocation Parameters"
                        }
                        else
                        {
                            if ($BuildInfo.DscTest.Pester.Configuration.$sectionName.$propertyName)
                            {
                                $taskParameterValue = $BuildInfo.DscTest.Pester.Configuration.$sectionName.$propertyName

                                if ($taskParameterValue)
                                {
                                    # Use the value from build.yaml.
                                    Write-Build -Color 'DarkGray' -Text "Using $taskParameterName from Build Config"

                                    Set-Variable -Name $taskParameterName -Value $taskParameterValue
                                }
                            }
                        }

                        # Set the value in the pester configuration object if it was available.
                        if ($taskParameterValue)
                        {
                            <#
                                Force conversion from build configuration types to
                                correct Pester type to avoid exceptions like:

                                ERROR: Exception setting "ExcludeTag": "Cannot convert
                                the "System.Collections.Generic.List`1[System.Object]"
                                value of type "System.Collections.Generic.List`1[[System.Object,
                                System.Private.CoreLib, Version=5.0.0.0, Culture=neutral,
                                PublicKeyToken=7cec85d7bea7798e]]" to type
                                "Pester.StringArrayOption"."
                            #>
                            $pesterConfigurationValue = switch ($pesterConfiguration.$sectionName.$propertyName)
                            {
                                {$_ -is [Pester.StringArrayOption]}
                                {
                                    [Pester.StringArrayOption] @($taskParameterValue)
                                }

                                {$_ -is [Pester.StringOption]}
                                {
                                    [Pester.StringOption] $taskParameterValue
                                }

                                {$_ -is [Pester.BoolOption]}
                                {
                                    [Pester.BoolOption] $taskParameterValue
                                }

                                Default
                                {
                                    <#
                                        Set the value without conversion so that new types that
                                        are not supported can be catched.
                                    #>
                                    $pesterConfigurationValue = $taskParameterValue
                                }
                            }

                            # If the conversion above is not made this will fail.
                            $pesterConfiguration.$sectionName.$propertyName = $pesterConfigurationValue
                        }
                    }
                }
            }
        }
    }
    # else
    # {
    #     throw 'Missing the key ''DscTest:'' or the child key ''Pester:'' in the build configuration file build.yaml.'
    # }

    # Set the default value for all "Script:" properties that still have no value.
    foreach ($propertyName in $defaultScriptParameters.Keys)
    {
        $taskParameterName = "DscTestScript$propertyName"
        $taskParameterValue = Get-Variable -Name $taskParameterName -ValueOnly -ErrorAction 'SilentlyContinue'

        if (-not $taskParameterValue)
        {
            Write-Build -Color 'DarkGray' -Text "Using $taskParameterName from Defaults"

            Set-Variable -Name $taskParameterName -Value $defaultScriptParameters.($propertyName)
        }
    }

    # Set the default value for all "Pester:" properties that still have no value.
    foreach ($propertyName in $defaultPesterParameters.Keys)
    {
        $taskParameterName = "DscTestPester$propertyName"
        $taskParameterValue = Get-Variable -Name $taskParameterName -ValueOnly -ErrorAction 'SilentlyContinue'

        if (-not $taskParameterValue)
        {
            Write-Build -Color 'DarkGray' -Text "Using $taskParameterName from Defaults"

            Set-Variable -Name $taskParameterName -Value $defaultPesterParameters.$propertyName
        }
    }

    "`tBuild Module Output   = $BuildModuleOutput"
    "`tTest Output Folder    = $DscTestOutputFolder"
    "`t"

    $pesterParameters = @{}

    <#
        Get all pester variables (DscTestPester*).
    #>
    $dscTestPesterVariables = Get-Variable -Name 'DscTestPester*' -Scope 'Local'

    # Find the longest name so we can pad the output nicely.
    $longestPropertyNameLength = (
        ($dscTestPesterVariables).Name |
            ForEach-Object -Process { $_.Length } |
            Measure-Object -Maximum
    ).Maximum

    foreach ($variable in $dscTestPesterVariables)
    {
        $paddedVariableName = $variable.Name.PadRight($longestPropertyNameLength)

        "`t$($paddedVariableName) = $($variable.Value -join ', ')"

        <#
            Only set the pester parameter if it does not belong to the
            Pester Configuration object.
        #>
        if ($variable.Name -notmatch 'DscTestPesterConfiguration')
        {
            $pesterParameterName = $variable.Name -replace 'DscTestPester'

            $pesterParameters[$pesterParameterName] = $variable.Value
        }
    }

    "`t"

    $scriptParameters = @{}

    $dscTestScriptVariables = Get-Variable -Name 'DscTestScript*' -Scope 'Local'

    # Find the longest name so we can pad the output nicely.
    $longestPropertyNameLength = (
        ($dscTestScriptVariables).Name |
            ForEach-Object -Process { $_.Length } |
            Measure-Object -Maximum
    ).Maximum

    foreach ($variable in $dscTestScriptVariables)
    {
        $scriptParameterName = $variable.Name -replace 'DscTestScript'

        $scriptParameters[$scriptParameterName] = $variable.Value

        $paddedVariableName = $variable.Name.PadRight($longestPropertyNameLength)

        "`t$($paddedVariableName) = $($variable.Value -join ', ')"
    }

    # Values passed to parameters in all test scripts.
    $pesterData = @{
        ProjectPath        = $ProjectPath
        SourcePath         = $SourcePath
        MainGitBranch      = $scriptParameters['MainGitBranch']
        ModuleBase         = Join-Path -Path $BuildModuleOutput -ChildPath "$ProjectName/*"
        ModuleName         = $ProjectName
        ExcludeModuleFile  = $DscTestScriptExcludeModuleFile
        ExcludeSourceFile  = $DscTestScriptExcludeSourceFile
    }

    $pathToHqrmTests = Join-Path -Path $PSScriptRoot -ChildPath '../Tests/QA'

    Write-Verbose -Message ('Path to HQRM tests: {0}' -f $pathToHqrmTests)

    $hqrmTestScripts = Get-ChildItem -Path $pathToHqrmTests

    $pesterContainers = foreach ($testScript in $hqrmTestScripts)
    {
        New-PesterContainer -Path $testScript.FullName -Data $pesterData.Clone()
    }

    if ($BuildInfo.DscTest.Pester.Configuration -and $pesterConfiguration)
    {
        $pesterConfiguration.Run.Container = $pesterContainers

        # Override the PassThru property if it was wrongly set through the build configuration.
        $pesterConfiguration.Run.PassThru = $true
    }
    else
    {
        $pesterParameters['Container'] = $pesterContainers

        # Override the PassThru property if it was wrongly set through the build configuration.
        $pesterParameters['PassThru'] = $true
    }

    <#
        Avoiding processing the verbose statements unless it is necessary since
        ConvertTo-Json outputs a warning message ("serialization has exceeded the
        set depth") even if the verbose message is not outputted.
    #>
    if ($VerbosePreference -ne 'SilentlyContinue')
    {
        Write-Verbose -Message ($pesterParameters | ConvertTo-Json)
        Write-Verbose -Message ($scriptParameters | ConvertTo-Json)
    }

    if ($BuildInfo.DscTest.Pester.Configuration -and $pesterConfiguration)
    {
        $script:testResults = Invoke-Pester @pesterParameters -Configuration $pesterConfiguration
    }
    else
    {
        $script:testResults = Invoke-Pester @pesterParameters
    }


    $os = if ($isWindows -or $PSVersionTable.PSVersion.Major -le 5)
    {
        'Windows'
    }
    elseif ($isMacOS)
    {
        'MacOS'
    }
    else
    {
        'Linux'
    }

    $psVersion = 'PSv.{0}' -f $PSVersionTable.PSVersion
    $DscTestOutputFileFileName = "DscTest_{0}_v{1}.{2}.{3}.xml" -f $ProjectName, $ModuleVersion, $os, $psVersion
    # $DscTestOutputFullPath = Join-Path -Path $DscTestOutputFolder -ChildPath "$($DscTestPesterOutputFormat)_$DscTestOutputFileFileName"

    $DscTestResultObjectCliXml = Join-Path -Path $DscTestOutputFolder -ChildPath "DscTestObject_$DscTestOutputFileFileName"

    $null = $script:testResults | Export-CliXml -Path $DscTestResultObjectCliXml -Force

    <#
        Verify so that all containers (discovery phase) ran and all tests passed,
        if not make sure the test pipeline correctly fails.
    #>
    if ($script:testResults.Result -eq 'Failed')
    {
        throw 'Pester reported failure. Tests did not pass.'
    }
}

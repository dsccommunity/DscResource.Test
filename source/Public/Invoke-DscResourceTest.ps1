<#
    .ForwardHelpTargetName Invoke-Pester
    .ForwardHelpCategory Function
#>
function Invoke-DscResourceTest
{
    [CmdletBinding(DefaultParameterSetName = 'ByProjectPath')]
    param
    (
        [Parameter(ParameterSetName = 'ByModuleNameOrPath', Mandatory = $true, Position = 0)]
        [System.String]
        $Module,

        [Parameter(ParameterSetName = 'ByModuleSpecification', Mandatory = $true, Position = 0)]
        [Microsoft.PowerShell.Commands.ModuleSpecification]
        $FullyQualifiedModule,

        [Parameter(ParameterSetName = 'ByProjectPath', Mandatory = $true, Position = 0)]
        [System.String]
        $ProjectPath,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath', Position = 1)]
        [Parameter(ParameterSetName = 'ByModuleSpecification', Position = 1)]
        [Parameter(ParameterSetName = 'ByProjectPath', Position = 1)]
        [Alias('Script', 'relative_path')]
        [System.Object[]]
        $Path,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath', Position = 2)]
        [Parameter(ParameterSetName = 'ByModuleSpecification', Position = 2)]
        [Parameter(ParameterSetName = 'ByProjectPath', Position = 2)]
        [Alias('Name')]
        [System.String[]]
        $TestName,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath', Position = 3)]
        [Parameter(ParameterSetName = 'ByModuleSpecification', Position = 3)]
        [Parameter(ParameterSetName = 'ByProjectPath', Position = 3)]
        [System.Management.Automation.SwitchParameter]
        $EnableExit, #v4

        [Parameter(ParameterSetName = 'ByModuleNameOrPath', Position = 5)]
        [Parameter(ParameterSetName = 'ByModuleSpecification', Position = 5)]
        [Parameter(ParameterSetName = 'ByProjectPath', Position = 5)]
        [Alias('Tags', 'Tag')]
        [System.String[]]
        $TagFilter, #v4 Filter.Tag

        [Parameter()]
        [Alias('ExcludeTag')]
        [System.String[]]
        $ExcludeTagFilter, #v4 Filter.ExcludeTag

        [Parameter()]
        [System.String[]]
        $ExcludeModuleFile,

        [Parameter()]
        [System.String[]]
        $ExcludeSourceFile,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $PassThru,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [System.Object[]]
        $CodeCoverage, #v4 CodeCoverage.Enabled = $true

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [System.String]
        $CodeCoverageOutputFile, #v4

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [ValidateSet('JaCoCo')]
        [System.String]
        $CodeCoverageOutputFileFormat, #v4 CodeCoverage.CodeCoverageOutputFileFormat = 'JaCoCo'

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [System.Management.Automation.SwitchParameter]
        $Strict, #v4

        [Parameter()]
        [System.String]
        $Output, #v4

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [System.String]
        $OutputFile, #v4 TestResult.OutputFile

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [ValidateSet('NUnitXml', 'JUnitXml')]
        [System.String]
        $OutputFormat, #v4 TestResult.OutputFormat

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [System.Management.Automation.SwitchParameter]
        $Quiet, #v4 $Show = 'none'

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [System.Object]
        $PesterOption, #v4

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [Pester.OutputTypes]
        $Show, #v4 Output.Verbosity Default,Passed,Failed,Pending,Skipped,Inconclusive,Describe,Context,Summary,Header,All,Fails

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [System.Collections.IDictionary]
        [Alias('Configuration')]
        $Settings,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [System.String]
        $MainGitBranch = 'master',

        [Parameter(ParameterSetName = 'ByModuleNameOrPath', DontShow = $true)]
        [Parameter(ParameterSetName = 'ByModuleSpecification', DontShow = $true)]
        [Parameter(ParameterSetName = 'ByProjectPath', DontShow = $true)]
        [System.Management.Automation.SwitchParameter]
        $Pesterv5 = $(
            $moduleInformationPester5 = @{
                ModuleName = 'Pester'
                ModuleVersion = '5.0'
            }

            $moduleInformationPester4 = @{
                ModuleName = 'Pester'
                MaximumVersion = '4.99'
            }

            if (
                # Pester 5 is loaded, or we don't have pester 4 loaded and 5 is available
                (Get-Module -FullyQualifiedName $moduleInformationPester5) `
                -or (
                    -not (Get-Module -FullyQualifiedName $moduleInformationPester4) `
                    -and (Get-Module -ListAvailable -FullyQualifiedName $moduleInformationPester5 )
                )
            )
            {
                $true
            }
            else
            {
                $false
            }
        )
    )

    begin
    {
        # Please StrictMode
        $SourcePath = $null

        switch ($PSCmdlet.ParameterSetName)
        {
            'ByModuleNameOrPath'
            {
                Write-Verbose -Message 'Calling DscResource Test by Module Name (or Path).'

                if (-not $PSBoundParameters.ContainsKey('Path'))
                {
                    $PSBoundParameters['Path'] = Join-Path -Path $MyInvocation.MyCommand.Module.ModuleBase -ChildPath 'Tests/QA'
                }

                $null = $PSBoundParameters.Remove('Module')

                $ModuleUnderTest = Import-Module -Name $Module -ErrorAction 'Stop' -Force -PassThru
            }

            'ByModuleSpecification'
            {
                Write-Verbose -Message 'Calling DscResource Test by Module Specification.'

                if (-not $PSBoundParameters.ContainsKey('Path'))
                {
                    $PSBoundParameters['Path'] = Join-Path -Path $MyInvocation.MyCommand.Module.ModuleBase -ChildPath 'Tests/QA'
                }

                $null = $PSBoundParameters.Remove('FullyQualifiedModule')

                $ModuleUnderTest = Import-Module -FullyQualifiedName $FullyQualifiedModule -Force -PassThru -ErrorAction 'Stop'
            }

            'ByProjectPath'
            {
                Write-Verbose -Message 'Calling DscResource Test by Project Path.'

                if (-not $ProjectPath)
                {
                    $ProjectPath = $PWD.Path
                }

                try
                {
                    $null = $PSBoundParameters.Remove('ProjectPath')
                }
                catch
                {
                    Write-Debug -Message 'The function was called via default param set. Using $PWD for Project Path.'
                }

                if (-not $PSBoundParameters.ContainsKey('Path'))
                {
                    $PSBoundParameters['Path'] = Join-Path -Path $MyInvocation.MyCommand.Module.ModuleBase -ChildPath 'Tests/QA'
                }

                # Find the Source Manifest under ProjectPath
                $SourceManifest = ((Get-ChildItem -Path "$ProjectPath\*\*.psd1").Where{
                        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
                        $(
                            try
                            {
                                Test-ModuleManifest -Path $_.FullName -ErrorAction 'Stop'
                            }
                            catch
                            {
                                $false
                            }
                        )
                    }
                )

                $SourcePath = $SourceManifest.Directory.FullName
                $OutputPath = Join-Path -Path $ProjectPath -ChildPath 'output'

                $GetOutputModuleParams = @{
                    Path        = $OutputPath
                    Include     = $SourceManifest.Name
                    Name        = $true # Or it doesn't behave properly on PS5.1
                    Exclude     = 'RequiredModules'
                    ErrorAction = 'Stop'
                    Depth       = 3
                }

                Write-Verbose -Message (
                    "Finding Output Module with `r`n {0}" -f (
                        $GetOutputModuleParams | Format-Table -Property * -AutoSize | Out-String
                    )
                )

                $modulePsd1 = Join-Path -Path $OutputPath -ChildPath (
                    Get-ChildItem @GetOutputModuleParams |
                        Select-Object -First 1
                )

                <#
                    Importing the module psd1 ensures the filtered Import-Module
                    passthru returns only one PSModuleInfo Object: Issue #71
                #>
                $dataFileImport = Import-PowerShellDataFile -Path $modulePsd1

                Write-Verbose -Message "Loading $modulePsd1."

                $ModuleUnderTest = Import-Module -Name $modulePsd1 -ErrorAction 'Stop' -PassThru |
                    Where-Object -FilterScript {
                        $PSItem.Guid -eq $dataFileImport['GUID']
                    }
            }
        }

        $ModuleName = $ModuleUnderTest.Name
        $ModuleBase = $ModuleUnderTest.ModuleBase

        # ExcludeSourceFile may be used by the Pester test files, and will be sent as a parameter (container in v5)
        $ExcludeSourceFile = foreach ($projectFileOrFolder in $ExcludeSourceFile)
        {
            if (-not [System.String]::IsNullOrEmpty($projectFileOrFolder) -and -not (Split-Path -IsAbsolute $projectFileOrFolder))
            {
                Join-Path -Path $SourcePath -ChildPath $projectFileOrFolder
            }
            elseif (-not [System.String]::IsNullOrEmpty($projectFileOrFolder))
            {
                $projectFileOrFolder
            }
        }

        # Remove ExcludeSourceFile from PSBoundParameters (so we can use PSBoundParameters directly to Invoke-Pester)
        if ($PSBoundParameters.ContainsKey('ExcludeSourceFile'))
        {
            $null = $PSBoundParameters.Remove('ExcludeSourceFile')
        }

        # ExcludeModuleFile may be used by the Pester test files, and will be sent as a parameter (container in v5)
        $ExcludeModuleFile = foreach ($moduleFileOrFolder in $ExcludeModuleFile)
        {
            if (-not [System.String]::IsNullOrEmpty($moduleFileOrFolder) -and -not (Split-Path -IsAbsolute $moduleFileOrFolder))
            {
                Join-Path -Path $ModuleUnderTest.ModuleBase -ChildPath $moduleFileOrFolder
            }
            elseif (-not [System.String]::IsNullOrEmpty($moduleFileOrFolder))
            {
                $moduleFileOrFolder
            }
        }

        # Remove ExcludeModuleFile from PSBoundParameters (so we can use PSBoundParameters directly to Invoke-Pester)
        if ($PSBoundParameters.ContainsKey('ExcludeModuleFile'))
        {
            $null = $PSBoundParameters.Remove('ExcludeModuleFile')
        }

        # Please StrictMode
        $optIns = $null
        $optOuts = $null

        <#
            In case of ByProjectPath Opt-ins will be done by tags:
            The Describe Name will be one of the Tag for the Describe block
            If a Opt-In file is found, it will default to auto-populate -Tag
            (cumulative from Command parameters).
        #>
        if ($ProjectPath -and -not $PSBoundParameters.ContainsKey('TagFilter') -and -not $PSBoundParameters.ContainsKey('ExcludeTagFilter'))
        {
            $expectedMetaOptInFile = Join-Path -Path $ProjectPath -ChildPath '.MetaTestOptIn.json'

            if ($PSCmdlet.ParameterSetName -eq 'ByProjectPath' -and (Test-Path -Path $expectedMetaOptInFile))
            {
                Write-Verbose -Message "Loading OptIns from $expectedMetaOptInFile."

                $optIns = Get-StructuredObjectFromFile -Path $expectedMetaOptInFile -ErrorAction 'Stop'
            }

            # Opt-Outs should be preferred, and we can do similar ways with ExcludeTags
            $expectedMetaOptOutFile = Join-Path -Path $ProjectPath -ChildPath '.MetaTestOptOut.json'

            if ($PSCmdlet.ParameterSetName -eq 'ByProjectPath' -and (Test-Path -Path $expectedMetaOptOutFile))
            {
                Write-Verbose -Message "Loading OptOuts from $expectedMetaOptOutFile."

                $optOuts = Get-StructuredObjectFromFile -Path $expectedMetaOptOutFile -ErrorAction 'Stop'
            }
        }

        # For each Possible parameters, use BoundParameters if exists, or use $Settings.ParameterName if exists otherwise
        $possibleParamName = $PSCmdlet.MyInvocation.MyCommand.Parameters.Name

        foreach ($paramName in $possibleParamName)
        {
            if (
                -not $PSBoundParameters.ContainsKey($paramName) `
                -and ($paramValue = $Settings.($paramName))
            )
            {
                Write-Verbose -Message "Adding setting $paramName."

                $PSBoundParameters.Add($paramName, $paramValue)
            }
        }

        $newTag = @()
        $newExcludeTag = @()

        # foreach OptIns, add them to `-Tag`, unless in the ExcludeTags or already in Tag
        foreach ($optInTag in $optIns)
        {
            if (
                $optInTag -notin $PSBoundParameters['ExcludeTagFilter'] `
                -and $optInTag -notin $PSBoundParameters['TagFilter']
            )
            {
                Write-Debug -Message "Adding tag $optInTag."
                $newTag += $optInTag
            }
        }

        if ($newTag.Count -gt 0)
        {
            $PSBoundParameters['TagFilter'] = $newTag
        }

        # foreach OptOuts, add them to `-ExcludeTag`, unless in `-Tag`
        foreach ($optOutTag in $optOuts)
        {
            if (
                $optOutTag -notin $PSBoundParameters['TagFilter'] `
                -and $optOutTag -notin $PSBoundParameters['ExcludeTagFilter']
            )
            {
                Write-Debug -Message "Adding ExcludeTag $optOutTag."

                $newExcludeTag += $optOutTag
            }
        }

        if ($newExcludeTag.Count -gt 0)
        {
            $PSBoundParameters['ExcludeTagFilter'] = $newExcludeTag
        }

        <#
            This won't display the warning message for the skipped blocks
            But should save time by not running initialization code within a Describe Block
            And we can add such warning if we create a static list of the things we can opt-in
            I'd prefer to not keep anything static, and AST risks not to cover 100% (maybe...), and OptOut is preferred

            Most tests should run against the built module
            PSSA could be run against source, or against built module & convert lines/file
        #>

        $ModuleUnderTestManifest = Join-Path -Path $ModuleUnderTest.ModuleBase -ChildPath "$($ModuleUnderTest.Name).psd1"


        if (-not $Pesterv5)
        {
            # In Pester v4, parameters are in hashtable with path @{Script = ''; Parameters = @{...}}
            # In Pester v5 this is now in "Container"
            $ScriptItems = foreach ($item in $PSBoundParameters['Path'])
            {
                if ($item -is [System.Collections.IDictionary])
                {
                    if ($item['Parameters'] -isNot [System.Collections.IDictionary])
                    {
                        $item['Parameters'] = @{ }
                    }

                    $item['Parameters']['ModuleBase'] = $ModuleUnderTest.ModuleBase
                    $item['Parameters']['ModuleName'] = $ModuleUnderTest.Name
                    $item['Parameters']['ModuleManifest'] = $ModuleUnderTestManifest
                    $item['Parameters']['ProjectPath'] = $ProjectPath
                    $item['Parameters']['SourcePath'] = $SourcePath
                    $item['Parameters']['SourceManifest'] = $SourceManifest.FullName
                    $item['Parameters']['Tag'] = $PSBoundParameters['TagFilter']
                    $item['Parameters']['ExcludeTag'] = $PSBoundParameters['ExcludeTagFilter']
                    $item['Parameters']['ExcludeModuleFile'] = $ExcludeModuleFile
                    $item['Parameters']['ExcludeSourceFile'] = $ExcludeSourceFile
                    $item['Parameters']['MainGitBranch'] = $MainGitBranch
                }
                else
                {
                    $item = @{
                        Path       = $item
                        Parameters = @{
                            ModuleBase        = $ModuleUnderTest.ModuleBase
                            ModuleName        = $ModuleUnderTest.Name
                            ModuleManifest    = $ModuleUnderTestManifest
                            ProjectPath       = $ProjectPath
                            SourcePath        = $SourcePath
                            SourceManifest    = $SourceManifest.FullName
                            Tag               = $PSBoundParameters['TagFilter']
                            ExcludeTag        = $PSBoundParameters['ExcludeTagFilter']
                            ExcludeModuleFile = $ExcludeModuleFile
                            ExcludeSourceFile = $ExcludeSourceFile
                            MainGitBranch     = $MainGitBranch
                        }
                    }
                }

                $item
            }

            $PSBoundParameters['Script'] = $ScriptItems

            if ($PSBoundParameters.ContainsKey('Path'))
            {
                $PSBoundParameters.Remove('Path')
            }

            if ($PSBoundParameters.ContainsKey('MainGitBranch'))
            {
                $PSBoundParameters.Remove('MainGitBranch')
            }

            # Remove Pester v5 specific parameter
            if ($PSBoundParameters.ContainsKey('TagFilter'))
            {
                $PSBoundParameters['Tag'] = $PSBoundParameters['TagFilter']
                $PSBoundParameters.Remove('TagFilter')
            }

            if ($PSBoundParameters.ContainsKey('ExcludeTagFilter'))
            {
                $PSBoundParameters['ExcludeTag'] = $PSBoundParameters['ExcludeTagFilter']
                $PSBoundParameters.Remove('ExcludeTagFilter')
            }

            if ($PSBoundParameters.ContainsKey('Configuration'))
            {
                $PSBoundParameters.Remove('Configuration')
            }
        }
        else
        {
            # Pester 5 tests
            $PesterV5AdvancedConfig = @{
                Run          = @{}
                Filter       = @{}
                CodeCoverage = @{}
                TestResult   = @{}
                Should       = @{}
                Debug        = @{}
                Output       = @{}
            }

            # Remove v4 deprecated parameters for v5 invocation (they're in $Configuration)
            @(
                'EnableExit',
                'TagFilter',
                'ExcludeTagFilter',
                'CodeCoverage',
                'CodeCoverageOutputFile',
                'CodeCoverageOutputFileFormat',
                'Strict',
                'Output',
                'OutputFile',
                'OutputFormat',
                'Quiet',
                'PesterOption',
                'Show',
                'MainGitBranch'
            ).ForEach{
                if ($PSBoundParameters.ContainsKey($_))
                {
                    switch ($_)
                    {
                        'EnableExit'
                        {
                            $PesterV5AdvancedConfig['Run']['EnableExit'] = $PSBoundParameters[$_]
                        }

                        'TagFilter'
                        {
                            $PesterV5AdvancedConfig['Filter']['Tag'] = $PSBoundParameters[$_]
                        }

                        'ExcludeTagFilter'
                        {
                            $PesterV5AdvancedConfig['Filter']['ExcludeTag'] = $PSBoundParameters[$_]
                        }

                        'Output'
                        {
                            $PesterV5AdvancedConfig['Output']['Verbosity'] = $PSBoundParameters[$_]
                        }

                        'CodeCoverage'
                        {
                            $PesterV5AdvancedConfig['CodeCoverage']['Enabled'] = $true
                            $PesterV5AdvancedConfig['CodeCoverage']['Path'] = $PSBoundParameters[$_]
                        }

                        'CodeCoverageOutputFile'
                        {
                            $PesterV5AdvancedConfig['CodeCoverage']['OutputPath'] = $PSBoundParameters[$_]
                        }

                        'CodeCoverageOutputFileFormat'
                        {
                            $PesterV5AdvancedConfig['CodeCoverage']['CodeCoverageOutputFileFormat'] = $PSBoundParameters[$_]
                        }

                        'OutputFile'
                        {
                            $PesterV5AdvancedConfig['TestResult']['OutputFile'] = $PSBoundParameters[$_]
                        }

                        'OutputFormat'
                        {
                            $PesterV5AdvancedConfig['TestResult']['OutputFormat'] = $PSBoundParameters[$_]
                        }

                        'Quiet'
                        {
                            $PesterV5AdvancedConfig['Output']['Verbosity'] = 'none'
                        }

                        'Show'
                        {
                            $PesterV5AdvancedConfig['Output']['Verbosity'] = $PSBoundParameters[$_]
                        }
                    }

                    $PSBoundParameters.Remove($_)
                }
            }

            $getDscResourceTestContainerParameters = @{
                ModuleBase        = $ModuleBase
                ModuleName        = $ModuleName
                # ModuleManifest    = $ModuleUnderTestManifest
                # ProjectPath       = $ProjectPath
                # SourcePath        = $SourcePath
                # SourceManifest   = $SourceManifest.FullName
                ExcludeModuleFile = $ExcludeModuleFile
                ExcludeSourceFile = $ExcludeSourceFile
                DefaultBranch     = $MainGitBranch
            }

            if ($ProjectPath)
            {
                $getDscResourceTestContainerParameters.Add('ProjectPath', $ProjectPath)
            }

            if ($SourcePath)
            {
                $getDscResourceTestContainerParameters.Add('SourcePath', $SourcePath)
            }

            $container = Get-DscResourceTestContainer @getDscResourceTestContainerParameters
            $PSBoundParameters['Container'] = $container
        }

        # Below is default command proxy handling
        try
        {
            $outBuffer = $null

            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref] $outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }

            $wrappedCmd = Get-Command -CommandType 'Function' -Name 'Invoke-Pester'

            $scriptCmd = {
                & $wrappedCmd @PSBoundParameters
            }

            $steppablePipeline = $scriptCmd.GetSteppablePipeline()

            $steppablePipeline.Begin($PSCmdlet)
        }
        catch
        {
            throw
        }
    }

    process
    {
        try
        {
            $steppablePipeline.Process($_)
        }
        catch
        {
            throw
        }
    }

    end
    {
        try
        {
            $steppablePipeline.End()
        }
        catch
        {
            throw
        }
    }
}

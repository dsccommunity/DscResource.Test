<#
    .ForwardHelpTargetName Invoke-Pester
    .ForwardHelpCategory Function
#>
function Invoke-DscResourceTest
{
    [CmdletBinding(DefaultParameterSetName = 'ByProjectPath')]
    param
    (
        # [Parameter(Mandatory = $true, ParameterSetName = 'Pester5', Position = 0)]
        # [System.String]
        # $v5,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath', Position = 0)]
        [System.String]
        $Module,

        [Parameter(ParameterSetName = 'ByModuleSpecification', Position = 0)]
        [Microsoft.PowerShell.Commands.ModuleSpecification]
        $FullyQualifiedModule,

        [Parameter(ParameterSetName = 'ByProjectPath', Position = 0)]
        [Parameter(Mandatory = $true, ParameterSetName = 'Pester5')]
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
        $EnableExit,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath', Position = 5)]
        [Parameter(ParameterSetName = 'ByModuleSpecification', Position = 5)]
        [Parameter(ParameterSetName = 'ByProjectPath', Position = 5)]
        [Parameter(ParameterSetName = 'Pester5')]
        [Alias('Tags','Tag')]
        [System.String[]]
        $TagFilter,

        [Parameter()]
        [Alias('ExcludeTag')]
        [System.String[]]
        $ExcludeTagFilter,

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
        $CodeCoverage,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [System.String]
        $CodeCoverageOutputFile,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [ValidateSet('JaCoCo')]
        [System.String]
        $CodeCoverageOutputFileFormat,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [System.Management.Automation.SwitchParameter]
        $Strict,

        [Parameter()]
        [System.String]
        $Output,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [System.String]
        $OutputFile,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [ValidateSet('NUnitXml', 'JUnitXml')]
        [System.String]
        $OutputFormat,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [System.Management.Automation.SwitchParameter]
        $Quiet,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [System.Object]
        $PesterOption,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [Pester.OutputTypes]
        $Show,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [System.Collections.Hashtable]
        $Settings,

        [Parameter(ParameterSetName = 'ByModuleNameOrPath')]
        [Parameter(ParameterSetName = 'ByModuleSpecification')]
        [Parameter(ParameterSetName = 'ByProjectPath')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Pester5')]
        [System.String]
        $MainGitBranch = 'master',

        [Parameter(Mandatory = $true, ParameterSetName = 'Pester5')]
        [System.String]
        $ModuleName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Pester5')]
        [System.String]
        $SourcePath,

        [Parameter(Mandatory = $true, ParameterSetName = 'Pester5')]
        [System.String]
        $ModuleBase
    )

    begin
    {
        if ($PSCmdlet.ParameterSetName -ne 'Pester5')
        {
            <#
                Run old Pester 4 workflow.

                Make sure Invoke-DscResourceTest runs against the Built Module either:

                By $Module (Name, Path, ModuleSpecification): enables to run some tests on installed modules (even without source)
                By $ProjectPath (detect source from there based on .psd1): Target both the source when relevant and the expected files
            #>

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

            if ($PSBoundParameters.ContainsKey('ExcludeSourceFile'))
            {
                $null = $PSBoundParameters.Remove('ExcludeSourceFile')
            }

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

            if ($PSBoundParameters.ContainsKey('ExcludeModuleFile'))
            {
                $null = $PSBoundParameters.Remove('ExcludeModuleFile')
            }


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
                            ModuleBase         = $ModuleUnderTest.ModuleBase
                            ModuleName         = $ModuleUnderTest.Name
                            ModuleManifest     = $ModuleUnderTestManifest
                            ProjectPath        = $ProjectPath
                            SourcePath         = $SourcePath
                            SourceManifest     = $SourceManifest.FullName
                            Tag                = $PSBoundParameters['TagFilter']
                            ExcludeTag         = $PSBoundParameters['ExcludeTagFilter']
                            ExcludeModuleFile  = $ExcludeModuleFile
                            ExcludeSourceFile  = $ExcludeSourceFile
                            MainGitBranch      = $MainGitBranch
                        }
                    }
                }

                $item
            }

            $PSBoundParameters['Path'] = $ScriptItems

            $invokePesterParameters = @{
                PassThru = $PSBoundParameters.PassThru
            }

            $invokePesterParameters['Script'] = $PSBoundParameters.Path

            if ($PSBoundParameters.ContainsKey('TestName'))
            {
                $invokePesterParameters['TestName'] = $PSBoundParameters.TestName
            }

            if ($PSBoundParameters.ContainsKey('EnableExit'))
            {
                $invokePesterParameters['EnableExit'] = $PSBoundParameters.EnableExit
            }

            if ($PSBoundParameters.ContainsKey('TagFilter'))
            {
                $invokePesterParameters['Tag'] = $PSBoundParameters.TagFilter
            }

            if ($PSBoundParameters.ContainsKey('ExcludeTagFilter'))
            {
                $invokePesterParameters['ExcludeTag'] = $PSBoundParameters.ExcludeTagFilter
            }

            if ($PSBoundParameters.ContainsKey('OutputFile'))
            {
                $invokePesterParameters['OutputFile'] = $PSBoundParameters.OutputFile
            }

            if ($PSBoundParameters.ContainsKey('OutputFormat'))
            {
                $invokePesterParameters['OutputFormat'] = $PSBoundParameters.OutputFormat
            }

            if ($PSBoundParameters.ContainsKey('CodeCoverage'))
            {
                $invokePesterParameters['CodeCoverage'] = $PSBoundParameters.CodeCoverage
            }

            if ($PSBoundParameters.ContainsKey('CodeCoverageOutputFile'))
            {
                $invokePesterParameters['CodeCoverageOutputFile'] = $PSBoundParameters.CodeCoverageOutputFile
            }

            if ($PSBoundParameters.ContainsKey('CodeCoverageOutputFileFormat'))
            {
                $invokePesterParameters['CodeCoverageOutputFileFormat'] = $PSBoundParameters.CodeCoverageOutputFileFormat
            }

            if ($PSBoundParameters.ContainsKey('PesterOption'))
            {
                $invokePesterParameters['PesterOption'] = $PSBoundParameters.PesterOption
            }

            if ($PSBoundParameters.ContainsKey('Show'))
            {
                $invokePesterParameters['Show'] = $PSBoundParameters.Show
            }
        }
        else
        {
            # Pester 5 tests

            $invokePesterParameters = @{}

            $getDscResourceTestContainerParameters = @{
                ProjectPath       = $ProjectPath
                ModuleName        = $ModuleName
                DefaultBranch     = $MainGitBranch
                SourcePath        = $SourcePath
                ExcludeSourceFile = $ExcludeSourceFile
                ModuleBase        = $ModuleBase
                ExcludeModuleFile = $ExcludeModuleFile
            }

            $container = Get-DscResourceTestContainer @getDscResourceTestContainerParameters

            $invokePesterParameters['Container'] = $container

            if ($PSBoundParameters.ContainsKey('Output'))
            {
                $invokePesterParameters['Output'] = $Output
            }

            if ($PSBoundParameters.ContainsKey('ExcludeTagFilter'))
            {
                $invokePesterParameters['ExcludeTagFilter'] = $ExcludeTagFilter
            }

            if ($PSBoundParameters.ContainsKey('TagFilter'))
            {
                $invokePesterParameters['TagFilter'] = $TagFilter
            }

            if ($PSBoundParameters.ContainsKey('PassThru'))
            {
                $invokePesterParameters['PassThru'] = $PassThru
            }
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
                & $wrappedCmd @invokePesterParameters
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

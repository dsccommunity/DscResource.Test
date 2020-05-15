function Invoke-DscResourceTest
{
    [CmdletBinding(DefaultParameterSetName = 'ByProjectPath')]
    param (
        [Parameter(ParameterSetName = 'ByModuleNameOrPath', Position = 0)]
        [System.String]
        ${Module},

        [Parameter(ParameterSetName = 'ByModuleSpecification', Position = 0)]
        [Microsoft.PowerShell.Commands.ModuleSpecification]
        $FullyQualifiedModule,

        [Parameter(ParameterSetName = 'ByProjectPath', Position = 0)]
        [System.String]
        ${ProjectPath},

        [Parameter(Position = 1)]
        [Alias('Path', 'relative_path')]
        [System.Object[]]
        ${Script},

        [Parameter(Position = 2)]
        [Alias('Name')]
        [string[]]
        ${TestName},

        [Parameter(Position = 3)]
        [switch]
        ${EnableExit},

        [Parameter(Position = 5)]
        [Alias('Tags')]
        [string[]]
        ${Tag},

        [Parameter()]
        [string[]]
        ${ExcludeTag},

        [Parameter()]
        [string[]]
        ${ExcludeModuleFile},

        [Parameter()]
        [string[]]
        ${ExcludeSourceFile},

        [Parameter()]
        [switch]
        ${PassThru},

        [Parameter()]
        [System.Object[]]
        ${CodeCoverage},

        [Parameter()]
        [string]
        ${CodeCoverageOutputFile},

        [Parameter()]
        [ValidateSet('JaCoCo')]
        [string]
        ${CodeCoverageOutputFileFormat},

        [Parameter()]
        [switch]
        ${Strict},

        [Parameter()]
        [string]
        ${OutputFile},

        [Parameter()]
        [ValidateSet('NUnitXml', 'JUnitXml')]
        [string]
        ${OutputFormat},

        [Parameter()]
        [switch]
        ${Quiet},

        [Parameter()]
        [System.Object]
        ${PesterOption},

        [Parameter()]
        [Pester.OutputTypes]
        ${Show},

        [Parameter()]
        [Hashtable]
        $Settings

    )

    begin
    {
        # Make sure Invoke-DscResourceTest runs against the Built Module either:
        #   By $Module (Name, Path, ModuleSpecification): enables to run some tests on installed modules (even without source)
        #   By $ProjectPath (detect source from there based on .psd1): Target both the source when relevant and the expected files

        switch ($PSCmdlet.ParameterSetName)
        {
            'ByModuleNameOrPath'
            {
                Write-Verbose "Calling DscResource Test by Module Name (Or Path)"
                if (!$PSBoundParameters.ContainsKey('Script'))
                {
                    $PSBoundParameters['Script'] = Join-Path -Path $MyInvocation.MyCommand.Module.ModuleBase -ChildPath 'Tests/QA'
                }
                $null = $PSBoundParameters.Remove('Module')
                $ModuleUnderTest = Import-Module -Name $Module -ErrorAction Stop -Force -PassThru
            }

            'ByModuleSpecification'
            {
                Write-Verbose "Calling DscResource Test by Module Specification"
                if (!$PSBoundParameters.ContainsKey('Script'))
                {
                    $PSBoundParameters['Script'] = Join-Path -Path $MyInvocation.MyCommand.Module.ModuleBase -ChildPath 'Tests/QA'
                }
                $null = $PSBoundParameters.Remove('FullyQualifiedModule')
                $ModuleUnderTest = Import-Module -FullyQualifiedName $FullyQualifiedModule -Force -PassThru -ErrorAction Stop
            }

            'ByProjectPath'
            {
                Write-Verbose "Calling DscResource Test by Project Path"
                if (!$ProjectPath)
                {
                    $ProjectPath = $PWD.Path
                }

                try
                {
                    $null = $PSBoundParameters.Remove('ProjectPath')
                }
                catch
                {
                    Write-Debug -Message "The function was called via default param set. Using `$PWD for Project Path"
                }

                if (!$PSBoundParameters.ContainsKey('Script'))
                {
                    $PSBoundParameters['Script'] = Join-Path -Path $MyInvocation.MyCommand.Module.ModuleBase -ChildPath 'Tests/QA'
                }
                # Find the Source Manifest under ProjectPath
                $SourceManifest = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
                        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
                        $(try
                            {
                                Test-ModuleManifest $_.FullName -ErrorAction Stop
                            }
                            catch
                            {
                                $false
                            } )
                    })

                $SourcePath = $SourceManifest.Directory.FullName
                $OutputPath = Join-Path $ProjectPath 'output'

                $GetOutputModuleParams = @{
                    Path        = $OutputPath
                    Include     = $SourceManifest.Name
                    Name        = $True # Or it doesn't behave properly on PS5.1
                    Exclude     = 'RequiredModules'
                    ErrorAction = 'Stop'
                    Depth       = 3
                }

                Write-Verbose (
                    "Finding Output Module with `r`n {0}" -f
                    ($GetOutputModuleParams | Format-Table -Property * -AutoSize | Out-String)
                )

                $ModulePsd1 = Join-Path -Path $OutputPath (Get-ChildItem @GetOutputModuleParams | Select-Object -First 1)
                # Importing the module psd1 ensures the filtered Import-Module passthru returns only one PSModuleInfo Object: Issue #71
                $dataFileImport = Import-PowerShellDataFile -Path $ModulePsd1
                Write-Verbose "Loading $ModulePsd1"
                $ModuleUnderTest = Import-Module -Name $ModulePsd1 -ErrorAction Stop -PassThru | Where-Object -FilterScript {$PSItem.Guid -eq $dataFileImport['GUID']}
            }
        }

        $ExcludeSourceFile = foreach ($projectFileOrFolder in $ExcludeSourceFile)
        {
            if (![string]::IsNullOrEmpty($projectFileOrFolder) -and !(Split-Path -IsAbsolute $projectFileOrFolder))
            {
                Join-Path -Path $SourcePath -ChildPath $projectFileOrFolder
            }
            elseif (![string]::IsNullOrEmpty($projectFileOrFolder))
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
            if (![string]::IsNullOrEmpty($moduleFileOrFolder) -and !(Split-Path -IsAbsolute $moduleFileOrFolder))
            {
                Join-Path -Path $ModuleUnderTest.ModuleBase -ChildPath $moduleFileOrFolder
            }
            elseif (![string]::IsNullOrEmpty($moduleFileOrFolder))
            {
                $moduleFileOrFolder
            }
        }

        if ($PSBoundParameters.ContainsKey('ExcludeModuleFile'))
        {
            $null = $PSBoundParameters.Remove('ExcludeModuleFile')
        }


        # In case of ByProjectPath Opt-ins will be done by tags:
        #   The Describe Name will be one of the Tag for the Describe block
        #   If a Opt-In file is found, it will default to auto-populate -Tag (cumulative from Command parameters)
        if ($ProjectPath -and !$PSBoundParameters.ContainsKey('Tag') -and !$PSBoundParameters.ContainsKey('ExcludeTag'))
        {
            $ExpectedMetaOptInFile = Join-Path -Path $ProjectPath -ChildPath '.MetaTestOptIn.json'
            if ($PSCmdlet.ParameterSetName -eq 'ByProjectPath' -and (Test-Path $ExpectedMetaOptInFile))
            {
                Write-Verbose -Message "Loading OptIns from $ExpectedMetaOptInFile"
                $OptIns = Get-StructuredObjectFromFile -Path $ExpectedMetaOptInFile -ErrorAction Stop
            }
            # Opt-Outs should be preferred, and we can do similar ways with ExcludeTags
            $ExpectedMetaOptOutFile = Join-Path -Path $ProjectPath -ChildPath '.MetaTestOptOut.json'
            if ($PSCmdlet.ParameterSetName -eq 'ByProjectPath' -and (Test-Path $ExpectedMetaOptOutFile))
            {
                Write-Verbose -Message "Loading OptOuts from $ExpectedMetaOptOutFile"
                $OptOuts = Get-StructuredObjectFromFile -Path $ExpectedMetaOptOutFile -ErrorAction Stop
            }
        }

        # For each Possible parameters, use BoundParameters if exists, or use $Settings.ParameterName if exists otherwise
        $PossibleParamName = $PSCmdlet.MyInvocation.MyCommand.Parameters.Name
        foreach ($ParamName in $PossibleParamName)
        {
            if ( !$PSBoundParameters.ContainsKey($ParamName) -and
                ($ParamValue = $Settings.($ParamName))
            )
            {
                Write-Verbose -Message "Adding setting $ParamName"
                $PSBoundParameters.Add($ParamName, $ParamValue)
            }
        }

        $newTag = @()
        $newExcludeTag = @()

        # foreach OptIns, add them to `-Tag`, unless in the ExcludeTags or already in Tag
        foreach ($OptInTag in $OptIns)
        {
            if ( $OptInTag -notIn $PSBoundParameters['ExcludeTag'] -and
                $OptInTag -notIn $PSBoundParameters['Tag']
            )
            {
                Write-Debug -Message "Adding tag $OptInTag"
                $newTag += $OptInTag
            }
        }

        if ($newTag.Count -gt 0)
        {
            $PSBoundParameters['Tag'] = $newTag
        }

        # foreach OptOuts, add them to `-ExcludeTag`, unless in `-Tag`
        foreach ($OptOutTag in $OptOuts)
        {
            if ( $OptOutTag -notIn $PSBoundParameters['Tag'] -and
                $OptOutTag -notIn $PSBoundParameters['ExcludeTag']
            )
            {
                Write-Debug -Message "Adding ExcludeTag $OptOutTag"
                $newExcludeTag += $OptOutTag
            }
        }

        if ($newExcludeTag.Count -gt 0)
        {
            $PSBoundParameters['ExcludeTag'] = $newExcludeTag
        }

        # This won't display the warning message for the skipped blocks
        #  But should save time by not running initialization code within a Describe Block
        #  And we can add such warning if we create a static list of the things we can opt-in
        #  I'd prefer to not keep anything static, and AST risks not to cover 100% (maybe...), and OptOut is preferred

        # Most tests should run against the built module
        # PSSA could be run against source, or against built module & convert lines/file

        $ModuleUnderTestManifest = Join-Path -Path $ModuleUnderTest.ModuleBase -ChildPath "$($ModuleUnderTest.Name).psd1"

        $ScriptItems = foreach ($item in $PSBoundParameters['Script'])
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
                $item['Parameters']['Tag'] = $PSBoundParameters['Tag']
                $item['Parameters']['ExcludeTag'] = $PSBoundParameters['ExcludeTag']
                $item['Parameters']['ExcludeModuleFile'] = $ExcludeModuleFile
                $item['Parameters']['ExcludeSourceFile'] = $ExcludeSourceFile
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
                        Tag                = $PSBoundParameters['Tag']
                        ExcludeTag         = $PSBoundParameters['ExcludeTag']
                        ExcludeModuleFile  = $ExcludeModuleFile
                        ExcludeSourceFile = $ExcludeSourceFile
                    }
                }
            }

            $item
        }

        $PSBoundParameters['Script'] = $ScriptItems

        # Below is default command proxy handling
        try
        {
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }
            $wrappedCmd = Get-Command -CommandType Function -Name Invoke-Pester
            $scriptCmd = { & $wrappedCmd @PSBoundParameters }
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
    <#

.ForwardHelpTargetName Invoke-Pester
.ForwardHelpCategory Function

#>


}

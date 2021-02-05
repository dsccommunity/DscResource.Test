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
    $OutputDirectory = (property OutputDirectory (Join-Path $BuildRoot 'output')),

    [Parameter()]
    [System.String]
    $ProjectName = (property ProjectName ''),

    [Parameter()]
    [System.String]
    $DscTestOutputFolder = (property DscTestOutputFolder 'testResults'),

    # Build Configuration object
    [Parameter()]
    [System.Collections.Hashtable]
    $BuildInfo = (property BuildInfo @{ })
)

# Synopsis: This task ensures the build job fails if the test aren't successful.
task Fail_Build_If_HQRM_Tests_Failed {
    "Asserting that no test failed."

    if ([System.String]::IsNullOrEmpty($ProjectName))
    {
        $ProjectName = Get-ProjectName -BuildRoot $BuildRoot
    }

    if (-not (Split-Path -IsAbsolute $OutputDirectory))
    {
        $OutputDirectory = Join-Path -Path $ProjectPath -ChildPath $OutputDirectory

        Write-Build -Color 'Yellow' -Text "Absolute path to Output Directory is $OutputDirectory"
    }

    if (-not (Split-Path -IsAbsolute $DscTestOutputFolder))
    {
        $DscTestOutputFolder = Join-Path -Path $OutputDirectory -ChildPath $DscTestOutputFolder
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

    $getModuleVersionParameters = @{
        OutputDirectory = $OutputDirectory
        ProjectName     = $ProjectName
    }

    $ModuleVersion = Get-BuiltModuleVersion @getModuleVersionParameters

    $psVersion = 'PSv.{0}' -f $PSVersionTable.PSVersion
    $DscTestOutputFileFileName = "DscTest_{0}_v{1}.{2}.{3}.xml" -f $ProjectName, $ModuleVersion, $os, $psVersion
    $DscTestResultObjectClixml = Join-Path -Path $DscTestOutputFolder -ChildPath "DscTestObject_$DscTestOutputFileFileName"

    "`t"
    "`tProject Path        = $ProjectPath"
    "`tProject Name        = $ProjectName"
    "`tOutput Directory    = $OutputDirectory"
    "`tTest Output Folder  = $DscTestOutputFolder"
    "`tTest Output Object  = $DscTestResultObjectClixml"
    "`t"

    if (-not (Test-Path -Path $DscTestResultObjectClixml))
    {
        throw "No command were tested. $DscTestResultObjectClixml not found."
    }
    else
    {
        $DscTestObject = Import-Clixml -Path $DscTestResultObjectClixml -ErrorAction 'Stop'

        Assert-Build -Condition ($DscTestObject.FailedCount -eq 0) -Message ('Failed {0} tests. Aborting Build.' -f $DscTestObject.FailedCount)
    }
}

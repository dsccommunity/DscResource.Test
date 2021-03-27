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
    $BuiltModuleSubdirectory = (property BuiltModuleSubdirectory ''),

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $VersionedOutputDirectory = (property VersionedOutputDirectory $true),

    [Parameter()]
    [System.String]
    $ProjectName = (property ProjectName $(Get-SamplerProjectName -BuildRoot $BuildRoot)),

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

    $OutputDirectory = Get-SamplerAbsolutePath -Path $OutputDirectory -RelativeTo $BuildRoot

    "`tOutputDirectory       = '$OutputDirectory'"

    $BuiltModuleSubdirectory = Get-SamplerAbsolutePath -Path $BuiltModuleSubdirectory -RelativeTo $OutputDirectory

    if ($VersionedOutputDirectory)
    {
        # VersionedOutputDirectory is not [bool]'' nor $false nor [bool]$null
        # Assume true, wherever it was set
        $VersionedOutputDirectory = $true
    }
    else
    {
        # VersionedOutputDirectory may be [bool]'' but we can't tell where it's
        # coming from, so assume the build info (Build.yaml) is right
        $VersionedOutputDirectory = $BuildInfo['VersionedOutputDirectory']
    }

    $GetBuiltModuleManifestParams = @{
        OutputDirectory          = $OutputDirectory
        BuiltModuleSubdirectory  = $BuiltModuleSubDirectory
        ModuleName               = $ProjectName
        VersionedOutputDirectory = $VersionedOutputDirectory
        ErrorAction              = 'Stop'
    }

    $builtModuleManifest = Get-SamplerBuiltModuleManifest @GetBuiltModuleManifestParams
    $builtModuleManifest = [string](Get-Item -Path $builtModuleManifest).FullName

    "`tBuilt Module Manifest = '$builtModuleManifest'"

    $builtModuleBase = Get-SamplerBuiltModuleBase @GetBuiltModuleManifestParams
    $builtModuleBase = [string](Get-Item -Path $builtModuleBase).FullName

    "`tBuilt Module Base     = '$builtModuleBase'"

    $moduleVersion = Get-BuiltModuleVersion @GetBuiltModuleManifestParams

    $moduleVersionObject = Split-ModuleVersion -ModuleVersion $moduleVersion
    $moduleVersionFolder = $moduleVersionObject.Version
    $preReleaseTag       = $moduleVersionObject.PreReleaseString

    "`tModule Version        = '$ModuleVersion'"
    "`tModule Version Folder = '$moduleVersionFolder'"
    "`tPre-release Tag       = '$preReleaseTag'"

    "`tProject Path          = $ProjectPath"
    "`tProject Name          = $ProjectName"
    "`tBuilt Module Base     = $builtModuleBase"

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

    $psVersion = 'PSv.{0}' -f $PSVersionTable.PSVersion
    $DscTestOutputFileFileName = "DscTest_{0}_v{1}.{2}.{3}.xml" -f $ProjectName, $ModuleVersion, $os, $psVersion
    $DscTestResultObjectClixml = Join-Path -Path $DscTestOutputFolder -ChildPath "DscTestObject_$DscTestOutputFileFileName"

    "`t"
    "`tTest Output Folder    = $DscTestOutputFolder"
    "`tTest Output Object    = $DscTestResultObjectClixml"
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

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

    # Get the values for task variables
    . Set-SamplerTaskVariable

    "`tProject Path          = $ProjectPath"

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

        <#
            A discovery/container failure (for example an empty -ForEach, or a
            parse error in a test file) does not increase FailedCount. It is
            reported through FailedContainersCount/FailedBlocksCount and the
            overall Result. Gating on FailedCount alone therefore lets such
            failures slip through as a green build. Gate on Result instead, which
            already accounts for failed tests, blocks and containers. This mirrors
            the check already used in the Invoke_HQRM_Tests task.
        #>
        $assertMessage = "Pester result was '{0}'. Failed {1} test(s), {2} block(s) and {3} container(s). Aborting Build." -f
            $DscTestObject.Result, $DscTestObject.FailedCount, $DscTestObject.FailedBlocksCount, $DscTestObject.FailedContainersCount

        Assert-Build -Condition ($DscTestObject.Result -eq 'Passed') -Message $assertMessage
    }
}

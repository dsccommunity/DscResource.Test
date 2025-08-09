<#
    .NOTES
        To run manually:

        $dscResourceModuleName = 'JeaDsc'
        $pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

        $container = New-PesterContainer -Path "$pathToHQRMTests/ModuleManifest.common.*.Tests.ps1" -Data @{
            ModuleName = $dscResourceModuleName
            ModuleBase = "./output/$dscResourceModuleName/*"
        }

        Invoke-Pester -Container $container -Output Detailed
#>
param
(
    [Parameter(Mandatory = $true)]
    [System.String]
    $ModuleName,

    [Parameter(Mandatory = $true)]
    [System.String]
    $ModuleBase,

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
$PSDefaultParameterValues['It:AllowNullOrEmptyForEach'] = $true

BeforeDiscovery {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force

    $moduleFiles = Get-ChildItem -Path $ModuleBase -Filter '*.psm1' -Recurse

    $classResourcesInModule = foreach ($moduleFile in $moduleFiles)
    {
        Get-ClassResourceNameFromFile -FilePath $moduleFile.FullName
    }

    #region Setup text file test cases.
    $classBasedResource = @()

    foreach ($resourceName in $classResourcesInModule)
    {
        $classBasedResource += @(
            @{
                Name = $resourceName
            }
        )
    }

    # Check if module contains class-based resources for DSCv2 compatibility tests
    $hasClassBasedResources = Test-ModuleContainsClassResource -ModulePath $ModuleBase
}

BeforeAll {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force
}

AfterAll {
    # Re-import just the public functions.
    Import-Module -Name 'DscResource.Test' -Force
}

Describe 'Common Tests - Module Manifest' -Tag 'Common Tests - Module Manifest' {
    BeforeAll {
        $moduleManifestPath = Join-Path -Path $ModuleBase -ChildPath "$ModuleName.psd1"

        $script:moduleManifestProperties = Import-PowerShellDataFile -Path $moduleManifestPath -ErrorAction 'Stop'
    }

    It 'Should have valid module manifest' {
        $moduleManifest = Test-ModuleManifest -Path $moduleManifestPath -ErrorAction 'SilentlyContinue'

        $moduleManifest.Name | Should -Not -BeNullOrEmpty
    }

    It 'Should contain a PowerShellVersion property with a minimum value based on resource types' {
        $containsClassResource = Test-ModuleContainsClassResource -ModulePath $ModuleBase

        if ($containsClassResource)
        {
            $minimumPSVersion = [Version] '5.0'
        }
        else
        {
            $minimumPSVersion = [Version] '4.0'
        }

        $script:moduleManifestProperties.PowerShellVersion -ge $minimumPSVersion | Should -BeTrue -Because ('the test evaluated that the minimum version should be ''{0}''' -f $minimumPSVersion)
    }

    Context 'When class-based resources exist' {
        It 'Should explicitly export <Name> in DscResourcesToExport'  -ForEach $classBasedResource {
            $script:moduleManifestProperties.DscResourcesToExport | Should -Contain $Name
        }
    }

    Context 'When class-based resources exist in the module' -Skip:(-not $hasClassBasedResources) {
        BeforeDiscovery {
            $moduleManifestPath = Join-Path -Path $ModuleBase -ChildPath "$ModuleName.psd1"
            $rawModuleManifest = Import-PowerShellDataFile -Path $moduleManifestPath -ErrorAction 'Stop'
            $cmdletsToExportExists = $rawModuleManifest.ContainsKey('CmdletsToExport')

            # Determine which tests should run based on CmdletsToExport existence and type
            $runStringTest = $cmdletsToExportExists -and ($rawModuleManifest.CmdletsToExport -is [System.String])
            $runArrayTest = $cmdletsToExportExists -and ($rawModuleManifest.CmdletsToExport -is [System.Array])
        }

        Context 'When CmdletsToExport is a string' -Skip:(-not $runStringTest) {
            It 'Should have CmdletsToExport set to ''*'' when it is a string for compatibility with DSCv2' -ForEach @($rawModuleManifest) {
                $cmdletsToExport = $_.CmdletsToExport

                $cmdletsToExport | Should -Be '*' -Because 'when CmdletsToExport is a string in a module with class-based resources, it must be set to ''*'' for compatibility with PSDesiredStateConfiguration 2.0.7'
            }
        }

        Context 'When CmdletsToExport is an array' -Skip:(-not $runArrayTest) {
            It 'Should have CmdletsToExport as a non-empty array when it is an array for compatibility with DSCv2' -ForEach @($rawModuleManifest) {
                $cmdletsToExport = $_.CmdletsToExport

                $cmdletsToExport.Count | Should -BeGreaterOrEqual 1 -Because 'when CmdletsToExport is an array in a module with class-based resources, it must contain at least one element for compatibility with PSDesiredStateConfiguration 2.0.7'
            }
        }
    }
}

$PSDefaultParameterValues.Remove('Context:AllowNullOrEmptyForEach')
$PSDefaultParameterValues.Remove('It:AllowNullOrEmptyForEach')

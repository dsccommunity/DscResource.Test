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

        <#
            ErrorAction specified as SilentlyContinue because this call will throw an error
            on machines with an older PS version than the manifest requires. If a WMF 5.1
            is not available modules that require 5.1 (e.g. PSDscResources) would always
            crash this test.
        #>
        $moduleManifestProperties = Test-ModuleManifest -Path $moduleManifestPath -ErrorAction 'SilentlyContinue'
    }

    It "Should contain a PowerShellVersion property with a minimum value based on resource types" {
        $containsClassResource = Test-ModuleContainsClassResource -ModulePath $ModuleBase

        if ($containsClassResource)
        {
            $minimumPSVersion = [Version] '5.0'
        }
        else
        {
            $minimumPSVersion = [Version] '4.0'
        }

        $moduleManifestProperties.PowerShellVersion -ge $minimumPSVersion | Should -BeTrue -Because ('the test evaluated that the minimum version should be ''{0}''' -f $minimumPSVersion)
    }

    Context 'When class-based resources <Name> exist' -ForEach $classBasedResource {
        It "Should explicitly export <Name> in DscResourcesToExport" {
            <#
                NOTE: In PowerShell 7.1.0 the cmdlet Test-ModuleManifest returns
                $null for the property ExportedDscResources even if the property
                have values in the module manifest.
            #>
            $moduleManifestProperties.ExportedDscResources | Should -Contain $Name
        }
    }
}

$PSDefaultParameterValues.Remove('Context:AllowNullOrEmptyForEach')

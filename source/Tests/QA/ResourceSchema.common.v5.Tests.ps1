
<#
    .NOTES
        To run manually:

        $dscResourceModuleName = 'FileSystemDsc'
        $pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

        $container = New-PesterContainer -Path "$pathToHQRMTests/ResourceSchema.common.*.Tests.ps1" -Data @{
            ModuleBase = "./output/$dscResourceModuleName/*"
        }

        Invoke-Pester -Container $container -Output Detailed
#>
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param
(
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

    $skipTests = $false

    if ($PSVersionTable.PSEdition -ne 'Desktop')
    {
        $skipTests = $true

        Write-Warning 'xDscResourceDesigner module only works on Windows PowerShell at the moment.'
    }
    elseif ($IsLinux -or $IsMacOS)
    {
        $skipTests = $true

        Write-Warning 'xDscResourceDesigner module only works on Windows at the moment.'
    }
    else
    {
        $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin)
        {
            Write-Warning 'xDscResourceDesigner needs your session to be running elevated.'

            $skipTests = $true
        }
    }

    if ($skipTests)
    {
        Write-Warning 'Test-xDscResource & Test-xDscSchema will be skipped.'
    }

    $resourceNames = @(Get-ModuleScriptResourceName -ModulePath $ModuleBase)
}

Describe 'Common Tests - Script Resource Schema Validation' -Tag 'WindowsOnly' {
    BeforeAll {
        Import-Module -Name xDscResourceDesigner -ErrorAction 'Stop'
    }

    Context 'When MOF resource <_> exist' -ForEach $resourceNames {
        It 'Should pass Test-xDscResource' -Skip:$skipTests {
            Test-xDscResource -Name $_ | Should -BeTrue
        }

        It 'Should pass Test-xDscSchema' -Skip:$skipTests {
            $dscResourcesFolderFilePath = Join-Path -Path $ModuleBase -ChildPath 'DscResources'
            $scriptResourcePath = Join-Path -Path $dscResourcesFolderFilePath -ChildPath $_
            $mofSchemaFilePath = Join-Path -Path $scriptResourcePath -ChildPath ('{0}.schema.mof' -f $_)

            # Expand the path so any '*' is resolved to the correct version number.
            $resolvedPath = Resolve-Path -Path $mofSchemaFilePath

            # Must pass an explicit path to Test-xDscSchema otherwise it fails.
            Test-xDscSchema -Path $resolvedPath | Should -BeTrue
        }
    }
}

$PSDefaultParameterValues.Remove('Context:AllowNullOrEmptyForEach')

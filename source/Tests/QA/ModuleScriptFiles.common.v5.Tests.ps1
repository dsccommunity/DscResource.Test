<#
    .NOTES
        To run manually:

        $dscResourceModuleName = 'FileSystemDsc'
        $pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

        $container = New-PesterContainer -Path "$pathToHQRMTests/ModuleScriptFiles.common.*.Tests.ps1" -Data @{
            ProjectPath = '.'
            ModuleBase = "./output/$dscResourceModuleName/*"
            # SourcePath = './source'
            # ExcludeModuleFile = @('Modules/DscResource.Common')
            # ExcludeSourceFile = @('Examples')
        }

        Invoke-Pester -Container $container -Output Detailed
#>
param
(
    [Parameter()]
    [System.String]
    $ProjectPath,

    [Parameter(Mandatory = $true)]
    [System.String]
    $ModuleBase,

    [Parameter()]
    [System.String]
    $SourcePath,

    [Parameter()]
    [System.String[]]
    $ExcludeModuleFile,

    [Parameter()]
    [System.String[]]
    $ExcludeSourceFile,

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

    $moduleFiles = @(Get-ChildItem -Path $ModuleBase -Filter '*.psm1' -Recurse | WhereModuleFileNotExcluded -ExcludeModuleFile $ExcludeModuleFile)

    if ($SourcePath)
    {
        $moduleFiles += @(Get-ChildItem -Path $SourcePath -Filter '*.psm1' -Recurse | WhereSourceFileNotExcluded -ExcludeSourceFile $ExcludeSourceFile)
    }

    if ($ProjectPath)
    {
        # Expand the project folder if it is a relative path.
        $resolvedProjectPath = (Resolve-Path -Path $ProjectPath).Path
    }
    else
    {
        $resolvedProjectPath = $ModuleBase
    }

    $moduleFileToTest = @()

    foreach ($file in $moduleFiles)
    {
        # Use the project folder to extrapolate relative path.
        $descriptiveName = Get-RelativePathFromModuleRoot -FilePath $file.FullName -ModuleRootFilePath $resolvedProjectPath

        $moduleFileToTest += @(
            @{
                File            = $file
                DescriptiveName = $descriptiveName
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

Describe 'Common Tests - Module Script Files' -Tag 'Common Tests - Module Script Files' {
    Context 'When module file <DescriptiveName> exist' -ForEach $moduleFileToTest {
        It 'Should not contain parse errors' {
            $parseErrors = Get-FileParseError -FilePath $File.FullName

            if ($null -ne $parseErrors)
            {
                <#
                    If there are error, force throw them so we get Pesters normal handling.
                    Doing this outputs more information like line in the code.
                #>
                { throw $parseErrors } | Should -Not -Throw -Because 'there should not be any parse errors in a module script file'
            }
        }
    }
}

$PSDefaultParameterValues.Remove('Context:AllowNullOrEmptyForEach')

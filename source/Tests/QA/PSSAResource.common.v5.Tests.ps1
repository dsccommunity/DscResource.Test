<#
    .NOTES
        To run manually:

        $dscResourceModuleName = 'FileSystemDsc'
        $pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

        $container = New-PesterContainer -Path "$pathToHQRMTests/PSSAResource.common.*.Tests.ps1" -Data @{
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
$isPester5 = (Get-Module -Name Pester).Version -ge '5.1.0'

# Only run if Pester 5.1.
if (-not $isPester5)
{
    Write-Verbose -Message 'Repository is using old Pester version, new HQRM tests for Pester 5 are skipped.' -Verbose
    return
}

BeforeDiscovery {
    if ($PSVersionTable.PSVersion.Major -lt 5)
    {
        Write-Warning -Message 'PS Script Analyzer can not run on this platform. Please run tests on a machine with WMF 5.0+.'
        return
    }

    $skipCustomRules = $false

    if (-not (Get-Module -Name 'DscResource.AnalyzerRules' -ListAvailable))
    {
        Write-Warning -Message 'Required module DscResource.AnalyzerRules not found. Please add to RequiredModules.psd1. Skipping tests that uses custom PSSA rules.'

        # Skipping test must be done during discovery.
        $skipCustomRules = $true
    }

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

    # Get the required rules to build the test cases
    $PSSA_rule_config = Get-StructuredObjectFromFile -Path (Join-Path -Path (Get-CurrentModuleBase) -ChildPath 'Config/PSSA_rules_config.json')

    $requiredRuleToTest = $PSSA_rule_config.required_rules
}

BeforeAll {
    # Re-imports the private (and public) functions.
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../DscResource.Test.psm1') -Force
}

AfterAll {
    # Re-import just the public functions.
    Import-Module -Name 'DscResource.Test' -Force
}

Describe 'Common Tests - PS Script Analyzer on Resource Files' -Tag @('DscPSSA', 'Common Tests - PS Script Analyzer on Resource Files') {
    BeforeAll {
        $PSSA_rule_config = Get-StructuredObjectFromFile -Path (Join-Path -Path (Get-CurrentModuleBase) -ChildPath 'Config/PSSA_rules_config.json')

        $invokeScriptAnalyzerParameters = @{
            Path                = $dscResourcesPsm1File.FullName
            IncludeDefaultRules = $true
            IncludeRule         = @($PSSA_rule_config.required_rules + $PSSA_rule_config.flagged_rules + $PSSA_rule_config.ignore_rules)
            ErrorVariable       = 'MyErrors'
        }

        # If the module is not available then the tests was skipped in Discovery.
        if ((Get-Module -Name 'DscResource.AnalyzerRules' -ListAvailable))
        {
            $dscResourceAnalyzerRulesModule = Import-Module 'DscResource.AnalyzerRules' -PassThru -ErrorAction 'Stop'

            $invokeScriptAnalyzerParameters.CustomRulePath = Join-Path -Path $dscResourceAnalyzerRulesModule.ModuleBase -ChildPath $dscResourceAnalyzerRulesModule.RootModule
            $invokeScriptAnalyzerParameters.IncludeRule += 'Measure-*'
        }
    }

    Context 'When module file ''<DescriptiveName>'' exist' -ForEach $moduleFileToTest {
        BeforeAll {
            $invokeScriptAnalyzerParameters.Path = $File.FullName

            $PSSAErrors = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters

            $errorPssaRulesOutput = $PSSAErrors.Where{ $_.Severity -eq 'Error' }
            $requiredPssaRulesOutput = $PSSAErrors.Where{ $_.RuleName -in $PSSA_rule_config.required_rules }
            $flaggedPssaRulesOutput = $PSSAErrors.Where{ $_.RuleName -in $PSSA_rule_config.flagged_rules }
            $DSCCustomRulesOutput = $PSSAErrors.Where{ $_.RuleName -like "DscResource.AnalyzerRules*" }
            $ignoredPssaRulesOutput = $PSSAErrors.Where{ $_.RuleName -in $PSSA_rule_config.ignore_rules }
            $NewErrorRulesOutput = @($ignoredPssaRulesOutput + $flaggedPssaRulesOutput + $requiredPssaRulesOutput)

            $suppressedRuleNames = @(
                Get-SuppressedPSSARuleNameList -FilePath $File.FullName | ForEach-Object -Process {
                    # Remove any starting or trailing ' and ".
                    $newItem = $_ -replace '^["'']|["'']$', ''

                    # Only return non-empty strings.
                    if ($newItem)
                    {
                        $newItem
                    }
                }
            )
        }


        It 'Should not suppress the required rule ''<_>''' -ForEach $requiredRuleToTest -Tag @('Common Tests - Required Script Analyzer Rules', 'RequiredPSSA') {
            $_ | Should -Not -BeIn $suppressedRuleNames -Because 'no module script file should suppress a required Script Analyzer rule'
        }

        It 'Should pass all error-level PS Script Analyzer rules' -Tag @('Common Tests - Error-Level Script Analyzer Rules', 'ErrorPSSA') {
            $report = $errorPssaRulesOutput |
                Format-Table -AutoSize |
                Out-String -Width 110

            $errorPssaRulesOutput | Should -HaveCount 0 -Because "Error-level Rule(s) triggered.`r`n`r`n $report`r`n"
        }

        It 'Should pass all required PS Script Analyzer rules' -Tag @('Common Tests - Required Script Analyzer Rules', 'RequiredPSSA') {
            $report = $requiredPssaRulesOutput |
                Format-Table -AutoSize |
                Out-String -Width 110

            $requiredPssaRulesOutput | Should -HaveCount 0 -Because "Required Rule(s) triggered.`r`n`r`n $report`r`n"
        }

        It 'Should pass all flagged PS Script Analyzer rules' -Tag @('Common Tests - Flagged Script Analyzer Rules', 'FlaggedPSSA') {
            $report = $flaggedPssaRulesOutput |
                Format-Table -AutoSize |
                Out-String -Width 110

            $flaggedPssaRulesOutput | Should -HaveCount 0 -Because "Flagged Rule(s) triggered.`r`n`r`n $report`r`n"
        }

        It 'Should pass any recently-added, error-level PS Script Analyzer rules' -Tag @('Common Tests - New Error-Level Script Analyzer Rules', 'NewErrorPSSA') {
            $report = $NewErrorRulesOutput |
                Format-Table -AutoSize |
                Out-String -Width 110

            $NewErrorRulesOutput | Should -HaveCount 0 -Because "New Rules flagged `r`n`r`n $report `r`n"
        }

        It 'Should pass all custom DSC Resource Kit PSSA rules' -Skip:$skipCustomRules -Tag @('Common Tests - Custom Script Analyzer Rules', 'CustomPSSA', 'DscResource.AnalyzerRules') {
            $report = $DSCCustomRulesOutput |
                Select-Object @{
                    Name       = 'RuleName'
                    Expression = { $_.RuleName -replace 'DscResource.AnalyzerRules\\' }
                }, Severity, ScriptName, Line, Message |
                Format-Table -AutoSize -Wrap |
                Out-String -Width 110

            $DSCCustomRulesOutput | Should -HaveCount 0 -Because "Custom Error-level Rule(s) triggered.`r`n`r`n $report`r`n"
        }
    }
}

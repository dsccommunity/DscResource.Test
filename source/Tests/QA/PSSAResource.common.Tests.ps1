[Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ParameterBlockParameterAttribute', '', Scope='Function', Target='*')]
param (
    $ModuleName,
    $ModuleBase,
    $ModuleManifest,
    $ProjectPath,
    $SourcePath,
    $SourceManifest,
    $Tag,
    $ExcludeTag,
    $ExcludeModuleFile,
    $ExcludeSourceFile
)

Describe 'Common Tests - PS Script Analyzer on Resource Files' -Tag DscPSSA,'Common Tests - PS Script Analyzer on Resource Files' {

    if ($PSVersionTable.PSVersion.Major -lt 5)
    {
        Write-Warning -Message 'PS Script Analyzer can not run on this platform. Please run tests on a machine with WMF 5.0+.'
        return
    }

    <#
        PSSA = PS Script Analyzer

        The following PSSA tests will always fail if any violations are found:
        - Common Tests - Error-Level Script Analyzer Rules
        - Common Tests - Custom Script Analyzer Rules

        The following PSSA tests will only fail if a violation is found and
        a matching option is found in the opt-in file.
        - Common Tests - Required Script Analyzer Rules
        - Common Tests - Flagged Script Analyzer Rules
        - Common Tests - New Error-Level Script Analyzer Rules
        - Common Tests - Custom Script Analyzer Rules
    #>
    $RequiredPSSA = @(
        'Common Tests - Required Script Analyzer Rules',
        'RequiredPSSA'
    )
    $FlaggedPSSA = @(
        'Common Tests - Flagged Script Analyzer Rules',
        'FlaggedPSSA'
    )
    $NewErrorPSSA = @(
        'Common Tests - New Error-Level Script Analyzer Rules',
        'NewErrorPSSA'
    )
    $CustomPSSA = @(
        'Common Tests - Custom Script Analyzer Rules',
        'CustomPSSA',
        'DscResource.AnalyzerRules'
    )

    $TestTestShouldBeSkippedParams = @{
        Tag = $Tag
        ExcludeTag = $ExcludeTag
    }

    $ShouldSkipRequiredPSSA = Test-TestShouldBeSkipped @TestTestShouldBeSkippedParams -TestNames $RequiredPSSA
    $ShouldSkipFlaggedPSSA  = Test-TestShouldBeSkipped @TestTestShouldBeSkippedParams -TestNames $FlaggedPSSA
    $ShouldSkipCustomPSSA   = Test-TestShouldBeSkipped @TestTestShouldBeSkippedParams -TestNames $CustomPSSA
    $ShouldSkipNewErrorPSSA = Test-TestShouldBeSkipped @TestTestShouldBeSkippedParams -TestNames $NewErrorPSSA

    $PSSA_rule_config = Get-StructuredObjectFromFile -Path (Join-Path (Get-CurrentModuleBase) 'Config/PSSA_rules_config.json')
    $DscResourceAnalyzerRulesModule = Import-Module DscResource.AnalyzerRules -PassThru -ErrorAction Stop

    $dscResourcesPsm1Files = @(Get-ChildItem -Path $ModuleBase -Include *.psm1 -Recurse | WhereModuleFileNotExcluded)

    if ($SourcePath)
    {
        $dscResourcesPsm1Files += @(Get-ChildItem -Path $SourcePath -Include *.psm1 -Recurse | WhereSourceFileNotExcluded)
    }

    foreach ($dscResourcesPsm1File in $dscResourcesPsm1Files)
    {
        $invokeScriptAnalyzerParameters = @{
            Path        = $dscResourcesPsm1File.FullName
            CustomRulePath = (Join-Path $DscResourceAnalyzerRulesModule.ModuleBase $DscResourceAnalyzerRulesModule.RootModule)
            IncludeRule = @($PSSA_rule_config.required_rules + $PSSA_rule_config.flagged_rules + $PSSA_rule_config.ignore_rules + 'Measure-*')
            ErrorVariable = 'MyErrors'
        }

        $PSSAErrors = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters
        $errorPssaRulesOutput    = $PSSAErrors.Where{$_.Severity -eq 'Error'}
        $requiredPssaRulesOutput = $PSSAErrors.Where{$_.RuleName -in $PSSA_rule_config.required_rules }
        $flaggedPssaRulesOutput  = $PSSAErrors.Where{$_.RuleName -in $PSSA_rule_config.flagged_rules}
        $DSCCustomRulesOutput    = $PSSAErrors.Where{$_.RuleName -like "DscResource.AnalyzerRules*"}
        $ignoredPssaRulesOutput  = $PSSAErrors.Where{$_.RuleName -in $PSSA_rule_config.ignore_rules}
        $NewErrorRulesOutput = @($ignoredPssaRulesOutput + $flaggedPssaRulesOutput + $requiredPssaRulesOutput)

        Context $dscResourcesPsm1File.Name {

            It 'Should not suppress any required PS Script Analyzer rules' {
                $requiredRuleIsSuppressed = $false

                $suppressedRuleNames = Get-SuppressedPSSARuleNameList -FilePath $dscResourcesPsm1File.FullName

                foreach ($suppressedRuleName in $suppressedRuleNames)
                {
                    $suppressedRuleNameNoQuotes = $suppressedRuleName.Replace("'", '')

                    if ($requiredPssaRuleNames -icontains $suppressedRuleNameNoQuotes)
                    {
                        Write-Warning -Message "The file $($dscResourcesPsm1File.Name) contains a suppression of the required PS Script Analyser rule $suppressedRuleNameNoQuotes. Please remove the rule suppression."
                        $requiredRuleIsSuppressed = $true
                    }
                }

                $requiredRuleIsSuppressed | Should -Be $false
            }

            It 'Should pass all error-level PS Script Analyzer rules' {
                $report = $errorPssaRulesOutput | Format-Table -AutoSize | Out-String -Width 110
                $errorPssaRulesOutput | Should -HaveCount 0 -Because "Error-level Rule(s) triggered.`r`n`r`n $report`r`n"
            }

            It 'Should pass all required PS Script Analyzer rules' -Skip:($requiredPssaRulesOutput.count -gt 0 -and $ShouldSkipRequiredPSSA) {
                $report = $requiredPssaRulesOutput | Format-Table -AutoSize | Out-String -Width 110
                $requiredPssaRulesOutput | Should -HaveCount 0 -Because "Required Rule(s) triggered.`r`n`r`n $report`r`n"
            }

            It 'Should pass all flagged PS Script Analyzer rules' -Skip:($flaggedPssaRulesOutput.count -gt 0 -and $ShouldSkipFlaggedPSSA) {
                $report = $flaggedPssaRulesOutput | Format-Table -AutoSize | Out-String -Width 110
                $flaggedPssaRulesOutput | Should -HaveCount 0 -Because "Flagged Rule(s) triggered.`r`n`r`n $report`r`n"
            }

            It 'Should pass any recently-added, error-level PS Script Analyzer rules' -skip:($NewErrorRulesOutput.count -gt 0 -and $ShouldSkipNewErrorPSSA) {
                $report = $NewErrorRulesOutput | Format-Table -AutoSize | Out-String -Width 110
                $NewErrorRulesOutput | Should -HaveCount 0 -Because "New Rules flagged `r`n`r`n $report `r`n"
            }

            It 'Should pass all custom DSC Resource Kit PSSA rules' -Skip:($DSCCustomRulesOutput.count -gt 0 -and $ShouldSkipCustomPSSA) {
                $report = $DSCCustomRulesOutput | Select-Object @{
                    Name       = 'RuleName'
                    Expression = {$_.RuleName -replace 'DscResource.AnalyzerRules\\'}
                },Severity,ScriptName,Line,Message | Format-Table -AutoSize -Wrap | Out-String -Width 110
                $DSCCustomRulesOutput | Should -HaveCount 0 -Because "Error-level Rule(s) triggered.`r`n`r`n $report`r`n"
            }
        }
    }
}

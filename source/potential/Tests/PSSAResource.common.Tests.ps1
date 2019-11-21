
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

if ($PSVersionTable.PSVersion.Major -lt 5) {
    $SkipPSSA = $true
    Write-Warning -Message 'PS Script Analyzer can not run on this platform. Please run tests on a machine with WMF 5.0+.'
}
else {
    $SkipPSSA = $false
}

Describe 'Common Tests - PS Script Analyzer on Resource Files' -Tag DscPSSA -skip:$SkipPSSA {

    Import-Module PSScriptAnalyzer -ErrorAction Stop

    $requiredPssaRuleNames = @(
        'PSAvoidDefaultValueForMandatoryParameter',
        'PSAvoidDefaultValueSwitchParameter',
        'PSAvoidInvokingEmptyMembers',
        'PSAvoidNullOrEmptyHelpMessageAttribute',
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingComputerNameHardcoded',
        'PSAvoidUsingDeprecatedManifestFields',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPositionalParameters',
        'PSAvoidShouldContinueWithoutForce',
        'PSAvoidUsingWMICmdlet',
        'PSAvoidUsingWriteHost',
        'PSDSCReturnCorrectTypesForDSCFunctions',
        'PSDSCStandardDSCFunctionsInResource',
        'PSDSCUseIdenticalMandatoryParametersForDSC',
        'PSDSCUseIdenticalParametersForDSC',
        'PSMissingModuleManifestField',
        'PSPossibleIncorrectComparisonWithNull',
        'PSProvideCommentHelp',
        'PSReservedCmdletChar',
        'PSReservedParams',
        'PSUseApprovedVerbs',
        'PSUseCmdletCorrectly',
        'PSUseOutputTypeCorrectly'
    )

    $flaggedPssaRuleNames = @(
        'PSAvoidGlobalVars',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingUsernameAndPasswordParams',
        'PSDSCUseVerboseMessageInDSCResource',
        'PSShouldProcess',
        'PSUseDeclaredVarsMoreThanAssigments',
        'PSUsePSCredentialType'
    )

    $ignorePssaRuleNames = @(
        'PSDSCDscExamplesPresent',
        'PSDSCDscTestsPresent',
        'PSUseBOMForUnicodeEncodedFile',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseSingularNouns',
        'PSUseToExportFieldsInManifest',
        'PSUseUTF8EncodingForHelpFile'
    )

    $dscResourcesPsm1Files = Get-Psm1FileList -FilePath $dscResourcesFolderFilePath

    foreach ($dscResourcesPsm1File in $dscResourcesPsm1Files) {
        $invokeScriptAnalyzerParameters = @{
            Path        = $dscResourcesPsm1File.FullName
            ErrorAction = 'SilentlyContinue'
            Recurse     = $true
        }

        Context $dscResourcesPsm1File.Name {
            It 'Should pass all error-level PS Script Analyzer rules' {
                $errorPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -Severity 'Error'

                if ($null -ne $errorPssaRulesOutput) {
                    Write-PsScriptAnalyzerWarning -PssaRuleOutput $errorPssaRulesOutput -RuleType 'Error-Level'
                }

                $errorPssaRulesOutput | Should -Be $null
            }

            It 'Should pass all required PS Script Analyzer rules' {
                $requiredPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -IncludeRule $requiredPssaRuleNames

                if ($null -ne $requiredPssaRulesOutput) {
                    Write-PsScriptAnalyzerWarning -PssaRuleOutput $requiredPssaRulesOutput -RuleType 'Required'
                }

                if ($null -ne $requiredPssaRulesOutput -and (Get-OptInStatus -OptIns $optIns -Name 'Common Tests - Required Script Analyzer Rules')) {
                    <#
                        If opted into 'Common Tests - Required Script Analyzer Rules' then
                        test that there were no violations
                    #>
                    $requiredPssaRulesOutput | Should -Be $null
                }
            }

            It 'Should pass all flagged PS Script Analyzer rules' {
                $flaggedPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -IncludeRule $flaggedPssaRuleNames

                if ($null -ne $flaggedPssaRulesOutput) {
                    Write-PsScriptAnalyzerWarning -PssaRuleOutput $flaggedPssaRulesOutput -RuleType 'Flagged'
                }

                if ($null -ne $flaggedPssaRulesOutput -and (Get-OptInStatus -OptIns $optIns -Name 'Common Tests - Flagged Script Analyzer Rules')) {
                    <#
                        If opted into 'Common Tests - Flagged Script Analyzer Rules' then
                        test that there were no violations
                    #>
                    $flaggedPssaRulesOutput | Should -Be $null
                }
            }

            It 'Should pass any recently-added, error-level PS Script Analyzer rules' {
                $knownPssaRuleNames = $requiredPssaRuleNames + $flaggedPssaRuleNames + $ignorePssaRuleNames

                $newErrorPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters -ExcludeRule $knownPssaRuleNames -Severity 'Error'

                if ($null -ne $newErrorPssaRulesOutput) {
                    Write-PsScriptAnalyzerWarning -PssaRuleOutput $newErrorPssaRulesOutput -RuleType 'Recently-added'
                }

                if ($null -ne $newErrorPssaRulesOutput -and (Get-OptInStatus -OptIns $optIns -Name 'Common Tests - New Error-Level Script Analyzer Rules')) {
                    <#
                        If opted into 'Common Tests - New Error-Level Script Analyzer Rules' then
                        test that there were no violations
                    #>
                    $newErrorPssaRulesOutput | Should -Be $null
                }
            }

            It 'Should not suppress any required PS Script Analyzer rules' {
                $requiredRuleIsSuppressed = $false

                $suppressedRuleNames = Get-SuppressedPSSARuleNameList -FilePath $dscResourcesPsm1File.FullName

                foreach ($suppressedRuleName in $suppressedRuleNames) {
                    $suppressedRuleNameNoQuotes = $suppressedRuleName.Replace("'", '')

                    if ($requiredPssaRuleNames -icontains $suppressedRuleNameNoQuotes) {
                        Write-Warning -Message "The file $($dscResourcesPsm1File.Name) contains a suppression of the required PS Script Analyser rule $suppressedRuleNameNoQuotes. Please remove the rule suppression."
                        $requiredRuleIsSuppressed = $true
                    }
                }

                $requiredRuleIsSuppressed | Should -Be $false
            }

            It 'Should pass all custom DSC Resource Kit PSSA rules' {
                $customDscResourceAnalyzerRulesPath = Join-Path -Path $PSScriptRoot -ChildPath 'DscResource.AnalyzerRules'
                $customPssaRulesOutput = Invoke-ScriptAnalyzer @invokeScriptAnalyzerParameters `
                    -CustomRulePath $customDscResourceAnalyzerRulesPath `
                    -Severity 'Warning'

                if ($null -ne $customPssaRulesOutput) {
                    Write-PsScriptAnalyzerWarning -PssaRuleOutput $customPssaRulesOutput -RuleType 'Custom DSC Resource Kit'
                }

                if ($null -ne $customPssaRulesOutput -and (Get-OptInStatus -OptIns $optIns -Name 'Common Tests - Custom Script Analyzer Rules')) {
                    <#
                        If opted into 'Common Tests - Custom Script Analyzer Rules' then
                        test that there were no violations
                    #>
                    $customPssaRulesOutput | Should -Be $null
                }
            }
        }
    }
}

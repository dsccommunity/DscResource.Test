$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try
            {
                Test-ModuleManifest $_.FullName -ErrorAction Stop
            }
            catch
            {
                $false
            } )
    }).BaseName

Import-Module -Name $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Get-SystemExceptionRecord' -Tag 'GetSystemExceptionRecord' {
        Context 'When calling with the parameter Message' {
            It 'Should have the correct values in the error record' {
                $result = Get-SystemExceptionRecord -Message 'mocked error message.' -Exception 'System.Exception'

                $result | Should -BeOfType 'System.Management.Automation.ErrorRecord'
                $result.Exception | Should -BeOfType 'System.Exception'
                $result.Exception.Message | Should -Be 'System.Exception: mocked error message.'
            }
        }

        Context 'When calling with the parameters Message and ErrorRecord' {
            It 'Should have the correct values in the error record' {
                $result = $null

                try
                {
                    # Force divide by zero exception.
                    1 / 0
                }
                catch
                {
                    $result = Get-SystemExceptionRecord -Message 'mocked error message.' -Exception 'System.InvalidOperationException' -ErrorRecord $_
                }

                $result | Should -BeOfType 'System.Management.Automation.ErrorRecord'
                $result.Exception | Should -BeOfType 'System.Exception'
                $result.Exception.Message -match 'System.InvalidOperationException: mocked error message.' | Should -BeTrue
                $result.Exception.Message -match 'System.Management.Automation.RuntimeException: Attempted to divide by zero.' | Should -BeTrue
                $result.Exception.Message -match 'System.DivideByZeroException: Attempted to divide by zero.' | Should -BeTrue
            }
        }
    }
}

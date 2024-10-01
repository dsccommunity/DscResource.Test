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

Describe 'Get-InvalidArgumentRecord' -Tag 'Get-InvalidArgumentRecord' {
    Context 'When calling with the parameter Message' {
        It 'Should have the correct values in the error record' {
            $result = Get-InvalidArgumentRecord -Message 'mocked error message.' -ArgumentName 'mockArgument'

            $result | Should -BeOfType 'System.Management.Automation.ErrorRecord'
            $result.Exception | Should -BeOfType 'System.ArgumentException'
            $result.Exception.Message | Should -BeLike 'mocked error message.*'
        }
    }
}

$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'Get-StructuredObjectFromFiles' {

        Mock -CommandName Import-PowerShellDataFile
        Mock -CommandName Get-Content
        Mock -CommandName Import-Module
        Import-Module powershell-yaml -Force -ErrorAction Stop
        Mock -CommandName ConvertFrom-Yaml
        # Mock -CommandName ConvertFrom-Json fails on 6.x



        It 'Should Import a PowerShell DataFile when path extension is PSD1' {
            $null = Get-StructuredObjectFromFile -Path 'TestDrive:\tests.psd1'
            Assert-MockCalled -CommandName Import-PowerShellDataFile -Scope it
        }


        # It 'Should ConvertFrom-Json when path extension is JSON' {
        #     $null = Get-StructuredObjectFromFile -Path 'TestDrive:\tests.json'
        #     Assert-MockCalled -CommandName ConvertFrom-Json -Scope it
        # }

        It 'Should Import module & ConvertFrom-Yaml when path extension is Yaml' {
            $null = Get-StructuredObjectFromFile -Path 'TestDrive:\tests.yaml'

            Assert-MockCalled -CommandName Import-Module -Scope it
            Assert-MockCalled -CommandName ConvertFrom-Yaml -Scope It
        }


        It 'Should throw when extension not one of the above' {
            { Get-StructuredObjectFromFile -Path 'TestDrive:\tests.txt'} | Should -Throw
        }
    }
}
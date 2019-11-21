$ProjectPath = "$PSScriptRoot\..\..\.." | Convert-Path
$ProjectName = ((Get-ChildItem -Path $ProjectPath\*\*.psd1).Where{
        ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
        $(try { Test-ModuleManifest $_.FullName -ErrorAction Stop } catch { $false } )
    }).BaseName


Import-Module $ProjectName -Force

InModuleScope $ProjectName {
    Describe 'ConvertTo-OrderedDictionary' {
        It 'should convert simple PSCustomObject' {

            $InputObject = [PSCustomObject]@{
                key1 = 'value1'
                key2 = 'value2'
                key3 = 'value3'
            }

            $output = ConvertTo-OrderedDictionary -InputObject $InputObject
            $output.keys | Should -HaveCount 3
            $output | Should -BeOfType System.Collections.Specialized.IOrderedDictionary

            # Testing through pipeline
            $outputPipeline = $InputObject | ConvertTo-OrderedDictionary
            $outputPipeline.keys | Should -HaveCount 3
            $outputPipeline | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
        }

        It 'should convert nested PSCustomObject' {
            $InputObject = [PSCustomObject]@{
                key1 = 'value1'
                key2 = 'value2'
                key3 = 'value3'
                key4 = [PSCustomObject]@{
                    SubKey1 = 'subValue1'
                    SubKey2 = 'subValue2'
                    SubKey3 = 'subValue3'
                }
            }

            $output = ConvertTo-OrderedDictionary -InputObject $InputObject
            $output.keys | Should -HaveCount 4
            $output | Should -BeOfType System.Collections.Specialized.IOrderedDictionary
            $output.key4 | Should -BeOfType System.Collections.Specialized.IOrderedDictionary
            $output.key4.keys | Should -HaveCount 3

            # Testing through pipeline
            $outputPipeline = $InputObject | ConvertTo-OrderedDictionary
            $outputPipeline | Should -BeOfType System.Collections.Specialized.IOrderedDictionary
            $outputPipeline.key4 | Should -BeOfType System.Collections.Specialized.IOrderedDictionary
            $outputPipeline.key4.keys | Should -HaveCount 3

        }

        It 'Should convert Hashtable to Case Insensitive OrderedDictionary' {
            $InputObject = @{
                key1 = 'my object'
            }
            $output = ConvertTo-OrderedDictionary -InputObject $InputObject
            $output | Should -BeOfType System.Collections.Specialized.IOrderedDictionary
            { $output.Add('KEY1', 'key already exist') } | Should -Throw -Because "The key already exist in different case"

            $outputPipeline = $InputObject | ConvertTo-OrderedDictionary
            $outputPipeline | Should -BeOfType System.Collections.Specialized.IOrderedDictionary
            {$outputPipeline.Add('KEY1','key already exist')} | Should -Throw -Because "The key already exist in different case"
        }

        It 'Should return $Null when $null is passed' {
            ($null | ConvertTo-OrderedDictionary) | Should -BeNullOrEmpty
            (ConvertTo-OrderedDictionary -InputObject $null) | Should -BeNullOrEmpty
        }

        It 'Should not alter strings or Int' {
            $InputObject = @{
                Key1 = 'this is a string'
                Key2 = 2
            }

            $output = ConvertTo-OrderedDictionary -InputObject $InputObject
            $output.Key1 | Should -BeExactly $InputObject.key1
            $output.Key2 | Should -BeExactly $InputObject.key2

            $outputPipeline = $InputObject | ConvertTo-OrderedDictionary
            $outputPipeline.Key1 | Should -BeExactly $InputObject.key1
            $outputPipeline.Key2 | Should -BeExactly $InputObject.key2
        }

        It 'Should convert Arrays of nested objects' {
            $InputObject = @(
                ([PSCustomObject]@{
                    Key11 = 'Value1'
                    Key12 = @(
                        'value121', 'value122'
                    )
                }),
                (@{
                    Key21 = 'value21'
                    Key22 = @(
                        'value221', 'value222'
                    )
                }),
                (@(
                    @{ key31 = 311; key32 = @(@{ key331 = 'val331'; key332 = 'val332' })  }
                ))
            )

            $output = ConvertTo-OrderedDictionary -InputObject $InputObject
            $output | Should -HaveCount $InputObject.Count
            $output[0].Keys | Should -HaveCount $InputObject[0].PSObject.Properties.Name.Count

            $outputPipeline = $InputObject | ConvertTo-OrderedDictionary
            $outputPipeline[0].Keys | Should -HaveCount $InputObject[0].PSObject.Properties.Name.Count
            # $outputPipeline.Key2 | Should -BeExactly $InputObject.key2
        }
    }
}
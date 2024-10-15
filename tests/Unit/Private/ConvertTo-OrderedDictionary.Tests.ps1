[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param ()

BeforeDiscovery {
    try
    {
        if (-not (Get-Module -Name 'DscResource.Test'))
        {
            # Assumes dependencies has been resolved, so if this module is not available, run 'noop' task.
            if (-not (Get-Module -Name 'DscResource.Test' -ListAvailable))
            {
                # Redirect all streams to $null, except the error stream (stream 2)
                & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 2>&1 4>&1 5>&1 6>&1 > $null
            }

            # If the dependencies has not been resolved, this will throw an error.
            Import-Module -Name 'DscResource.Test' -Force -ErrorAction 'Stop'
        }
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -ResolveDependency -Tasks build" first.'
    }
}

BeforeAll {
    $script:moduleName = 'DscResource.Test'

    # Make sure there are not other modules imported that will conflict with mocks.
    Get-Module -Name $script:moduleName -All | Remove-Module -Force

    # Re-import the module using force to get any code changes between runs.
    Import-Module -Name $script:moduleName -Force -ErrorAction 'Stop'

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:moduleName
}

AfterAll {
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'ConvertTo-OrderedDictionary' -Tag 'Private' {
    It 'Should convert simple PSCustomObject' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

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
    }

    It 'Should convert nested PSCustomObject' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

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
    }

    It 'Should convert Hashtable to Case Insensitive OrderedDictionary' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            $InputObject = @{
                key1 = 'my object'
            }
            $output = ConvertTo-OrderedDictionary -InputObject $InputObject
            $output | Should -BeOfType System.Collections.Specialized.IOrderedDictionary
            { $output.Add('KEY1', 'key already exist') } | Should -Throw -Because 'The key already exist in different case'

            $outputPipeline = $InputObject | ConvertTo-OrderedDictionary
            $outputPipeline | Should -BeOfType System.Collections.Specialized.IOrderedDictionary
            { $outputPipeline.Add('KEY1', 'key already exist') } | Should -Throw -Because 'The key already exist in different case'
        }
    }

    It 'Should return $Null when $null is passed' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

            ($null | ConvertTo-OrderedDictionary) | Should -BeNullOrEmpty
            ConvertTo-OrderedDictionary -InputObject $null | Should -BeNullOrEmpty
        }
    }

    It 'Should not alter strings or Int' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

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
    }

    It 'Should convert Arrays of nested objects' {
        InModuleScope -ScriptBlock {
            Set-StrictMode -Version 1.0

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
                    @{ key31 = 311; key32 = @(@{ key331 = 'val331'; key332 = 'val332' }) }
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

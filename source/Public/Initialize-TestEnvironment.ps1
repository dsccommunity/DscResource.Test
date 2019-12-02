
<#
    .SYNOPSIS
        Initializes an environment for running unit or integration tests
        on a DSC resource.

        This includes:
        1. Updates the $env:PSModulePath to ensure the correct module is tested.
        2. Imports the module to test.
        3. Sets the PowerShell ExecutionMode to Unrestricted.
        4. returns a test environment object to store the settings.

        The above changes are reverted by calling the Restore-TestEnvironment
        function with the returned object.

        Returns a test environment object which must be passed to the
        Restore-TestEnvironment function to allow it to restore the system
        back to the original state.

    .PARAMETER Module
        The name of the DSC Module containing the resource that the tests will be
        run on.

    .PARAMETER DscResourceName
        The full name of the DSC resource that the tests will be run on. This is
        usually the name of the folder containing the actual resource MOF file.

    .PARAMETER TestType
        Specifies the type of tests that are being initialized. It can be:
        Unit: Initialize for running Unit tests on a DSC resource. Default.
        Integration: Initialize for running Integration tests on a DSC resource.

    .PARAMETER ResourceType
        Specifies if the DscResource under test is mof-based or class-based.
        The default value is 'mof'.

        It can be:
        Mof: The test initialization assumes a Mof-based DscResource folder structure.
        Class: The test initialization assumes a Class-based DscResource folder structure.

    .EXAMPLE
        $TestEnvironment = Initialize-TestEnvironment `
            -DSCModuleName 'xNetworking' `
            -DSCResourceName 'MSFT_xFirewall' `
            -TestType Unit

        This command will initialize the test environment for Unit testing
        the MSFT_xFirewall mof-based DSC resource in the xNetworking DSC module.

    .EXAMPLE
        $TestEnvironment = Initialize-TestEnvironment `
            -DSCModuleName 'SqlServerDsc' `
            -DSCResourceName 'SqlAGDatabase' `
            -TestType Unit
            -ResourceType Class

        This command will initialize the test environment for Unit testing
        the SqlAGDatabase class-based DSC resource in the SqlServer DSC module.

    .EXAMPLE
        $TestEnvironment = Initialize-TestEnvironment `
            -DSCModuleName 'xNetworking' `
            -DSCResourceName 'MSFT_xFirewall' `
            -TestType Integration

        This command will initialize the test environment for Integration testing
        the MSFT_xFirewall DSC resource in the xNetworking DSC module.
#>
function Initialize-TestEnvironment
{
    [OutputType([Hashtable])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Alias('DscModuleName')]
        [ValidateNotNullOrEmpty()]
        [String]
        $Module,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $DscResourceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Unit', 'Integration')]
        [String]
        $TestType,

        [Parameter()]
        [ValidateSet('Mof', 'Class')]
        [String]
        $ResourceType = 'Mof'
    )

    Write-Verbose -Message "Initializing test environment for $TestType testing of $DscResourceName in module $Module"
    $ModuleUnderTest = Import-Module $Module -PassThru -ErrorAction Stop
    $moduleRootFilePath = $ModuleUnderTest.ModuleBase
    $moduleManifestFilePath = Join-Path -Path $moduleRootFilePath -ChildPath "$($ModuleUnderTest.Name).psd1"

    if (Test-Path -Path $moduleManifestFilePath)
    {
        Write-Verbose -Message "Module manifest $($ModuleUnderTest.Name).psd1 detected at $moduleManifestFilePath"
    }
    else
    {
        throw "Module manifest could not be found for the module $($ModuleUnderTest.Name) in the root folder $moduleRootFilePath"
    }

    # Import the module to test
    if ($TestType -ieq 'Unit')
    {
        switch ($ResourceType)
        {
            'Mof'
            {
                $resourceTypeFolderName = 'DSCResources'
            }

            'Class'
            {
                $resourceTypeFolderName = 'DSCClassResources'
            }
        }

        $dscResourcesFolderFilePath = Join-Path -Path $moduleRootFilePath -ChildPath $resourceTypeFolderName
        $dscResourceToTestFolderFilePath = Join-Path -Path $dscResourcesFolderFilePath -ChildPath $DscResourceName

        $moduleToImportFilePath = Join-Path -Path $dscResourceToTestFolderFilePath -ChildPath "$DscResourceName.psm1"
    }
    else
    {
        $moduleToImportFilePath = $moduleManifestFilePath
    }

    Import-Module -Name $moduleToImportFilePath -Scope 'Global' -Force

    <#
        Set the PSModulePath environment variable so that the module path that includes the module
        we want to test appears first. LCM will then use this path to locate modules when
        integration tests are called. Placing the path we want first ensures the correct module
        will be tested.
    #>

    if ((Split-Path -Leaf $moduleRootFilePath) -as [version])
    {
        $moduleParentFilePath = Split-Path -Parent -Path (Split-Path -Parent -Path $moduleRootFilePath)
    }
    else
    {
        $moduleParentFilePath = Split-Path -Path $moduleRootFilePath -Parent
    }


    $oldPSModulePath = $env:PSModulePath

    if ($null -ne $oldPSModulePath)
    {
        $oldPSModulePathSplit = $oldPSModulePath.Split([io.path]::PathSeparator)
    }
    else
    {
        $oldPSModulePathSplit = $null
    }

    if ($oldPSModulePathSplit -ccontains $moduleParentFilePath)
    {
        # Remove the existing module path from the new PSModulePath
        $newPSModulePathSplit = $oldPSModulePathSplit | Where-Object { $_ -ne $moduleParentFilePath }
    }
    else
    {
        $newPSModulePath = $oldPSModulePath
    }


    $newPSModulePathSplit = @($moduleParentFilePath) + $newPSModulePathSplit
    $newPSModulePath = $newPSModulePathSplit -join [io.Path]::PathSeparator

    Set-PSModulePath -Path $newPSModulePath

    if ($TestType -ieq 'Integration')
    {
        <#
            For integration tests we have to set the machine's PSModulePath because otherwise the
            DSC LCM won't be able to find the resource module being tested or may use the wrong one.
        #>
        Set-PSModulePath -Path $newPSModulePath -Machine

        # Clear the DSC LCM & Configurations
        Clear-DscLcmConfiguration
    }

    # Preserve and set the execution policy so that the DSC MOF can be created
    $oldExecutionPolicy = Get-ExecutionPolicy
    if ($oldExecutionPolicy -ine 'Unrestricted')
    {
        Set-ExecutionPolicy -ExecutionPolicy 'Unrestricted' -Scope 'Process' -Force
    }

    # Return the test environment
    return @{
        DSCModuleName      = $Module
        Module             = $ModuleUnderTest
        DSCResourceName    = $DscResourceName
        TestType           = $TestType
        ImportedModulePath = $moduleToImportFilePath
        OldPSModulePath    = $oldPSModulePath
        OldExecutionPolicy = $oldExecutionPolicy
    }
}

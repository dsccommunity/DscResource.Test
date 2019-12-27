
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

    .PARAMETER ProcessExecutionPolicy
        Specifies the process execution policy to set before running tests.
        The default will be the one that is set in the process where the tests
        are running.

    .PARAMETER MachineExecutionPolicy
        Specifies the machine execution policy to set before running tests.
        The default will be the one that is set on the machine where the tests
        are running.

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
        $ResourceType = 'Mof',

        [Parameter()]
        [ValidateSet('AllSigned', 'Bypass','RemoteSigned','Unrestricted')]
        [String]
        $ProcessExecutionPolicy,

        [Parameter()]
        [ValidateSet('AllSigned', 'Bypass','RemoteSigned','Unrestricted')]
        [String]
        $MachineExecutionPolicy
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

    $RequiredModulesPath = Join-Path -Path $moduleParentFilePath 'RequiredModules'
    if ($newPSModulePathSplit -cnotcontains $RequiredModulesPath)
    {
        $newPSModulePathSplit = @($RequiredModulesPath) + $newPSModulePathSplit
    }

    $newPSModulePathSplit = @($moduleParentFilePath) + $newPSModulePathSplit
    $newPSModulePath = $newPSModulePathSplit -join [io.Path]::PathSeparator

    Set-PSModulePath -Path $newPSModulePath

    if ($TestType -ieq 'Integration')
    {
        # # Making sure setting up the LCM & Machine Path makes sense...
        if (($IsWindows -or $PSEdition -eq 'Desktop') -and
            ($Principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())) -and
            $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        )
        {
            if (!$script:MachineOldPSModulePath)
            {
                Write-Warning "This will change your Machine Environment Variable"
                $script:MachineOldPSModulePath = [System.Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')
            }

            # Preserve and set the execution policy so that the DSC MOF can be created
            $currentMachineExecutionPolicy = Get-ExecutionPolicy -Scope 'LocalMachine'
            if ($PSBoundParameters.ContainsKey('MachineExecutionPolicy'))
            {
                if ($currentMachineExecutionPolicy -ne $MachineExecutionPolicy)
                {
                    Set-ExecutionPolicy -ExecutionPolicy $MachineExecutionPolicy -Scope 'LocalMachine' -Force -ErrorAction Stop

                    <#
                        Should only be set after we actually changed the execution
                        policy because if $script:MachineOldExecutionPolicy is set
                        to a value `Restore-TestEnvironment` will try to revert
                        the value.
                    #>
                    $script:MachineOldExecutionPolicy = $currentMachineExecutionPolicy

                    $currentMachineExecutionPolicy = $MachineExecutionPolicy
                }
            }

            Write-Verbose -Message ('The machine execution policy is set to ''{0}''' -f $currentMachineExecutionPolicy)

            <#
                For integration tests we have to set the machine's PSModulePath because otherwise the
                DSC LCM won't be able to find the resource module being tested or may use the wrong one.
            #>
            Set-PSModulePath -Path $newPSModulePath -Machine

            # Clear the DSC LCM & Configurations
            Clear-DscLcmConfiguration
            # Setup the Self signed Certificate for Integration tests & get the LCM ready
            $null = New-DscSelfSignedCertificate
            Initialize-DscTestLcm -DisableConsistency -Encrypt
        }
        else
        {
            Write-Warning "Setting up the DSC Integration Test Environment (LCM & Certificate) only works on Windows PS5+ as Admin"
        }
    }

    <#
        Preserve and set the execution policy so that the DSC MOF can be created.

        `Restore-TestEnvironment` will only revert the value if $oldExecutionPolicy
        differ from current execution policy. So we make to always set it to the
        current execution policy so that if we don't need to change it then
        `Restore-TestEnvironment` will not try to revert the value.
    #>
    $oldExecutionPolicy = Get-ExecutionPolicy -Scope 'Process'
    if ($PSBoundParameters.ContainsKey('ProcessExecutionPolicy'))
    {
        if ($oldExecutionPolicy -ne $ProcessExecutionPolicy)
        {
            Set-ExecutionPolicy -ExecutionPolicy $ProcessExecutionPolicy -Scope 'Process' -Force -ErrorAction Stop
        }
    }

    Write-Verbose -Message ('The process execution policy is set to ''{0}''' -f $oldExecutionPolicy)


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

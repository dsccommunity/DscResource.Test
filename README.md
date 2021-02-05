# DscResource.Test

[![Build Status](https://dev.azure.com/dsccommunity/DscResource.Test/_apis/build/status/dsccommunity.DscResource.Test?branchName=master)](https://dev.azure.com/dsccommunity/DscResource.Test/_build/latest?definitionId=3&branchName=master)
![Code Coverage](https://img.shields.io/azure-devops/coverage/dsccommunity/DscResource.Test/3/master)
[![Azure DevOps tests](https://img.shields.io/azure-devops/tests/dsccommunity/DscResource.Test/3/master)](https://dsccommunity.visualstudio.com/DscResource.Test/_test/analytics?definitionId=3&contextType=build)
[![PowerShell Gallery (with prereleases)](https://img.shields.io/powershellgallery/vpre/DscResource.Test?label=DscResource.Test%20Preview)](https://www.powershellgallery.com/packages/DscResource.Test/)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/DscResource.Test?label=DscResource.Test)](https://www.powershellgallery.com/packages/DscResource.Test/)

This is a PowerShell module designed to help testing your projects against HQRM guidelines.

You can run the tests against the source of your project or against a built module.  
The format expected for your project follows [the Sampler](https://github.com/gaelcolas/Sampler)
template (basically the source code in a source/src/ModuleName folder, and
a built version in the output folder).

## Usage

Although this module is best used as part of the Sampler template pipeline
automation, you can also use this in a standalone or custom way.

Install the module from the PowerShell Gallery:

```PowerShell
Install-Module DscResource.test
```

Execute against a Built module:

```PowerShell
Invoke-DscResourceTest -Module UpdateServicesDsc
```

## Dependencies

This module depends on:

- **Pester**: This is a collection of generic Pester tests to run against your built
module or source code.
- **PSScriptAnalyzer**: Some tests are just validating you comply with some of the
guidances set in PSSA rules and with custom rules.
- **DscResource.AnalyzerRules**: This is the custom rules we've created to enforce
a standard across the DscResource module we look after as a community.
- **xDscResourceDesigner**: Because it offers MOF and DSC Resource testing capabilities.

### Contributing

The [Contributing guidelines can be found here](CONTRIBUTING.md).

This project has continuous testing running on Windows, MacOS, Linux, with both
Windows PowerShell 5.1 and the PowerShell version available on the Azure DevOps
agents.

Quick Start:

```PowerShell
PS C:\src\> git clone git@github.com:dsccommunity/DscResource.Test.git
PS C:\src\> cd DscResource.Test
PS C:\src\DscResource.Test> build.ps1 -ResolveDependency
# this will first bootstrap the environment by downloading dependencies required
# then run the '.' task workflow as defined in build.yml
```

## Cmdlets
<!-- markdownlint-disable MD036 - Emphasis used instead of a heading -->

Refer to the comment-based help for more information about these helper
functions.

### `Clear-DscLcmConfiguration`

Clear the DSC LCM by performing the following functions:

1. Cancel any currently executing DSC LCM operations
1. Remove any DSC configurations that:
    - are currently applied
    - are pending application
    - have been previously applied

The purpose of this function is to ensure the DSC LCM is in a known
and idle state before an integration test is performed that will
apply a configuration.

This is to prevent an integration test from being performed but failing
because the DSC LCM is applying a previous configuration.

This function should be called after each Describe block in an integration
test to ensure the DSC LCM is reset before another test DSC configuration
is applied.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
Clear-DscLcmConfiguration [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

#### Outputs

None.

#### Example

```powershell
Clear-DscLcmConfiguration
```

This command will Stop the DSC LCM and clear out any DSC configurations.

### `Get-InvalidOperationRecord`

Returns an invalid operation exception object.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
Get-InvalidOperationRecord [-Message] <string> [[-ErrorRecord] <ErrorRecord>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

#### Outputs

**System.Object**

#### Example

```powershell
$mockErrorRecord = Get-InvalidOperationRecord -Message (
    $script:localizedData.FailedToRename -f $name
)
```

This will return an error record with the localized string as the exception
message.

```powershell
try
{
    # Something that tries an operation.
}
catch
{
    $mockErrorRecord = Get-InvalidOperationRecord -ErrorRecord $_ -Message (
        $script:localizedData.FailedToRename -f $name
    )
}
```

This will return an error record. The exception message will be concatenated
to include both the localized string and all the inner exceptions messages
from error record that was passed from the `catch`-block.

### `Get-InvalidResultRecord`

Returns an invalid result exception object.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
Get-InvalidResultRecord [-Message] <string> [[-ErrorRecord] <ErrorRecord>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

#### Aliases

`Get-ObjectNotFound`

#### Outputs

**System.Object**

#### Example

```powershell
$mockErrorRecord = Get-InvalidResultRecord -Message (
    $script:localizedData.FailedToGetAllFromName -f $name
)
```

This will return an error record with the localized string as the exception
message.

```powershell
try
{
    # Something that tries to return an expected result.
}
catch
{
    $mockErrorRecord = Get-InvalidResultRecord -ErrorRecord $_ -Message (
        $script:localizedData.FailedToGetAllFromName -f $name
    )
}
```

This will return an error record. The exception message will be concatenated
to include both the localized string and all the inner exceptions messages
from error record that was passed from the `catch`-block.

### `Initialize-TestEnvironment`

Initializes an environment for running unit or integration tests
on a DSC resource.

This includes:

1. Updates the $env:PSModulePath to ensure the correct module is tested.
1. Imports the module to test.
1. Sets the PowerShell ExecutionMode to Unrestricted.
1. returns a test environment object to store the settings.

The above changes are reverted by calling the Restore-TestEnvironment
function with the returned object.

Returns a test environment object which must be passed to the
Restore-TestEnvironment function to allow it to restore the system
back to the original state.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
Initialize-TestEnvironment [-Module] <string> [-DscResourceName] <string> 
  [-TestType] {Unit | Integration | All} [[-ResourceType] {Mof | Class}]
  [[-ProcessExecutionPolicy] {AllSigned | Bypass | RemoteSigned | Unrestricted}] 
  [[-MachineExecutionPolicy] {AllSigned | Bypass | RemoteSigned | Unrestricted}] 
  [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

#### Outputs

**System.Collections.Hashtable**

#### Example

```powershell
$script:testEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'NetworkingDsc' `
    -DSCResourceName 'DSC_Firewall' `
    -ResourceType 'Mof' `
    -TestType 'Unit'
```

This command will initialize the test environment for Unit testing
the DSC_Firewall MOF-based DSC resource in the NetworkingDsc DSC resource
module.

```powershell
$script:testEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'NetworkingDsc' `
    -DSCResourceName 'DSC_Firewall' `
    -ResourceType 'Class' `
    -TestType 'Unit'
```

This command will initialize the test environment for Unit testing
the DSC_Firewall Class-based DSC resource in the NetworkingDsc DSC resource'
module.

```powershell
$script:testEnvironment = Initialize-TestEnvironment `
    -DSCModuleName 'NetworkingDsc' `
    -DSCResourceName 'DSC_Firewall' `
    -ResourceType 'Class' `
    -TestType 'Integration'
```

This command will initialize the test environment for Integration testing
the DSC_Firewall DSC resource in the NetworkingDsc DSC resource module.

### `Invoke-DscResourceTest`

Wrapper for Invoke-Pester. It is used primarily by the pipeline and can
be used to run test by providing a project path, module specification,
by module name, or path.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
Invoke-DscResourceTest [[-ProjectPath] <string>] [[-Path] <Object[]>] [[-TestName] <string[]>]
  [[-EnableExit]] [[-TagFilter] <string[]>] [-ExcludeTagFilter <string[]>] [-ExcludeModuleFile <string[]>]
  [-ExcludeSourceFile <string[]>] [-PassThru] [-CodeCoverage <Object[]>] [-CodeCoverageOutputFile <string>]
  [-CodeCoverageOutputFileFormat {JaCoCo}] [-Strict] [-Output <string>] [-OutputFile <string>] 
  [-OutputFormat {NUnitXml | JUnitXml}] [-Quiet] [-PesterOption <Object>]
  [-Show {None | Default | Passed | Failed | Pending | Skipped | Inconclusive | Describe | Context | Summary | Header | Fails | All}]
  [-Settings <hashtable>] [-MainGitBranch <string>] [<CommonParameters>]

Invoke-DscResourceTest [[-Module] <string>] [[-Path] <Object[]>] [[-TestName] <string[]>] 
  [[-EnableExit]] [[-TagFilter] <string[]>] [-ExcludeTagFilter <string[]>] [-ExcludeModuleFile <string[]>]
  [-ExcludeSourceFile <string[]>] [-PassThru] [-CodeCoverage <Object[]>] [-CodeCoverageOutputFile <string>]
  [-CodeCoverageOutputFileFormat {JaCoCo}] [-Strict] [-Output <string>] [-OutputFile <string>]
  [-OutputFormat {NUnitXml | JUnitXml}] [-Quiet] [-PesterOption <Object>]
  [-Show {None | Default | Passed | Failed | Pending | Skipped | Inconclusive | Describe | Context | Summary | Header | Fails | All}]
  [-Settings <hashtable>] [-MainGitBranch <string>] [<CommonParameters>]

Invoke-DscResourceTest [[-FullyQualifiedModule] <ModuleSpecification>] [[-Path] <Object[]>]
  [[-TestName] <string[]>] [[-EnableExit]] [[-TagFilter] <string[]>] [-ExcludeTagFilter <string[]>]
  [-ExcludeModuleFile <string[]>] [-ExcludeSourceFile <string[]>] [-PassThru] [-CodeCoverage <Object[]>]
  [-CodeCoverageOutputFile <string>] [-CodeCoverageOutputFileFormat {JaCoCo}] [-Strict] [-Output <string>]
  [-OutputFile <string>] [-OutputFormat {NUnitXml | JUnitXml}] [-Quiet] [-PesterOption <Object>]
  [-Show {None | Default | Passed | Failed | Pending | Skipped | Inconclusive | Describe | Context | Summary | Header | Fails | All}]
  [-Settings <hashtable>] [-MainGitBranch <string>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

#### Outputs

**System.Object**

#### Example

None.

### `New-DscSelfSignedCertificate`

This command will create a new self-signed certificate to be used to
compile configurations.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
New-DscSelfSignedCertificate [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

#### Outputs

Returns the created certificate. Writes the path to the public
certificate in the machine environment variable $env:DscPublicCertificatePath,
and the certificate thumbprint in the machine environment variable
$env:DscCertificateThumbprint.

#### Example

```powershell
$certificate = New-DscSelfSignedCertificate
```

This command will create and return a new self-signed certificate to be
used to compile configurations. The command will write the path to the
public certificate in the machine environment variable `$env:DscPublicCertificatePath`,
and the certificate thumbprint in the machine environment variable
`$env:DscCertificateThumbprint`.

If a certificate with subject 'DscEncryptionCert' already exists, that
certificate will be returned instead of creating a new. The command will
assume that the existing certificate was created with the same command.

### `Restore-TestEnvironment`

Restores the environment after running unit or integration tests
on a DSC resource.

This restores the following changes made by calling
Initialize-TestEnvironment:

1. Restores the $env:PSModulePath if it was changed.
1. Restores the PowerShell execution policy.
1. Resets the DSC LCM if running Integration tests.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
Restore-TestEnvironment [-TestEnvironment] <hashtable> [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

#### Outputs

None.

#### Example

```powershell
Restore-TestEnvironment -TestEnvironment $script:testEnvironment
```

This will restore the test environment and use the values that is provided
in the hashtable passed to the command. The hasttable that is passed should
have been created by `Initialize-TestEnvironment`.

### `Wait-ForIdleLcm`

Waits for LCM to become idle and optionally clears the LCM by running
`Clear-DscLcmConfiguration`.

It is meant to be used in integration test where integration tests run to
quickly before LCM have time to cool down.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
Wait-ForIdleLcm [-Clear] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

#### Outputs

None.

#### Example

```powershell
Wait-ForIdleLcm -Clear
```

This will wait for the LCM to become idle and then clear the LCM.

# DscResource.Test

This module contains tasks and the HQRM (High Quality Resource Module) tests for the PowerShell DSC Community's DSC resources. This is a PowerShell module designed to help testing your projects against HQRM guidelines.

[![Build Status](https://dev.azure.com/dsccommunity/DscResource.Test/_apis/build/status/dsccommunity.DscResource.Test?branchName=main)](https://dev.azure.com/dsccommunity/DscResource.Test/_build/latest?definitionId=3&branchName=main)
![Azure DevOps coverage (branch)](https://img.shields.io/azure-devops/coverage/dsccommunity/DscResource.Test/3/main)
[![codecov](https://codecov.io/gh/dsccommunity/DscResource.Test/branch/main/graph/badge.svg)](https://codecov.io/gh/dsccommunity/DscResource.Test)
[![Azure DevOps tests](https://img.shields.io/azure-devops/tests/dsccommunity/DscResource.Test/3/main)](https://dsccommunity.visualstudio.com/DscResource.Test/_test/analytics?definitionId=3&contextType=build)
[![PowerShell Gallery (with prereleases)](https://img.shields.io/powershellgallery/vpre/DscResource.Test?label=DscResource.Test%20Preview)](https://www.powershellgallery.com/packages/DscResource.Test/)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/DscResource.Test?label=DscResource.Test)](https://www.powershellgallery.com/packages/DscResource.Test/)

## Code of Conduct

This project has adopted this [Code of Conduct](CODE_OF_CONDUCT.md).

## Releases

For each merge to the branch `main` a preview release will be
deployed to [PowerShell Gallery](https://www.powershellgallery.com/).
Periodically a release version tag will be pushed which will deploy a
full release to [PowerShell Gallery](https://www.powershellgallery.com/).

## Contributing

Please check out common DSC Community [contributing guidelines](https://dsccommunity.org/guidelines/contributing).

## Change log

A full list of changes in each version can be found in the [change log](CHANGELOG.md).

## Usage

Although this module is best used as part of the Sampler template pipeline
automation, you can also use this in a standalone or custom way.

You can run the tests against the source of your project or against a built module.  
The format expected for your project follows [the Sampler](https://github.com/gaelcolas/Sampler)
template (basically the source code in a source/src/ModuleName folder, and
a built version in the output folder).

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

### `Get-DscResourceTestContainer`

This command will return a container for each available HQRM test script.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
Get-DscResourceTestContainer [-ProjectPath] <string> [-ModuleName] <string> 
  [-DefaultBranch] <string> [-SourcePath] <string> [[-ExcludeSourceFile] <string[]>] 
  [-ModuleBase] <string> [[-ExcludeModuleFile] <string[]>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

#### Outputs

**Pester.ContainerInfo[]**

#### Example

```powershell
$getDscResourceTestContainersParameters = @{
    ProjectPath       = '.'
    ModuleName        = 'MyDscResourceName'
    DefaultBranch     = 'main'
    SourcePath        = './source'
    ExcludeSourceFile = @('Examples')
    ModuleBase        = "./output/MyDscResourceName/*"
    ExcludeModuleFile = @('Modules/DscResource.Common')
}

$container = Get-DscResourceTestContainer @getDscResourceTestContainersParameters

Invoke-Pester -Container $container -Output Detailed
```

Returns a container for each available HQRM test script using the provided
values as script parameters. Then Pester is invoked on the containers.

### `Get-InvalidArgumentRecord`

Returns an invalid argument exception object.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
Get-InvalidArgumentRecord [-Message] <string> [-ArgumentName] <string> [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

#### Outputs

**System.Object**

#### Example

```powershell
$errorRecord = Get-InvalidArgumentRecord `
    -Message ($script:localizedData.InterfaceNotAvailableError -f $interfaceAlias) `
    -ArgumentName 'Interface'
```

This will return an error record with the localized string as the exception
message.

### `Get-InvalidResultRecord`

Returns an invalid result exception object.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
Get-InvalidResultRecord [-Message] <string> [[-ErrorRecord] <ErrorRecord>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

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

### `Get-InvalidResultRecord`

Returns an invalid result exception object.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
Get-InvalidResultRecord [-Message] <string> [[-ErrorRecord] <ErrorRecord>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

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

### `Get-ObjectNotFoundRecord`

Returns an invalid result exception object.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
Get-ObjectNotFoundRecord [-Message] <string> [[-ErrorRecord] <ErrorRecord>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

#### Outputs

**System.Object**

#### Example

```powershell
$mockErrorRecord = Get-ObjectNotFoundRecord -Message (
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
    $mockErrorRecord = Get-ObjectNotFoundRecord -ErrorRecord $_ -Message (
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

This cmdlet behaves differently between Pester 4 and Pester 5. For Pester 5
the cmdlet has been made so that it can run on any module by providing
the correct paths. When only Pester 4 is available it is limited to the
pattern of the [Sampler](https://github.com/gaelcolas/Sampler) project.

#### Using Pester 4

Wrapper for Invoke-Pester. It is used primarily by the pipeline and can
be used to run test by providing a project path, module specification,
by module name, or path.

#### Pester 5

Wrapper for Invoke-Pester's Simple parameter set. It can be used to run
all the HQRM test with a single command. Only the parameter set `Pester5`
is supported, the first parameter set in the section _Syntax_ below.
Mandatory parameters are those necessary to run the test scripts.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
Invoke-DscResourceTest -ProjectPath <string> -MainGitBranch <string> 
  -ModuleName <string> -SourcePath <string> -ModuleBase <string> 
  [-TagFilter <string[]>] [-ExcludeTagFilter <string[]>] 
  [-ExcludeModuleFile <string[]>] [-ExcludeSourceFile <string[]>] 
  [-PassThru] [-Output <string>] [<CommonParameters>]

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

```powershell
$invokeDscResourceTestParameters = @{
    # Test script parameters
    ProjectPath       = '.'
    ModuleName        = 'SqlServerDsc'
    MainGitBranch     = 'main'
    SourcePath        = './source'
    ModuleBase        = "./output/SqlServerDsc/*"
}

Invoke-DscResourceTest @invokeDscResourceTestParameters
```

This passes all mandatory parameters to `Invoke-DscResourceTest` which
run all the HQRM tests. This will only output minimal information, by using
the default value for `Invoke-Pester`'s `Output` parameter.

```powershell
$invokeDscResourceTestParameters = @{
    # Test script parameters
    ProjectPath       = '.'
    ModuleName        = 'SqlServerDsc'
    MainGitBranch     = 'main'
    SourcePath        = './source'
    ExcludeSourceFile = @('Examples')
    ModuleBase        = "./output/SqlServerDsc/*"
    ExcludeModuleFile = @('Modules/DscResource.Common')

    # Invoke-Pester parameters
    Output            = 'Detailed'
    ExcludeTagFilter  = 'Common Tests - New Error-Level Script Analyzer Rules'
    PassThru          = $true
}

$testResult = Invoke-DscResourceTest @invokeDscResourceTestParameters
```

This run all the HQRM tests except the tests tagged with
`'Common Tests - New Error-Level Script Analyzer Rules'` and also outputs
details of every tests as it runs.

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

It will return if the LCM state is other than 'Busy'. The other states are
'Idle', 'PendingConfiguration', or 'PendingReboot'.

#### Syntax

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
Wait-ForIdleLcm [[-Timeout] <timespan>] [-Clear] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

#### Outputs

None.

#### Example

```powershell
Wait-ForIdleLcm -Clear
```

This will wait for the LCM to return from busy state and then clear the LCM.

```powershell
Wait-ForIdleLcm -Clear -Timeout '00:00:08'
```

This will wait for the LCM to return from busy state. If the LCM has not
returned from busy state within the elapsed time specified in the parameter
`Timeout` then it will stop waiting and clear the LCM.

## Tasks

These are `Invoke-Build` tasks. The build tasks are primarily meant to be
run by the project [Sampler's](https://github.com/gaelcolas/Sampler)
`build.ps1` which wraps `Invoke-Build` and has the configuration file
(`build.yaml`) to control its behavior.

To make the tasks available for the cmdlet `Invoke-Build` in a repository
that is based on the [Sampler](https://github.com/gaelcolas/Sampler) project,
add this module to the file `RequiredModules.psd1` and then in the file
`build.yaml` add the following:

```yaml
ModuleBuildTasks:
  DscResource.Test:
    - 'Task.*'
```

### `Invoke_HQRM_Tests`

This build task runs the High Quality Resource Module (HQRM) tests located
in the folder `Tests/QA` in the module _DscResource.Test_'s root. This build
task is normally not used on its own. It is meant to run through the meta task
[`Invoke_HQRM_Tests_Stop_On_Fail`](#invoke-hqrm-tests-stop-on-fail).

Below is an example how the build task can be used when a repository is
based on the [Sampler](https://github.com/gaelcolas/Sampler) project.

```yaml
BuildWorkflow:
  '.':
    - build

  hqrmtest:
    - Invoke_HQRM_Tests
```

The build configuration (build.yaml) can be used to control the behavior
of the build task. Everything under the key `DscTest:` controls the behavior.
There are two sections `Pester` and `Script`.

#### Section Pester

The section Pester control the behavior of `Invoke-Pester` that is run
through the build task. There are two different ways of configuring this,
they can be combined but it is limited to the parameter sets of `Invoke-Pester`,
see the command syntax in the [`Invoke-Pester` documentation](https://pester.dev/docs/commands/Invoke-Pester).

##### Passing parameters to Pester

Any parameter that `Invoke-Pester` takes is valid to use as key in the
build configuration. The exception is `Container`, it is handled by the
build task to pass parameters to the scripts correctly (see [Section Script](#section-script)).
Also the parameter `Path` can only point to test files that do not need
any script parameters passed to them to run.

>**NOTE:** A key that does not have a value will be ignored.

```yaml
DscTest:
  Pester:
    Path:
    ExcludePath:
    TagFilter:
    FullNameFilter:
    ExcludeTagFilter:
      - Common Tests - New Error-Level Script Analyzer Rules
    Output: Detailed
```

Important to note that if the key `Configuration` is present it limits
what other parameters that can be passed to `Invoke-Pester` due to the
parameter set that is then used. But the key `Configuration` gives more
control over the behavior of `Invoke-Pester`. For more information what 
can be configured see the [sections of the `[PesterConfiguration]` object](https://pester.dev/docs/commands/Invoke-Pester#-configuration).

Under the key `Configuration` any section name in the `[PesterConfiguration]`
object is valid to use as key. Any new sections or properties that will be
added in future version of Pester will also be valid (as long as they follow
the same pattern).

```plaintext
PS > [PesterConfiguration]::Default
Run          : Run configuration.
Filter       : Filter configuration
CodeCoverage : CodeCoverage configuration.
TestResult   : TestResult configuration.
Should       : Should configuration.
Debug        : Debug configuration for Pester. ⚠ Use at your own risk!
Output       : Output configuration
```

This shows how to use the advanced configuration option to exclude tags
and change the output verbosity. The keys `Filter:` and `Output:` are the
section names from the list above, and the keys `ExcludeTag` and `Verbosity`
are properties in the respective section in the `[PesterConfiguration]`
object.

>**NOTE:** A key that does not have a value will be ignored.

```yaml
DscTest:
  Pester:
    Configuration:
      Filter:
        Tag:
        ExcludeTag:
          - Common Tests - New Error-Level Script Analyzer Rules
      Output:
        Verbosity: Detailed
```

#### Section Script

##### Passing parameters to test scripts

The key `Script:` is used to define values to pass to parameters in the
test scripts. Each key defined under the key `Script:` is a parameter that
can be used in one or more test script.

See the section [Tests](#tests) for the parameters that can be defined here
to control the behavior of the tests.

>**NOTE:** The test scripts only used the parameters that is required and
>ignore any other that is defined. If there are tests added that need a
>different parameter name, that name can be defined under the key `Script:`
>and will be passed to the test that require it without any change to the
>build task.

This defines three parameters `ExcludeSourceFile`, `ExcludeModuleFile`,
and `MainGitBranch` and their corresponding values.

```yaml
DscTest:
  Script:
    ExcludeSourceFile:
      - output
      - source/DSCResources/DSC_ObsoleteResource1
      - DSC_ObsoleteResource2
    ExcludeModuleFile:
      - Modules/DscResource.Common
    MainGitBranch: main
```

### `Fail_Build_If_HQRM_Tests_Failed`

This build task evaluates that there was no failed tests when the task
`Invoke_HQRM_Tests` ran. This build task is normally not used on its own.
It is meant to run through the meta task [`Invoke_HQRM_Tests_Stop_On_Fail`](#invoke_hqrm_tests_stop_on_fail).

Below is an example how the build task can be used when a repository is
based on the [Sampler](https://github.com/gaelcolas/Sampler) project.

```yaml
BuildWorkflow:
  '.':
    - build

  hqrmtest:
    - Invoke_HQRM_Tests
    - Fail_Build_If_HQRM_Tests_Failed
```

### `Invoke_HQRM_Tests_Stop_On_Fail`

This is a meta task meant to be used in the build configuration to run
tests in the correct order to fail the test pipeline if there are any
failed test.

The order this meta task is running tasks:

- Invoke_HQRM_Tests
- Fail_Build_If_HQRM_Tests_Failed

Below is an example how the build task can be used when a repository is
based on the [Sampler](https://github.com/gaelcolas/Sampler) project.

```yaml
BuildWorkflow:
  '.':
    - build

  hqrmtest:
    - Invoke_HQRM_Tests_Stop_On_Fail
```


## Tests

This is the documentation for the Pester 5 tests. 

### Changelog.common

#### Parameters

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
[-ProjectPath] <String> [-MainGitBranch] <String> [[-Args] <Object>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

##### MainGitBranch

The name of the default branch of the Git upstream repository.

##### ProjectPath

The path to the root of the project, for example the root of the local
Git repository.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

```powershell
$defaultBranch = 'main'
$pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

$container = New-PesterContainer -Path "$pathToHQRMTests/Changelog.common.*.Tests.ps1" -Data @{
    ProjectPath = '.'
    MainGitBranch = $defaultBranch
}

Invoke-Pester -Container $container -Output Detailed
```

### ExampleFiles.common

#### Parameters

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
[-SourcePath] <String> [[-ExcludeSourceFile] <String[]>] [[-Args] <Object>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

##### ExcludeSourceFile

Any path or part of a path that will be excluded from the list of files
gathered by the test. Default no files will be excluded from the test.

##### SourcePath

The path to the source folder of the project, e.g. `./source`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

#### Example

```powershell
$pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

$container = New-PesterContainer -Path "$pathToHQRMTests/ExampleFiles.common.*.Tests.ps1" -Data @{
    SourcePath = './source'
    # ExcludeSourceFile = @('MyExample.ps1')
}

Invoke-Pester -Container $container -Output Detailed
```

### FileFormatting.common

#### Parameters

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
 [-ProjectPath] <String> [-ModuleBase] <String> [[-SourcePath] <String>] 
   [[-ExcludeModuleFile] <String[]>] [[-ExcludeSourceFile] <String[]>] 
   [[-Args] <Object>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

##### ExcludeModuleFile

Any path or part of a path that will be excluded from the list of files
gathered by the test from the path specified in the parameter `ModuleBase`.
Default no files will be excluded from the test.

##### ExcludeSourceFile

Any path or part of a path that will be excluded from the list of files
gathered by the test from the path specified in the parameter `SourcePath`.
Default no files will be excluded from the test.

##### ModuleBase

The path to the root of built module, e.g. `./output/FileSystemDsc/1.2.0`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

##### ProjectPath

The path to the root of the project, for example the root of the local
Git repository.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

##### SourcePath

The path to the source folder of the project, e.g. `./source`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

```powershell
$dscResourceModuleName = 'FileSystemDsc'
$pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

$container = New-PesterContainer -Path "$pathToHQRMTests/FileFormatting.common.*.Tests.ps1" -Data @{
    ProjectPath = '.'
    ModuleBase = "./output/$dscResourceModuleName/*"
    # SourcePath = './source'
    # ExcludeModuleFile = @('Modules/DscResource.Common')
    # ExcludeSourceFile = @('Examples')
}

Invoke-Pester -Container $container -Output Detailed
```

### Localization.common

#### Parameters

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
  [-ModuleBase] <String> [[-ExcludeModuleFile] <String[]>]  [[-ProjectPath] <String[]>]
  [[-Args] <Object>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

##### ExcludeModuleFile

Any path or part of a path that will be excluded from the list of files
gathered by the test from the path specified in the parameter `ModuleBase`.
Default no files will be excluded from the test.

##### ModuleBase

The path to the root of built module, e.g. `./output/FileSystemDsc/1.2.0`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

##### ProjectPath

The path to the root of the project, for example the root of the local
Git repository.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

#### Example

```powershell
$dscResourceModuleName = 'FileSystemDsc'
$pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

$container = New-PesterContainer -Path "$pathToHQRMTests/Localization.common.*.Tests.ps1" -Data @{
    ModuleBase = "./output/$dscResourceModuleName/*"
    # ExcludeModuleFile = @('Modules/DscResource.Common')
    # ProjectPath = '.'
}

Invoke-Pester -Container $container -Output Detailed
```

### Localization.builtModule

#### Parameters

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
  [-ModuleBase] <String> [[-ProjectPath] <String[]>]
  [[-Args] <Object>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

##### ModuleBase

The path to the root of built module, e.g. `./output/FileSystemDsc/1.2.0`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

##### ProjectPath

The path to the root of the project, for example the root of the local
Git repository.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

#### Example

```powershell
$dscResourceModuleName = 'FileSystemDsc'
$pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

$container = New-PesterContainer -Path "$pathToHQRMTests/Localization.builtModule.*.Tests.ps1" -Data @{
    ModuleBase = "./output/$dscResourceModuleName/*"
    # ProjectPath = '.'
}

Invoke-Pester -Container $container -Output Detailed
```

### MarkdownLinks.common

#### Parameters

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
[-ProjectPath] <String> [-ModuleBase] <String> [[-SourcePath] <String>] 
  [[-ExcludeSourceFile] <String[]>] [[-Args] <Object>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

##### ExcludeSourceFile

Any path or part of a path that will be excluded from the list of files
gathered by the test from the path specified in the parameter `SourcePath`.
Default no files will be excluded from the test.

##### ModuleBase

The path to the root of built module, e.g. `./output/FileSystemDsc/1.2.0`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

##### ProjectPath

The path to the root of the project, for example the root of the local
Git repository.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

##### SourcePath

The path to the source folder of the project, e.g. `./source`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

```powershell
$dscResourceModuleName = 'FileSystemDsc'
$pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

$container = New-PesterContainer -Path "$pathToHQRMTests/MarkdownLinks.common.*.Tests.ps1" -Data @{
    $ProjectPath = '.'
    ModuleBase = "./output/$dscResourceModuleName/*"
    # SourcePath = './source'
    # ExcludeSourceFile = @('Examples')
}

Invoke-Pester -Container $container -Output Detailed
```

### ModuleManifest.common

#### Parameters

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
[-ModuleName] <String> [-ModuleBase] <String> [[-Args] <Object>]
  [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

##### ModuleBase

The path to the root of built module, e.g. `./output/FileSystemDsc/1.2.0`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

##### ModuleName

The name of the module that is built, e.g. `FileSystemDsc`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

#### Example

```powershell
$dscResourceModuleName = 'JeaDsc'
$pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

$container = New-PesterContainer -Path "$pathToHQRMTests/ModuleManifest.common.*.Tests.ps1" -Data @{
    ModuleName = $dscResourceModuleName
    ModuleBase = "./output/$dscResourceModuleName/*"
}

Invoke-Pester -Container $container -Output Detailed
```

### ModuleScriptFiles.common

#### Parameters

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
[-ProjectPath] <String> [-ModuleBase] <String> [[-SourcePath] <String>]
  [[-ExcludeModuleFile] <String[]>] [[-ExcludeSourceFile] <String[]>] 
  [[-Args] <Object>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

##### ExcludeModuleFile

Any path or part of a path that will be excluded from the list of files
gathered by the test from the path specified in the parameter `ModuleBase`.
Default no files will be excluded from the test.

##### ExcludeSourceFile

Any path or part of a path that will be excluded from the list of files
gathered by the test from the path specified in the parameter `SourcePath`.
Default no files will be excluded from the test.

##### ModuleBase

The path to the root of built module, e.g. `./output/FileSystemDsc/1.2.0`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

##### ProjectPath

The path to the root of the project, for example the root of the local
Git repository.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

##### SourcePath

The path to the source folder of the project, e.g. `./source`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

#### Example

```powershell
$dscResourceModuleName = 'FileSystemDsc'
$pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

$container = New-PesterContainer -Path "$pathToHQRMTests/ModuleScriptFiles.common.*.Tests.ps1" -Data @{
    ProjectPath = '.'
    ModuleBase = "./output/$dscResourceModuleName/*"
    # SourcePath = './source'
    # ExcludeModuleFile = @('Modules/DscResource.Common')
    # ExcludeSourceFile = @('Examples')
}

Invoke-Pester -Container $container -Output Detailed
```

### PSSAResource.common

#### Parameters

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
[-ProjectPath] <String> [-ModuleBase] <String> [[-SourcePath] <String>]
  [[-ExcludeSourceFile] <String[]>] [[-Args] <Object>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

##### ExcludeSourceFile

Any path or part of a path that will be excluded from the list of files
gathered by the test from the path specified in the parameter `SourcePath`.
Default no files will be excluded from the test.

##### ModuleBase

The path to the root of built module, e.g. `./output/FileSystemDsc/1.2.0`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

##### ProjectPath

The path to the root of the project, for example the root of the local
Git repository.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

##### SourcePath

The path to the source folder of the project, e.g. `./source`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

```powershell
$dscResourceModuleName = 'FileSystemDsc'
$pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

$container = New-PesterContainer -Path "$pathToHQRMTests/PSSAResource.common.*.Tests.ps1" -Data @{
    ProjectPath = '.'
    ModuleBase = "./output/$dscResourceModuleName/*"
    # SourcePath = './source'
    # ExcludeSourceFile = @('Examples')
}

Invoke-Pester -Container $container -Output Detailed
```

### PublishExampleFiles.common

#### Parameters

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
[-SourcePath] <String> [[-ExcludeSourceFile] <String[]>] [[-Args] <Object>] 
  [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

##### ExcludeSourceFile

Any path or part of a path that will be excluded from the list of files
gathered by the test from the path specified in the parameter `SourcePath`.
Default no files will be excluded from the test.

##### SourcePath

The path to the source folder of the project, e.g. `./source`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

#### Example

```powershell
$pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

$container = New-PesterContainer -Path "$pathToHQRMTests/PublishExampleFiles.common.*.Tests.ps1" -Data @{
    SourcePath = './source'
    # ExcludeSourceFile = @('MyExample.ps1')
}

Invoke-Pester -Container $container -Output Detailed
```

### RelativePathLength.common

#### Parameters

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
[-ModuleBase] <String> [[-Args] <Object>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

##### ModuleBase

The path to the root of built module, e.g. `./output/FileSystemDsc/1.2.0`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

```powershell
$dscResourceModuleName = 'FileSystemDsc'
$pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

$container = New-PesterContainer -Path "$pathToHQRMTests/RelativePathLength.common.*.Tests.ps1" -Data @{
    ModuleBase = "./output/$dscResourceModuleName/*"
}

Invoke-Pester -Container $container -Output Detailed
```

### ResourceSchema.common

#### Parameters

<!-- markdownlint-disable MD013 - Line length -->
```plaintext
[-ModuleBase] <String> [[-Args] <Object>] [<CommonParameters>]
```
<!-- markdownlint-enable MD013 - Line length -->

##### ModuleBase

The path to the root of built module, e.g. `./output/FileSystemDsc/1.2.0`.

If using the build task the default value for this parameter will be set
to the value that comes from the pipeline.

```powershell
$dscResourceModuleName = 'FileSystemDsc'
$pathToHQRMTests = Join-Path -Path (Get-Module DscResource.Test).ModuleBase -ChildPath 'Tests\QA'

$container = New-PesterContainer -Path "$pathToHQRMTests/ResourceSchema.common.*.Tests.ps1" -Data @{
    ModuleBase = "./output/$dscResourceModuleName/*"
}

Invoke-Pester -Container $container -Output Detailed
```

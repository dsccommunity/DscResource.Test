# Changelog for DscResource.Test

All notable changes to this project will be documented in this file.

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.16.3] - 2024-08-29

### Added

- `Get-SystemExceptionRecord`
  - Added private command fixes ([Issue [#126](https://github.com/dsccommunity/DscResource.Test/issues/126)]).
- Public command `Get-ObjectNotFoundRecord`
  - Use private function `Get-SystemExceptionRecord`.

### Changed

- `Get-InvalidOperationRecord`
  - Use private function `Get-SystemExceptionRecord`.
- `Get-InvalidResultRecord`
  - Removed alias `Get-ObjectNotFoundRecord` and added as it's own public command.
- `PSSAResource.common.v4.Tests`
  - Fixed rule suppression by using correct variable.

### Fixed

- `azure-pipelines`
  - Pin gitversion to V5.

## [0.16.2] - 2023-05-18

### Added

- `Restore-TestEnvironment`
  - A new parameter `KeepNewMachinePSModulePath` was added and only works
    if the test type is `Integration` or `All`. The new parameter will
    keep any new paths that was added to the machine environment variable
    `PSModulePath` after the command `Initialize-TestEnvironment` was called.
    This is helpful if a a path is added by an integration test and is needed
    by a second integration test and there is a need to run `Restore-TestEnvironment`
    between tests.
- Added private function `Join-PSModulePath` that will concatenate two
  strings with semi-colon separated paths.

### Fixed

- `Initialize-TestEnvironment`
  - Now `$script:machineOldPSModulePath` is always set when called with the
    test type `Integration` or `All`. Before it reverted to the paths on the
    event `OnRemove` that were the current paths when `Initialize-TestEnvironment`
    was first called. On subsequent calls any new paths were ignored.
  - If there are a subsequent call to `Initialize-TestEnvironment` without the
    command `Restore-TestEnvironment` was called prior the command will now
    fail with a non-terminating exception asking the user to run `Restore-TestEnvironment`
    to avoid the previously saved paths (`$script:machineOldPSModulePath`)
    to be overwritten.

## [0.16.1] - 2022-04-20

### Changed

- Updated pipeline to use the latest build and pipeline files from Sampler.

### Fixed

- Now the pipeline will fail if the Pester discovery phase fails. Prior
  if discovery failed the pipeline still passed ([issue #112](https://github.com/dsccommunity/DscResource.Test/issues/112)).

## [0.16.0] - 2021-09-11

### Added

- Added support for examples for LCM Meta Configurations to
  `Test-ConfigurationName` ([issue #116](https://github.com/dsccommunity/DscResource.Test/issues/116)).

## [0.15.2] - 2021-09-08

### Changed

- Refactoring all tasks to initialise variable with `Set-SamplerTaskVariable` script ([issue #110](https://github.com/dsccommunity/DscResource.Test/issues/110)).
- Now the data for the Pester containers are cloned to not hit the issue
  [Using same data with two or more containers fail](https://github.com/pester/Pester/issues/2073).

## [0.15.1] - 2021-03-29

### Added

- `Wait-ForIdleLcm`
  - Added new parameter `Timeout` to be able to return after the specified
    elapsed time ([issue #101](https://github.com/dsccommunity/DscResource.Test/issues/101)).

### Changed

- DscResource.Test
  - Rename the default branch to `main` ([issue #104](https://github.com/dsccommunity/DscResource.Test/issues/104)).
  - Updated pipeline files, using the latest Sampler deploy tasks.
- `Wait-ForIdleLcm`
  - Updated to wait as long as the `LCMState` property has the state `'Busy'` ([issue #101](https://github.com/dsccommunity/DscResource.Test/issues/101)).
    This will prevent the pipeline to loop indefinitely when an integration
    test fails and the property `LCMState` is set to `PendingConfiguration`.

### Fixed

- `Invoke_HQRM_Tests`
  - Fixed the task so it runs together with latest PowerShell module Sampler.
- `Fail_Build_If_HQRM_Tests_Failed`
  - Fixed the task so it runs together with latest PowerShell module Sampler.

## [0.15.0] - 2021-02-09

### Added

- Added test helper functions `Get-InvalidResultRecord` and `Get-InvalidOperationRecord`.
- Added alias `Get-ObjectNotFoundRecord` that points to `Get-InvalidResultRecord`.
- Added build task `Invoke_HQRM_Tests` and `Fail_Build_If_HQRM_Tests_Failed`.
- Added meta build task `Invoke_HQRM_Tests_Stop_On_Fail` that runs both
  build tasks `Invoke_HQRM_Tests` and `Fail_Build_If_HQRM_Tests_Failed`
  in correct order.
- New QA (HQRM) tests for Pester 5 was added that will only run if Pester 5.1
  is used by the test pipeline.
- Added (converted) HQRM test for Pester 5
  - Added `Changelog.common.v5.Tests.ps1`
  - Added `ExampleFiles.common.v5.Tests.ps1`
  - Added `FileFormatting.common.v5.Tests.ps1`
    - The individual test for checking BOM on markdown files was remove
      and replaced by a test that checks for BOM on all text files (code,
      configuration, and markdown). That also replaced the Pester 4 tests
      `ModuleFiles.common.v4.Tests.ps1` (that only checked for BOM on
      `.psm1`files), and `ScriptFiles.common.v4.Tests.ps1` (that only
      checked for BOM on `.ps1` files). No changes were made to the
      Pester 4 tests, just the Pester 5 tests.
  - Added `MarkdownLinks.common.v5.Tests.ps1`
  - Added `ModuleManifest.common.v5.Tests.ps1`
  - Added `ModuleScriptFiles.common.v5.Tests.ps1`
    - Contain the converted Pester 4 tests from `Psm1Parsing.common.v4.Tests.ps1`.
  - Added `PSSAResource.common.v5.Tests.ps1`
    - Any test that is excluded by using Pester `ExcludeTag` under the key
      `DscTest:` will now be silently excluded due to how Pester does _Discovery_.
  - Added `PublishExampleFiles.v5.Tests.ps1`
  - Added `ResourceSchema.common.v5.Tests.ps1`
- Added public function `Get-DscResourceTestContainer` which returns a Pester
  container for each available Pester 5 HQRM test.

### Changed

- Renamed all existing QA (HQRM) tests to `*.v4.Tests.ps1*` and made
  them not run if test pipeline is using Pester 5.
- The function `Get-TextFilesList` can now take an optional parameter
  `FileExtension` to only return those files, e.g. `@('.psm1')`. This
  makes the function `Get-Psm1FileList` obsolete.
- `Get-DscResourceTestContainer`
  - Changed to support the new Pester 5 HQRM tests, and code for an older
    Pester 5 Beta iteration was removed.
- Added a `build.yaml` task script `Add_Aliases_To_Module_Manifest` that
  update module manifest with a list of aliases that is configured in
  the `build.yaml` file under the key `AliasesToExport:`. This is quick
  fix for the issue [Export alias create with Set-Alias and New-Alias](https://github.com/PoshCode/ModuleBuilder/issues/103).

### Fixed

- Fix issue with running pester 4 HQRM test after preview release `v0.15.0-preview0002`.

## [0.14.3] - 2021-01-13

### Fixed

- Fix issue where the use of ScriptsToProcess causes the Initialize-TestEnvironment
  function to fail ([issue #97](https://github.com/dsccommunity/DscResource.Test/issues/97)).

## [0.14.2] - 2021-01-05

### Fixed

- Now the path separators are handled correctly in the filter functions
  `WhereModuleFileNotExcluded` and `WhereSourceFileNotExcluded`.
- Updated cmdlet documentation in README.md.

## [0.14.1] - 2020-11-12

### Fixed

- Fix Remove Test Manifest has Class based resource in nested modules - Fixes #85

### Changed

- Fix deploy condition in `azure-pipelines.yml` so that it does not execute
  unless run from the `dsccommunity` Azure DevOps org ([issue #86](https://github.com/dsccommunity/DscResource.Test/issues/86)).

## [0.14.0] - 2020-08-08

### Fixed

- Fixed error in `Tests/QA/Changelog.common.Tests.ps1` when Describing Changelog
  Management ([issue #81](https://github.com/dsccommunity/DscResource.Test/issues/81)).

### Added

- Added support for passing alternate trunk branch name through to
  `Invoke-DscResourceTest.Tests.ps1` function ([issue #82](https://github.com/dsccommunity/DscResource.Test/issues/82)).

## [0.13.3] - 2020-06-01

### Fixed

- Added logic to support Pester 4.

## [0.13.2] - 2020-05-30

### Fixed

- Update build.yaml to support latest ModuleBuilder.
- Pinned required module Pester to 4.10.1.
- Update CONTRIBUTING.md.

### Changes

- The cmdlet Invoke-DscResourceTest support running test in Pester 5.

## [0.13.1] - 2020-05-15

### Fixed

- Fixed #71. Updated `Invoke-DscResourceTest` to handle multiple PSModuleInfo objects

## [0.13.0] - 2020-03-28

### Added

- Added a test to check for the correct formatting of the Unreleased section
  in the Changelog.

### Changed

- Updated the Azure DevOps Pipeline build agents to the supported versions
  because the older `win1803` and `vs2015-win2012r2` versions have been
  deprecated ([issue #68](https://github.com/dsccommunity/DscResource.Test/issues/68)).

### Fixed

- Fixed #66. Tests in 'ModuleManifest.common.Tests.ps1' in context 'Requirements for manifest of module with class-based resources' always fail.

## [0.12.1] - 2020-01-16

### Fixed

- Update the cmdlet `Initialize-TestEnvironment` to allow setting up
  the environment when run in PowerShell 5.0.
- Update the pipeline so the module will be tested on PowerShell 5.0
  (Microsoft-hosted agent running Windows Server 2012 R2).

## [0.12.0] - 2020-01-16

### Changed

- Required PowerShell version was lowered to v5.0 in the module manifest.
- Azure Pipelines will no longer trigger on changes to just the CHANGELOG.md.

## [0.11.1] - 2020-01-06

### Changed

- Moved init code into Describe Block for PSSAResource and ResourceSchema Tests

### Fixed

- Updated QA tests to follow style guideline.

## [0.11.0] - 2019-12-29

### Added

- Added new QA ExampleFiles test.
- Added new QA MarkdownLinks test.
- Added check on changelog when invoking by project path.

## [0.10.0] - 2019-12-28

### Added

- Added a new test type, `All`, to the `Initialize-TestEnvironment` function
  that initializes the DSC LCM and imports the module for testing ([issue #48](https://github.com/dsccommunity/DscResource.Test/issues/48)).

## [0.9.0] - 2019-12-27

### Added

- Added an integration test to regression test integration tests failing
  with `Security Error` ([issue #38](https://github.com/dsccommunity/DscResource.Test/issues/38)).

### Changed

- The `Initialize-TestEnvironment` now takes two new parameters that sets
  the execution policy for machine and process. If these are not set then
  the execution policy will not be changed.
- Updated `build.ps1` to the latest in the template.
- Added LICENSE (fixes [Issue #41](https://github.com/dsccommunity/DscResource.Test/issues/41)).
- Added standard badges to README.MD (fixes [Issue #43](https://github.com/dsccommunity/DscResource.Test/issues/43)).

### Fixed

- Fixing the Relative path to make sure it calculates from it's ModuleBase.
- Used the right code of conduct for DSC Community.
- Fixed integration tests failing with the error `Security Error`
  ([issue #38](https://github.com/dsccommunity/DscResource.Test/issues/38)).

### Changed

- Changed module manifest to include Tags, ProjectUri, LicenseUri, Logo
  and changed AliasesToExport to empty (fixes [Issue #42](https://github.com/dsccommunity/DscResource.Test/issues/42)).
- Changed Clear-DscLcmConfiguration to a public function so it can be called
  directly by resource modules (fixes [Issue #40](https://github.com/dsccommunity/DscResource.Test/issues/40)).

### Removed

- Removed Deploy.PSDeploy.ps1 because it is not used (fixes [Issue #44](https://github.com/dsccommunity/DscResource.Test/issues/44)).
- Removed commented out code from DscResource.Test.psm1
  file (fixes [Issue #45](https://github.com/dsccommunity/DscResource.Test/issues/45)).

## [0.8.0] - 2019-12-21

### Added

- Added new QA Localization test, supporting excludes.
- Added new QA PublishExampleFiles test.

### Fixed

- Invoking the tests by ProjectPath (as well as per module).
- Fixed the Get-ChildItem -Depth 3 on Windows PS (needed -Name or it does not work).

### Changed

- Re-added the check for Initialize-TestEnvironment to check if session elevated & OS.

## [0.7.0] - 2019-12-19

### Added

- Added new QA Localization test.

## [0.5.3] - 2019-12-16

### Fixed

- Temporarily remove Admin-check in `Initialize-TestEnvironment`.
- Suppress output from function `Initialize-DscTestLcm`.

## [0.5.1] - 2019-12-13

### Fixed

- Correctly detect Windows PowerShell in `Initialize-TestEnvironment`.

## [0.5.0] - 2019-12-12

### Fixed

- Now skipping isAdmin on non-windows (because creds works differently)
- Moving spellcheck out of the tests
- Updating ScriptFiles tests to get different module base when from module or from project path

## [0.4.0] - 2019-12-04

### Added

- Allow most test to optionally target Source files (under Project/SourceFolder)
- Enable excluding file by path relative to either ModuleBase (when specifying a module) or Source Path

## [0.3.0] - 2019-12-02

### Added

- Added Public functions Initialize-TestEnvironment, New-DscSelfSignedCertificate, Restore-TestEnvironment
- Added Private functions Set-EnvironmentVariable, Set-PSModulePath, Clear-DscLcmConfiguration
- Added PSPKI as ExternalModuleDependencies when creating self signed certs on older OSes

## [0.2.0] - 2019-11-27

### Added

- Created module from DscResource.Tests repository.
- Function Invoke-DscResourceTest is proxy to Invoke-Pester, with Sugar coating for
the built-in tests.
- Added Secret Variables for releases and using DSC Bot account

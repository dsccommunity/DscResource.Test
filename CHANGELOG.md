# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Moved init code into Describe Block for PSSAResource and ResourceSchema Tests

## [0.11.0] - 2019-12-29

### Added

- Added new QA ExampleFiles test.
- Added new QA MarkdownLinks test.

## [0.10.0] - 2019-12-28

### Added

- Added a new test type, `All`, to the `Initialize-TestEnvironment` function
  that initializes the DSC LCM and imports the module for testing ([issue #48](https://github.com/dsccommunity/DscResource.Test/issues/48)).
- Added check on changelog when invoking by project path.

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

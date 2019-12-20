# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added new QA MarkdownLinks test.
- Added new QA Localization test

### Fixed

- Invoking the tests by ProjectPath (as well as per module).

### Changed

- Re-added the check for Initialize-TestEnvironment to check if session elevated & OS.

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

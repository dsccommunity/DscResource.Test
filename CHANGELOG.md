# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.1] - 2019-12-04
## [Unreleased]

### Fixed

- Now skipping isAdmin on non-windows (because creds works differently)

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

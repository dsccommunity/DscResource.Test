# DscResource.Test

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

@{
    # Set up a mini virtual environment...
    PSDependOptions             = @{
        AddToPath  = $True
        Target     = 'output\RequiredModules'
        Parameters = @{
        }
    }

    invokeBuild                 = 'latest'
    PSScriptAnalyzer            = 'latest'
    'DscResource.AnalyzerRules' = 'latest'
    pester                      = 'latest'
    Plaster                     = 'latest'
    ModuleBuilder               = 'latest'
    ChangelogManagement         = 'latest'
    Sampler                     = 'latest'
    xDscResourceDesigner        = 'latest'
    MarkdownLinkCheck           = 'latest'
}

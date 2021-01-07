
<#
    .SYNOPSIS
        Retrieves all text files under the given root file path.

    .PARAMETER Root
        The root file path under which to retrieve all text files.

    .NOTES
        Retrieves all files with the '.gitignore', '.gitattributes', '.ps1', '.psm1', '.psd1',
        '.json', '.xml', '.cmd', or '.mof' file extensions.
#>
function Get-TextFilesList
{
    [OutputType([System.IO.FileInfo[]])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Root,

        [Parameter()]
        [String[]]
        $FileExtension = @('.gitignore', '.gitattributes', '.ps1', '.psm1', '.psd1', '.json', '.xml', '.cmd', '.mof', '.md', '.js', '.yml')
    )

    return Get-ChildItem -Path $Root -Recurse | Where-Object -FilterScript { $FileExtension -contains $_.Extension }
}

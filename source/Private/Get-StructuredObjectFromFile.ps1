function Get-StructuredObjectFromFile
{
    [cmdletBinding()]
    param
    (
        [Parameter()]
        [String]
        $Path
    )

    $ioPath = [System.IO.FileInfo]($PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path))
    switch -regex ($ioPath.Extension)
    {
        '^\.psd1$'
        {
            $ObjectFromFile = Import-PowerShellDataFile -Path $ioPath -ErrorAction Stop
        }

        '^\.y[a]?ml$'
        {
            Import-Module Powershell-yaml -ErrorAction Stop
            $FileContent = Get-Content -Raw -Path $ioPath -ErrorAction Stop
            $ObjectFromFile = ConvertFrom-Yaml -Ordered -Yaml $FileContent -ErrorAction Stop
        }

        '^\.json$'
        {
            $FileContent = Get-Content -Raw -Path $ioPath -ErrorAction Stop
            $ObjectFromFile = ConvertFrom-Json -InputObject $FileContent -ErrorAction Stop
        }

        Default
        {
            throw "File extension $($ioPath.Extension) not recognized."
        }
    }

    return $ObjectFromFile
}

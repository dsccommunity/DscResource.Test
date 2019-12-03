filter WhereModuleFileNotExcluded
{
    foreach ($ExclPath in $ExcludeModuleFile)
    {
        if ((($filename = $_.FullName) -or ($fileName = $_)) -and $filename -Match ([regex]::Escape($ExclPath)))
        {
            Write-Debug "Skipping $($_.FullName) because it matches $ExclPath"
            return
        }
    }
    $_
}

filter WhereSourceFileNotExcluded
{
    foreach ($excludePath in $ExcludeSourceFile)
    {
        # Replace any path separator to the one used in the current operating system.
        $excludePath = $excludePath -replace '\/', [IO.Path]::DirectorySeparatorChar
        $excludePath = $excludePath -replace '\\', [IO.Path]::DirectorySeparatorChar

        if ((($filename = $_.FullName) -or ($fileName = $_)) -and $filename -Match ([regex]::Escape($excludePath)))
        {
            Write-Debug "Skipping $($_.FullName) because it matches $excludePath"
            return
        }
    }
    $_
}

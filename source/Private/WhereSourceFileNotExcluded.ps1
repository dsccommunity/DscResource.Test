filter WhereSourceFileNotExcluded
{
    param
    (
        # This will set the $ExcludeSourceFile from the parent scope if it exist
        $ExcludeSourceFile = $ExcludeSourceFile
    )

    foreach ($excludePath in $ExcludeSourceFile)
    {
        # Replace any path separator to the one used in the current operating system.
        $excludePath = $excludePath -replace '\/', [IO.Path]::DirectorySeparatorChar
        $excludePath = $excludePath -replace '\\', [IO.Path]::DirectorySeparatorChar

        if ((($excludePath -eq $_.FullName) -or ($excludePath -eq $_.Name)) -and $excludePath -match ([regex]::Escape($excludePath)))
        {
            Write-Debug "Skipping $($_.FullName) because it matches $excludePath"

            return
        }
    }

    $_
}

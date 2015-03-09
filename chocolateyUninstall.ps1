try {
    $dir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $path = Join-Path $dir 'tools\CType.msi'
    if (Test-Path $path)
    {
        Write-Debug "found $path"
    }
    else
    {
        Write-Debug "did not find $path"
    }
    Write-Debug "CType\chocolateyUninstall.ps1 running Uninstall-ChocolateyPackage -PackageName CType -FileType MSI -SilentArgs /Quiet -File $path"
    Uninstall-ChocolateyPackage -PackageName CType -FileType MSI -SilentArgs '/Quiet' -File $path
    Write-Debug "CType\chocolateyInstall.ps1 ran MSI uninstaller"
    $expectedPath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\CType"
    if (Test-Path $expectedPath)
    {
        Write-ChocolateyFailure 'CType' "MSI succeeded but $expectedPath is still present"
    }
    else
    {
        Write-ChocolateySuccess 'CType'
    }
} catch {
    Write-ChocolateyFailure 'CType' $_.Exception.Message
    throw 
}

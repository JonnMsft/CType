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
    Write-Debug "CType\chocolateyInstall.ps1 running Install-ChocolateyPackage -PackageName CType -FileType MSI -SilentArgs /Quiet -Url $path"
    Install-ChocolateyPackage -PackageName CType -FileType MSI -SilentArgs '/Quiet' -Url $path
    Write-Debug "CType\chocolateyInstall.ps1 ran MSI installer"
    $expectedPath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\CType"
    if (Test-Path $expectedPath)
    {
        Write-ChocolateySuccess 'CType'
    }
    else
    {
        Write-ChocolateyFailure 'CType' "MSI succeeded but $expectedPath not found"
    }
} catch {
    Write-ChocolateyFailure 'CType' $_.Exception.Message
    throw 
}

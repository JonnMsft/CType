$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$path = Join-Path $dir 'tools\CType.msi'
if (Test-Path $path)
{
    Write-Debug "CType\chocolateyUninstall.ps1: found $path"
}
    else
{
    Write-Debug "CType\chocolateyUninstall.ps1: did not find $path"
}

$env:chocolateyInstallOverride = "true"
$env:chocolateyInstallArguments = "$path /quiet"
Write-Debug "The current version of Chocolatey appears to contain a bug in Uninstall-ChocolateyPackage,"
Write-Debug "where the -File parameter value is ignored when -FileType is MSI."
Write-Debug "I bypass this by setting"
Write-Debug '$env:chocolateyInstallOverride = "true"'
Write-Debug '$env:chocolateyInstallArguments = "$path /quiet"'
Write-Debug "CType\chocolateyUninstall.ps1: running Uninstall-ChocolateyPackage -PackageName CType -FileType MSI -SilentArgs -File $path"
Uninstall-ChocolateyPackage -PackageName CType -FileType MSI -SilentArgs '/Quiet' -File $path
Write-Debug "CType\chocolateyInstall.ps1 ran MSI uninstaller"

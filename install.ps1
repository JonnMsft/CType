[CmdletBinding()]
param([string]$InstallDirectory)

$fileList = @(
    'CType.ps1',
    'CType.psm1',
    'CType.psd1',
    'en-US/about_CType.help.txt'
)

if ('' -eq $InstallDirectory)
{
    $personalModules = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath WindowsPowerShell\Modules
    if (($env:PSModulePath -split ';') -notcontains $personalModules)
    {
        Write-Warning "$($MyInvocation.InvocationName): $personalModules is not in `$env:PSModulePath"
    }

    if (!(Test-Path $personalModules))
    {
        Write-Error "$($MyInvocation.InvocationName): $personalModules does not exist"
    }

    $InstallDirectory = Join-Path -Path $personalModules -ChildPath CType
}

if (!(Test-Path $InstallDirectory))
{
    Write-Verbose "$($MyInvocation.InvocationName): creating $InstallDirectory"
    $null = New-Item $InstallDirectory -ItemType Directory
    $null = New-Item (Join-Path $InstallDirectory en-US) -ItemType Directory
}

$wc = New-Object System.Net.WebClient
$fileList | ForEach-Object {
    $source = "https://raw.github.com/JonnMsft/CType/master/$_"
    $dest = Join-Path $installDirectory $_
    Write-Progress -Activity $MyInvocation.InvocationName -Status $_
    Write-Verbose "$($MyInvocation.InvocationName): downloading $source TO $dest"
    $wc.DownloadFile($source, $dest)
}



Remove-Item tools\CType.msi -ErrorAction SilentlyContinue
Remove-Item tools\CType\CType.ps1 -ErrorAction SilentlyContinue
Remove-Item tools\CType\CType.psm1 -ErrorAction SilentlyContinue
Remove-Item tools\CType\CType.psd1 -ErrorAction SilentlyContinue
Remove-Item tools\CType\en-US\about_CType.help.txt -ErrorAction SilentlyContinue
Remove-Item tools\CType\en-US -ErrorAction SilentlyContinue
Remove-Item tools\CType -ErrorAction SilentlyContinue
Remove-Item tools -ErrorAction SilentlyContinue
$null = New-Item tools -ItemType Directory -ErrorAction Stop
$null = New-Item tools\CType -ItemType Directory -ErrorAction Stop
$null = New-Item tools\CType\en-US -ItemType Directory -ErrorAction Stop
Copy-Item .\CType_InstallShield\Express\SingleImage\DiskImages\DISK1\CType.msi tools
Copy-Item ..\..\Scripts\CType\CType.ps1 tools\CType
Copy-Item ..\..\Scripts\CType\CType.psm1 tools\CType
Copy-Item ..\..\Scripts\CType\CType.psd1 tools\CType
Copy-Item ..\..\Scripts\CType\en-US\about_CType.help.txt tools\CType\en-US
cmd /c C:\ProgramData\chocolatey\bin\cpack.exe
Remove-Item tools\CType.msi -ErrorAction SilentlyContinue
Remove-Item tools\CType\CType.ps1 -ErrorAction SilentlyContinue
Remove-Item tools\CType\CType.psm1 -ErrorAction SilentlyContinue
Remove-Item tools\CType\CType.psd1 -ErrorAction SilentlyContinue
Remove-Item tools\CType\en-US\about_CType.help.txt -ErrorAction SilentlyContinue
Remove-Item tools\CType\en-US -ErrorAction SilentlyContinue
Remove-Item tools\CType -ErrorAction SilentlyContinue
Remove-Item tools -ErrorAction SilentlyContinue

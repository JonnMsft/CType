# vstfpg06\Consol_06_TPC5 $/Nebula/Source/Ops Tools/current/Scripts/CType/CType.psm1

# Remember the current directory
$Script:ScriptDir = Split-Path $MyInvocation.MyCommand.Path

. $Script:ScriptDir\CType.ps1

Export-ModuleMember -Function '*-CType*',CType,property,sqlproperty,parent,use,ref,SqlWrapper,SqlTemplateObject,NoFormatData

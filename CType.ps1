
# CODEWORK Need better parameter validation

[Hashtable]$CType_AddedTypes = @{}

Write-Verbose 'CType.ps1: adding CType base types'
Add-Type -ReferencedAssemblies System.Data -TypeDefinition @'
namespace CType
{
    public class TypeElement
    {
    }
    public class Property : TypeElement
    {
        public string PropertyName;
        public string PropertyType;
        public string PropertyTableWidth;
        public string[] PropertyKeywords;
    }
    public class Parent : TypeElement
    {
        public string ParentTypeName;
    }
    public class Using : TypeElement
    {
        public string Namespace;
    }
    public class ReferencedAssembly : TypeElement
    {
        public string AssemblyName;
    }
    public class SqlWrapper : TypeElement
    {
    }
    public class SqlTemplateObject : TypeElement
    {
        public System.Data.DataRow DataRow;
    }
    public class NoFormatData : TypeElement
    {
    }
}
'@

function Add-CType
{
<#
.SYNOPSIS
Add a locally-defined type to this runspace.

.DESCRIPTION
Add a locally-defined type to this runspace, and optionally define table formatting for the type.
These types can be used as parameter types and in OutputType([typename]) declarations.

.PARAMETER TypeName
Name for the new type. You can include the namespace here or else specify it separately.

.PARAMETER Namespace
Namespace containing the new type. If not specified, the namespace is extracted from TypeName.

.PARAMETER ParentTypeName
Parent class of the new class, default is System.Object

.PARAMETER Using
Other namespaces, typically those containing types specified in PropertyType

.PARAMETER ReferencedAssemblies
Other assemblies, typically those containing types specified in PropertyType

.PARAMETER SqlWrapper
Make the new type a SQL wrapper class for use in ConvertTo-CTypeSqlWrapper.
This is set automatically if any PropertyKeyword contains SQLWrapper,
or if SQLTemplateObject is set.

.PARAMETER SqlTemplateObject
If specified, include all properties of this SQL template object in the SQL wrapper class.
Properties already specified in PropertyName are not affected.
SqlWrapper is automatically set if this is specified.

.PARAMETER NoFormatData
Skip defining formatting metadata for this type.
For example, you might want to combine all the formatting for the types in your module
into a single file.

.PARAMETER PropertyName
Name of a property of the type being defined

.PARAMETER PropertyType
Type of a property of the type being defined

.PARAMETER PropertyTableWidth
Table width in characters of a property of the type being defined.
If one or more properties specify PropertyTableWidth, a formatting directive
will be generated for this type and entered into the runspace.
If not specified, this property is not in the default table format.
This can also be set to '*', in which case this property is displayed at full width;
this should generally only be used for the last property with defined PropertyTableWidth.

.PARAMETER PropertyKeywords
Other keywords. The only keywords currently implemented are "Trim"
which trims leading/trailing whitespace from the output string in the table formatting,
and "SQLWrapper" which designates a read-only property read from the wrapped SQL object.

.EXAMPLE
# Define a new type
PS> @"
PropertyName,PropertyType,PropertyTableWidth,PropertyKeywords
PrimaryTarget,string,25,Trim
SecondaryTarget,string,25,Trim
Weight,int,10
IsPrimary,Boolean,10
Description,String,*
MainConnection,SqlConnection
SecondaryConnection,SqlConnection
"@ | ConvertFrom-Csv | Add-CType -TypeName MyType `
                                 -Namespace MyCompany.Namespace `
                                 -Using System.Data.SqlClient `
                                 -ReferencedAssemblies System.Data

# You can now use this as a full-fledged type, for example define parameters as
# param( [MyCompany.Namespace.MyType]$MyParameter )

# Create an instance of the type
PS> New-Object -TypeName MyCompany.Namespace.MyType -Property @{
    PrimaryTarget = "String1";
    SecondaryTarget = "String2";
    Weight = 4;
    Description = "This is a very long description"
    }

PrimaryTarget             SecondaryTarget           Weight     IsPrimary  Description                                                                                                                
-------------             ---------------           ------     ---------  -----------                                                                                                                
String1                   String2                   4          False      This is a very long description                                                                                            

.EXAMPLE
# Define a new CType Class
ConvertFrom-Csv @'
PropertyType,PropertyName,PropertyTableWidth,PropertyKeywords
string,Name,20
string,HostName,20
DateTime,WhenCreated,25
DateTime,WhenDeleted,25
'@ | Add-CType -TypeName MyCompany.MyNamespace.MyClass
# Create wrapped object
New-Object -Type MyCompany.MyNamespace.MyClass -Property @{
    Name = "MyName"
    WhenCreated = (get-date)
}

.EXAMPLE
# Define a new SQL Wrapper Class
ConvertFrom-Csv @'
PropertyType,PropertyName,PropertyTableWidth,PropertyKeywords
string,Name,20,SQLWrapper
string,HostName,20,SQLWrapper
DateTime,WhenCreated,25,SQLWrapper
DateTime,WhenDeleted,25,SQLWrapper
'@ | Add-CType -TypeName MyCompany.MyNamespace.MyClass -SqlWrapper
# Create wrapped objects
$SqlWrappedObjects = $SqlDataRows | ConvertTo-CTypeSqlWrapper -TypeName MyCompany.MyNamespace.MyClass

.NOTES
This method should only be called once for any class. Calling a second time
is generally harmless as long as the type definition is identical,
otherwise an error will be reported. Types cannot be altered once added to
a process (AppDomain?).

.LINK
ConvertTo-CTypeSqlWrapper
Add-Type
Update-CTypeFormatData
Update-FormatData
#>
    [CmdletBinding()]
    param(
        [string][parameter(Mandatory=$true)]$TypeName,
        [string]$Namespace,
        [string]$ParentTypeName,
        [string[]]$Using,
        [string[]]$ReferencedAssemblies,
        [switch]$SqlWrapper,
        [System.Data.DataRow]$SqlTemplateObject,
        [switch]$NoFormatData,
        [string][parameter(ValueFromPipelineByPropertyName=$true)]$PropertyName,
        [string][parameter(ValueFromPipelineByPropertyName=$true)]$PropertyType,
        [string][parameter(ValueFromPipelineByPropertyName=$true)]$PropertyTableWidth,
        [string[]][parameter(ValueFromPipelineByPropertyName=$true)]$PropertyKeywords
        )
    begin
    {
Write-Verbose -Message @"
$($MyInvocation.InvocationName): TypeName $TypeName
$($MyInvocation.InvocationName): Namespace $Namespace
$($MyInvocation.InvocationName): ParentTypeName $ParentTypeName
$($MyInvocation.InvocationName): Using $Using
$($MyInvocation.InvocationName): ReferencedAssemblies $ReferencedAssemblies
$($MyInvocation.InvocationName): SqlWrapper $SqlWrapper
$($MyInvocation.InvocationName): SqlTemplateObject $SqlTemplateObject
"@
        if (-not $Namespace)
        {
            $nameComponents = $TypeName.Split('.')
            if ($nameComponents.Count -lt 2)
            {
                throw 'You must specify a Namespace or else a TypeName which contains a Namespace'
            }
            $TypeName = $nameComponents[-1]
            $Namespace = $nameComponents[0..($nameComponents.Count - 2)] -join '.'
        }
        if ($CType_AddedTypes["$Namespace.$TypeName"])
        {
            Write-Warning "$($MyInvocation.InvocationName): Class $Namespace.$TypeName was already added; trying anyhow"
        }
        if ($SqlTemplateObject)
        {
            $SqlWrapper = $true
        }
        $propertyList = @()
    }
    process
    {
        if ($PropertyName)
        {
Write-Verbose -Message @"
$($MyInvocation.InvocationName): PropertyName $PropertyName
$($MyInvocation.InvocationName): PropertyType $PropertyType
$($MyInvocation.InvocationName): PropertyTableWidth $PropertyTableWidth
$($MyInvocation.InvocationName): PropertyKeywords $PropertyKeywords
"@
            if (-not $PropertyType)
            {
                throw 'PropertyType must be specified for all properties'
            }
            if ($PropertyTableWidth)
            {
                if ($PropertyTableWidth -ne '*')
                {
                    $w = $PropertyTableWidth -as [int]
                    if ($w -lt 1)
                    {
                        throw "PropertyTableWidth must be either a positive integer or '*' if it is specified"
                    }
                }
            }
            $propertyList += New-Object -TypeName CType.Property -Property @{
                PropertyName = $PropertyName
                PropertyType = $PropertyType
                PropertyTableWidth = $PropertyTableWidth
                PropertyKeywords = $PropertyKeywords
                }
            if ('SQLWrapper' -in $PropertyKeywords)
            {
                $SqlWrapper = $true
            }
        }
    }
    end
    {
        if ($SqlTemplateObject)
        {
            Write-Verbose "$($MyInvocation.InvocationName): SqlTemplateObject specified, adding additional properties"
            foreach ($column in $SqlTemplateObject.Table.Columns)
            {
                $name = $column.ColumnName
                $type = $column.DataType
                if ($name -in $propertyList.PropertyName)
                {
                    Write-Verbose "$($MyInvocation.InvocationName): SqlTemplateObject column $type $name already in property list"            
                }
                else
                {
                    Write-Verbose "$($MyInvocation.InvocationName): SqlTemplateObject column $type $name must be added property list"            
                    $propertyList += New-Object -TypeName CType.Property -Property @{
                        PropertyName = $name;
                        PropertyType = $type;
                        PropertyTableWidth = 0;
                        PropertyKeywords = @('SQLWrapper');
                        }
                }
            }
            $SqlWrapper = $true
        }

        if ($SqlWrapper)
        {
            if ($Using -notcontains 'System.Data')
            {
                $Using += 'System.Data'
            }
            if ($ReferencedAssemblies -notcontains 'System.Data')
            {
                $ReferencedAssemblies += 'System.Data'
            }
        }

        Write-Verbose "$($MyInvocation.InvocationName): building C# type definition"
        $typeDefinition = New-Object -TypeName System.Text.StringBuilder
        $Using = @("System") + ($Using | Where-Object {$_})
        $Using | % {
            $null = $typeDefinition.AppendLine("using $_;")
            }
$null = $typeDefinition.AppendLine(@"
namespace $Namespace
{
    public class $TypeName $(if ($ParentTypeName) {": $ParentTypeName"})
    {
"@)
    if ($SqlWrapper)
    {
$null = $typeDefinition.AppendLine(@"
        private System.Data.DataRow WrappedSqlObject;

        public $TypeName(System.Data.DataRow obj)
        {
            this.WrappedSqlObject = obj;
        }

"@)
    }
    foreach ($property in $propertyList)
    {
        $name = $property.PropertyName
        $type = $property.PropertyType
        Write-Verbose "$($MyInvocation.InvocationName) Property $type $name"

        # CSharp seems to be picky about spelling and capitalization of these types
        $typeObject = $type -as [Type]
        if ($typeObject.FullName)
        {
            $type = $typeObject.FullName
        }

        $propertyType = $type
        if ('SqlWrapper' -in $property.PropertyKeywords)
        {
            $valueExpression = "($type)val";
            if ($typeObject.IsValueType)
            {
                $propertytype = "Nullable<$type>"
            }

$null = $typeDefinition.AppendLine(@"
        public $propertyType $name
        {
            get {
                object val = this.WrappedSqlObject["$name"];
                if ((val == null) || (val.GetType().FullName == "System.DBNull"))
                {
                    return null;
                }
            return $valueExpression;
            } // get $propertyType $name
        } // property $propertyType $name


"@)
        }
        else # -not $SqlClassWrapper
        {

$null = $typeDefinition.AppendLine(@"
        public $propertyType $name { get; set; }
"@)

        }
    }

$null = $typeDefinition.AppendLine(@"
    }
}
"@)

        Write-Verbose "$($MyInvocation.InvocationName): Adding type:`n$($typeDefinition.ToString())"
        Add-Type -TypeDefinition $typeDefinition.ToString() -ReferencedAssemblies $ReferencedAssemblies

        $CType_AddedTypes["$Namespace.$classname"] = $true

        if (-not $NoFormatData)
        {
            $tableProperties = $propertyList | Where-Object {$_.PropertyTableWidth}
            if ($tableProperties)
            {
                $text = $tableProperties | Get-CTypeFormatPS1XML -TypeName "$Namespace.$TypeName"
                $text | Update-CTypeFormatData -TypeName "$Namespace.$TypeName"
            }
        }
    }
}

function Update-CTypeFormatData
{
<#
.SYNOPSIS
Add the specified formatting metadata to the current runspace.

.PARAMETER TypeName
Full typename for the type including namespace

.PARAMETER FormatDataString
Format data string from Get-CTypeFormatPS1XML

.EXAMPLE
$tableProperties = ConvertFrom-Csv @'
PropertyType,PropertyName,PropertyTableWidth
string,Name,20
string,HostName,20
DateTime,WhenCreated,25
DateTime,WhenDeleted,25
'@
$text = $tableProperties | Get-CTypeFormatPS1XML -TypeName "$Namespace.$TypeName"
Update-CTypeFormatData -TypeName "$Namespace.$TypeName" -FormatDataString $text

.LINK
Get-CTypeFormatPS1XML
Add-CType
Update-FormatData
#>
    [CmdletBinding()]
    param(
        [string][parameter(Mandatory=$true,Position=0)]$TypeName,
        [string][parameter(Mandatory=$true, ValueFromPipeline=$true)]$FormatDataString
        )
    begin
    {
        $activity = "$($MyInvocation.InvocationName) $TypeName"
        $tempfile = Join-Path $env:temp "$TypeName.$(get-date -Format 'yyyyMMdd-hhmmss-fffffff').format.ps1xml"
        [System.Text.StringBuilder]$text = New-Object -TypeName System.Text.StringBuilder
    }
    process
    {
        $null = $text.AppendLine($FormatDataString)
    }
    end
    {
        Write-Verbose "$activity`: Adding format data to temporary file $tempfile from formatting directive:`n$FormatDataString"
        $FormatDataString | Set-Content -Path $tempFile
        try
        {
            Write-Verbose "$activity`: Updating format data"
            Update-FormatData -PrependPath $tempfile
        }
        catch
        {
            if (Test-Path $tempfile -ErrorAction SilentlyContinue)
            {
                Write-Verbose "$activity`: Deleting temporary file $tempfile"
                Remove-Item $tempfile
            }
        }
    }
}

function Get-CTypeFormatPS1XML
{
<#
.SYNOPSIS
Returns the text of a PS1XML which defines output formatting for a type.

.DESCRIPTION
Returns the text of a PS1XML which defines output formatting for a type.
Pass this to Update-CTypeFormatData to apply this formatting to the current session.
You can also save this into a PS1XML file associated with your module.

.PARAMETER TypeName
Name for the type

.PARAMETER PropertyName
Name of a property of the type being defined

.PARAMETER PropertyType
Type of a property of the type being defined

.PARAMETER PropertyTableWidth
Table width of a property of the type being defined, per Add-CType.

.PARAMETER PropertyKeywords
Other keywords per Add-CType.

.LINK
Add-CType
Update-CTypeFormatData
#>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [string][parameter(Mandatory=$true,Position=0)]$TypeName,
        [string][parameter(ValueFromPipelineByPropertyName=$true)]$PropertyName,
        [string][parameter(ValueFromPipelineByPropertyName=$true)]$PropertyType,
        [string][parameter(ValueFromPipelineByPropertyName=$true)]$PropertyTableWidth,
        [string[]][parameter(ValueFromPipelineByPropertyName=$true)]$PropertyKeywords
        )

    begin
    {
        $activity = "$($MyInvocation.InvocationName) $TypeName"
        Write-Verbose $activity
# You could also build this using the [xml] class
$fileHeader = @"
<?xml version="1.0" encoding="utf-8" ?>
<Configuration>
    <ViewDefinitions>

"@
$templateViewHeader = @"
        <View>
            <Name>{0}</Name>
            <ViewSelectedBy>
                <TypeName>{0}</TypeName>
            </ViewSelectedBy>
            <TableControl>
                <TableHeaders>
"@
$templateColumnHeader = @"
                    <TableColumnHeader>
                        <Label>{0}</Label>
                    </TableColumnHeader>
"@
$templateColumnHeaderWithWidth = @"
                    <TableColumnHeader>
                        <Label>{0}</Label>
                        <Width>{1}</Width>
                    </TableColumnHeader>
"@
$headerItemSeparator = @"
                </TableHeaders>
                <TableRowEntries>
                    <TableRowEntry>
                        <TableColumnItems>
"@
$templateColumnItem = @"
                            <TableColumnItem>
                                <PropertyName>{0}</PropertyName>
                            </TableColumnItem>
"@
$templateColumnItemWithTrim = @"
                            <TableColumnItem>
                                <ScriptBlock>
                                  (Out-String -InputObject `$_.{0}).Trim()
                                </ScriptBlock>
                            </TableColumnItem>
"@
$viewFooter = @"
                        </TableColumnItems>
                    </TableRowEntry>
                 </TableRowEntries>
            </TableControl>
        </View>        
"@
$fileFooter = @"
    </ViewDefinitions>
</Configuration>
"@

        $propertyList = New-Object System.Collections.ArrayList

        $fileContent = New-Object System.Text.StringBuilder -ArgumentList $fileHeader
        $null = $fileContent.AppendLine( ($templateViewHeader -f $TypeName) )
    }

    process
    {
Write-Verbose -Message @"
$activity`: PropertyName $PropertyName
$activity`: PropertyType $PropertyType
$activity`: PropertyTableWidth $PropertyTableWidth
$activity`: PropertyKeywords $PropertyKeywords
"@
        if ($PropertyName -and $PropertyTableWidth)
        {
            if (-not $PropertyType)
            {
                throw 'PropertyType must be specified for all properties'
            }
            if ($PropertyTableWidth)
            {
                if ($PropertyTableWidth -ne '*')
                {
                    $w = $PropertyTableWidth -as [int]
                    if ($w -lt 1)
                    {
                        throw "PropertyTableWidth must be either a positive integer or '*' if it is specified"
                    }
                }
            }
            $obj = New-Object -TypeName CType.Property -Property @{
                PropertyName = $PropertyName
                PropertyType = $PropertyType
                PropertyTableWidth = $PropertyTableWidth
                PropertyKeywords = $PropertyKeywords
                }
            $null = $propertyList.Add($obj)
        }
        else
        {
            Write-Verbose "$activity`: Skipping due to null name or width"
        }
    }

    end
    {
        foreach ($p in $propertyList)
        {
            if ($p.PropertyTableWidth)
            {
                if ($p.PropertyTableWidth -eq '*')
                {
                    $null = $fileContent.AppendLine( ($templateColumnHeader -f $p.PropertyName) )
                }
                else
                {
                    $null = $fileContent.AppendLine( ($templateColumnHeaderWithWidth -f $p.PropertyName,$p.PropertyTableWidth) )
                }
            }
        }
        $null = $fileContent.AppendLine( $headerItemSeparator )
        foreach ($p in $propertyList)
        {
            if ($p.PropertyTableWidth)
            {
                if ('Trim' -in $p.PropertyKeywords)
                {
                    $null = $fileContent.AppendLine( ($templateColumnItemWithTrim -f $p.PropertyName) )
                }
                else
                {
                    $null = $fileContent.AppendLine( ($templateColumnItem -f $p.PropertyName) )
                }
            }
        }
        $null = $fileContent.AppendLine( $viewFooter )
        $null = $fileContent.AppendLine( $fileFooter )

        Write-Output $fileContent.ToString()
    }
}


function ConvertTo-CTypeSqlWrapper
{
<#
.SYNOPSIS
Wraps a SQL row in a wrapper object.
.DESCRIPTION
Wraps a SQL row in a wrapper object. The wrapper class must first be defined by
Add-CType -SqlWrapper. The wrapped object has several advantages over the
raw System.Data.DataRow object:
(1) Property value System.DBNull is automatically converted to $null so that it is boolean-false in scripting
(2) Type can be use in [OutputType([typename])] attributes
(3) Type can be assigned formatting directives and other PowerShell type decorations
(4) All properties are read-only
(5) Hides unneeded properties of base SQL object

.PARAMETER InputObject
System.Data.DataRow object to be wrapped

.PARAMETER TypeName
Name of wrapper class, should be the same as for Add-CType

.PARAMETER AddCType
If specified, the type will be created automatically
the first time an input object of this type is received,
where the first object is a template.

.PARAMETER AddCTypeScriptBlock
If specified, the type will be created automatically
the first time an input object of this type is received,
where the first object is a template and this script block
defines additional properties of the type. This implies -AddCType.
Note the limitations in Notes below.

.EXAMPLE
$connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
$command = New-Object System.Data.SqlClient.SqlCommand $commandString,$connection
$adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
$dataset = New-Object System.Data.DataSet
$null = $adapter.Fill($dataSet)
$result = $tables[0].Rows
$wrappedResult = $result | ConvertTo-CTypeSqlWrapper -TypeName MyCompany.MyNamespace.MyWrapperClass

.NOTES
Note that the type will be defined based on the first InputObject encountered.
Even if subsequent objects have a different property list, the type cannot be changed.

Note that you can define a type using AddCTypeScriptBlock, but because that type
cannot be defined until the first template object is created, you may have difficulty
using the type in an OutputType([typename]) block or a parameter definition.
Consider generating the type definition with ConvertTo-CTypeDefinition
and pasting the CType definition directly into your code.

.LINK
Add-CType
CType
ConvertTo-CTypeSqlDefinition
#>
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline=$true)][System.Data.DataRow]$InputObject,
        [parameter(Mandatory=$true,Position=0)][string]$TypeName,
        [switch]$AddCType,
        [ScriptBlock[]][parameter(Position=1)]$AddCTypeScriptBlock
    )
    process
    {
        if ($AddCType -or $AddCTypeScriptBlock)
        {
            if (-not $CType_AddedTypes[$TypeName])
            {
                CType -TypeName $TypeName -TypeElement $AddCTypeScriptBlock,(SqlTemplateObject $InputObject)
            }
        }
        New-Object -TypeName $TypeName -ArgumentList $InputObject
    }
}

function CType
{
<#
.SYNOPSIS
Create a new type
.PARAMETER TypeName
Name of the new type. Include namespace e.g. "MyCompany.MyNamespace.MyClassName"
.PARAMETER TypeElement
One or more script blocks or type elements which define class properties and other elements of the class.
The type elements may only contain objects on the list
property, sqlproperty, parent, use, ref,SqlWrapper, SqlTemplateObject, and NoFormatData,
and the script blocks must evaluate to objects of those types.
The script block definition must begin on the same line as the CType invocation,
or must be linked with backtick.
.EXAMPLE
# Creates a type with 4 properties, three of which are displayed in the default formatter.
CType MyCompany.MyNamespace.MyClassName {
  parent MyCompany.MyNamespace.MyParentClass
  property string PropertyName1 -PropertyTableWidth 20 -PropertyKeywords trim
  if ($true)
  {
    property int PropertyName2  -PropertyTableWidth 15
  }
  property string PropertyName3 -PropertyTableWidth *
  property bool PropertyName4
}
.EXAMPLE
# Creates a type with 4 properties, three SQL wrappers and one non-wrapped property.
# The non-wrapped property can be set like any other read/write property, the others
# always read from the equivalent property of the wrapped DataRow object.
CType MyCompany.MyNamespace.MyClassName {
  parent MyCompany.MyNamespace.MyParentClass
  sqlproperty string PropertyName1 -PropertyTableWidth 20 -PropertyKeywords trim
  sqlproperty int PropertyName2  -PropertyTableWidth 15
  property string PropertyName3 -PropertyTableWidth *
  sqlproperty bool PropertyName4
}
.NOTES
A type with a given name can only be defined once per PowerShell runspace.
If you need to change it you will need to exit the runspace where it is defined.
.LINK
Add-CType
#>
    [CmdletBinding()]
    param(
        [string][parameter(Mandatory=$true,Position=0)]$TypeName,
        [parameter(Position=1)]$TypeElement
        )
    $typeElements = foreach ($element in $TypeElement)
    {
        if ($element)
        {
            if ($element -is [ScriptBlock])
            {
                Invoke-Command -ScriptBlock $element
            }
            elseif ($element -is [ScriptBlock[]])
            {
                $element | % {Invoke-Command -ScriptBlock $_}
            }
            else
            {
                $element
            }
        }
    }
    foreach ($element in $typeElements)
    {
        if (-not ($element -is [CType.TypeElement]))
        {
            throw "$($MyInvocation.InvocationName): Invalid TypeElement $($element.GetType().FullName): TypeElement may only contain property, parent, use, ref,SqlWrapper, SqlTemplateObject, and NoFormatData, or script blocks generate them"
        }
    }
    [CType.Property[]]$properties = $typeElements | Where-Object {$_ -is [CType.Property]}
    [string[]]$parentTypes = $typeElements | Where-Object {$_ -is [CType.Parent]} | Select-Object -ExpandProperty ParentTypeName
    [string[]]$using = $typeElements | Where-Object {$_ -is [CType.Using]} | Select-Object -ExpandProperty Namespace
    [string[]]$referencedAssemblies = $typeElements | Where-Object {$_ -is [CType.ReferencedAssembly]} | Select-Object -ExpandProperty AssemblyName
    [System.Data.DataRow]$sqlTemplateObject = $null
    [System.Data.DataRow[]]$sqlTemplateObjects = @($typeElements | Where-Object {$_ -is [CType.SqlTemplateObject]} | Select-Object -ExpandProperty DataRow)
    if ($parentTypes)
    {
        if ($parentTypes.Count -gt 1)
        {
            throw 'You may only specify one parent type'
        }
        $parentType = $parentTypes[0]
    }
    else
    {
        $parentType = $null
    }
    if ($sqlTemplateObjects)
    {
        if ($sqlTemplateObjects.Count -gt 1)
        {
            throw 'You may only specify one SqlTemplateObject'
        }
        $sqlTemplateObject = $sqlTemplateObjects[0]
    }
    else
    {
        $sqlTemplateObject = $null
    }
    [bool]$noFormatData = [bool]($typeElements | Where-Object {$_ -is [CType.NoFormatData]} )
    [bool]$sqlWrapper = [bool]($typeElements | Where-Object {$_ -is [CType.SqlWrapper]} )
    $split = $TypeName.Split('.')
    if ($split.Count -lt 2)
    {
        throw 'You must specify full classname including namespace'
    }
    $classname = $split[-1]
    $namespace = $split[0..($split.Count-2)] -join '.'

    $properties | Add-CType -TypeName $TypeName `
                            -ParentTypeName $parentType `
                            -Using $using `
                            -ReferencedAssemblies $referencedAssemblies `
                            -SqlWrapper:$sqlWrapper `
                            -SqlTemplateObject $SqlTemplateObject `
                            -NoFormatData:$NoFormatData
}

function property
{
<#
.SYNOPSIS
Define a property for use in CType
#>
    [CmdletBinding()]
    [OutputType([CType.Property])]
    param(
        [string][parameter(Mandatory=$true,Position=0)]$PropertyType,
        [string][parameter(Mandatory=$true,Position=1)]$PropertyName,
        [string]$width,
        [switch]$trim
        )
    $propertyHash = @{
        PropertyType=$PropertyType
        PropertyName=$PropertyName
        }
    if ($width)
    {
        $propertyHash['PropertyTableWidth'] = $width
    }
    if ($trim)
    {
        $propertyHash['PropertyKeywords'] = "Trim"
    }
    New-Object -TypeName CType.Property -Property $propertyHash
}

function sqlproperty
{
<#
.SYNOPSIS
Define a SQL wrapper property for use in CType
#>
    [CmdletBinding()]
    [OutputType([CType.Property])]
    param(
        [string][parameter(Mandatory=$true,Position=0)]$PropertyType,
        [string][parameter(Mandatory=$true,Position=1)]$PropertyName,
        [string]$width,
        [switch]$trim
        )
    $propertyHash = @{
        PropertyType=$PropertyType
        PropertyName=$PropertyName
        }
    if ($width)
    {
        $propertyHash['PropertyTableWidth'] = $width
    }
    if ($trim)
    {
        $propertyHash['PropertyKeywords'] = ('SQLWrapper','Trim')
    }
    else
    {
        $propertyHash['PropertyKeywords'] = 'SQLWrapper'
    }
    New-Object -TypeName CType.Property -Property $propertyHash
}

function parent
{
<#
.SYNOPSIS
Specify a parent class for use in CType
#>
    [CmdletBinding()]
    [OutputType([CType.Parent])]
    param(
        [string][parameter(Mandatory=$true,Position=0)]$ParentTypeName
        )
    New-Object -TypeName CType.ParentType -Property @{
        ParentTypeName=$ParentTypeName
        }
}

function use
{
<#
.SYNOPSIS
Specify a Using reference for use in CType
#>
    [CmdletBinding()]
    [OutputType([CType.Using])]
    param(
        [string][parameter(Mandatory=$true,Position=0)]$Namespace
        )
    New-Object -TypeName CType.Using -Property @{
        Namespace=$Namespace
        }
}

function ref
{
<#
.SYNOPSIS
Specify a Referenced Assembly for use in CType
#>
    [CmdletBinding()]
    [OutputType([CType.ReferencedAssembly])]
    param(
        [string][parameter(Mandatory=$true,Position=0)]$AssemblyName
        )
    New-Object -TypeName CType.ReferencedAssembly -Property @{
        AssemblyName=$AssemblyName
        }
}

function SqlWrapper
{
<#
.SYNOPSIS
Specify that a CType should be a SQL Wrapper
.LINK
ConvertTo-CTypeSqlWrapper
#>
    [CmdletBinding()]
    [OutputType([CType.SqlWrapper])]
    param(
        )
    New-Object -TypeName CType.SqlWrapper
}

function SqlTemplateObject
{
<#
.SYNOPSIS
Specify a SQL template object for use in CType
#>
    [CmdletBinding()]
    [OutputType([CType.ReferencedAssembly])]
    param(
        [System.Data.DataRow][parameter(Mandatory=$true,Position=0)]$SqlTemplateObject
        )
    New-Object -TypeName CType.SqlTemplateObject -Property @{
        DataRow=$SqlTemplateObject
        }
}

function NoFormatData
{
<#
.SYNOPSIS
Specify that a CType should not generate formatting data
.DESCRIPTION
Specify that a CType should not generate formatting data.
For example, you might perfer to generate the formatting data using
Get-CTypeFormatPS1XML and enter this into the PS1XML for your module.
#>
    [CmdletBinding()]
    [OutputType([CType.NoFormatData])]
    param(
        )
    New-Object -TypeName CType.NoFormatData
}

function ConvertTo-CTypeDefinition
{
<#
.SYNOPSIS
Generate a string representing a CType definition for the specified SQL object
.DESCRIPTION
Generate a string representing a CType definition for the specified SQL object.
You can paste this string into your module code to generate a CType SQL wrapper
for objects of the specified class, reordering the properties and adding
width and keywords to specify the formatting for the type.
.LINK
CType
Add-CType
ConvertTo-CTypeSqlWrapper
#>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [System.Data.DataRow][parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]$SqlTemplateObject
        )
    process
    {
[System.Text.StringBuilder]$typeDefinition = New-Object -TypeName System.Text.StringBuilder -ArgumentList @"
CType YourClassNameHere {
    SqlWrapper
    parent YourParentClassHere

"@
        foreach ($column in $SqlTemplateObject.Table.Columns)
        {
            $name = $column.ColumnName
            $type = $column.DataType
            $null = $typeDefinition.AppendLine("    sqlproperty $type $name")
        }
        $null = $typeDefinition.AppendLine('}')
        $typeDefinition.ToString()
    }
}

function Test-CTypeIsDefined
{
<#
.SYNOPSIS
Test whether a CType type is already defined.
.DESCRIPTION
Test whether a CType type is already defined.
Note that types may not be removed from a PowerShell session once defined.
.PARAMETER TypeName
Name for the type.
.EXAMPLE
if (-not (Test-CTypeIsDefined MyCompany.MyNamespace.ClassName))
{
    CType MyCompany.MyNamespace.ClassName2 {
        CTypeProperty int Property1
        CTypeProperty string Property2
        CTypeProperty boolean Property3
    }
}
.NOTES
This method is fast, but it only detects CType types, not .NET types generally.
.LINK
CType
Add-CType
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string][parameter(Mandatory=$true,Position=0)]$TypeName
        )
    return [bool]($CType_AddedTypes[$TypeName])
}

function Test-CTypeDotNetTypeIsDefined
{
<#
.SYNOPSIS
Test whether a type is already defined.
.DESCRIPTION
Test whether a type is already defined.
Note that types may not be removed from a PowerShell session once defined.
.PARAMETER TypeName
Name for the type.
.EXAMPLE
if (-not (Test-CTypeDotNetTypeIsDefined MyCompany.MyNamespace.ClassName))
{
    CType MyCompany.MyNamespace.ClassName2 {
        CTypeProperty int Property1
        CTypeProperty string Property2
        CTypeProperty boolean Property3
    }
}
.NOTES
This method uses .NET reflection to search for the type, so it can take 100-200ms to run.
Use it sparingly. Consider using Test-CTypeIsDefined instead.
.LINK
CType
Add-CType
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string][parameter(Mandatory=$true,Position=0)]$TypeName
        )
    $time = Measure-Command {
        $val = [bool]([appdomain]::CurrentDomain.GetAssemblies() | Where-Object DefinedTypes | Where-Object {$_.DefinedTypes.FullName -eq $TypeName})
    }
    Write-Verbose "$($MyInvocation.InvocationName): Searching for type $TypeName took $($time.TotalMilliseconds) milliseconds"
    $val
}

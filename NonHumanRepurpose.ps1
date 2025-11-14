Import-Module ActiveDirectory

$dn1 = (Get-ADOrganizationalUnit -Filter 'Name -eq "MIM-Test2"').DistinguishedName

Rename-ADObject -Identity $dn1 -NewName "Non-Human Service Accounts test"

$dn2 = (Get-ADOrganizationalUnit -Filter 'Name -eq "Non-Human Service Accounts test"').DistinguishedName

$testContainers = @("Enabled", "In-Scope", "Out-of-Scope")

foreach($t in $testContainers){
    $identity = "OU=" + $t + "," + $dn2
    Remove-ADOrganizationalUnit -Identity $identity -Recursive
}

$User = "test.user"
$ObjectTypes = @("contact", "group", "user")
$WriteBackAttributes = @("ms-ds-ConsistencyGuid;user", "msDS-ExternalDirectoryObjectID;user", "otherHomePhone;user")

$cmdReadUsers = "dsacls '$OU' /I:S /G '`"$User`":RP;;user'"
Invoke-Expression $cmdReadUsers | Out-Null

foreach($objectClass in $objectTypes)
{
    Write-Host "Object type:" $objectClass;
    foreach($attribute in $WriteBackAttributes)
    {
        [String[]]$scopedAttrs = $attribute.Split(";", [StringSplitOptions]::None);
        [String]$attr = $scopedAttrs[0];
        [String]$ttype = $scopedAttrs[1];
 
        if( ($ttype.ToLower() -eq $objectClass.ToLower()) -or
            ($ttype.ToLower() -eq "all"))
        {
            Write-Host "`tWrite Property (WP) $attr on descendent user objects";
            [String]$cmd = "dsacls '$dn2' /I:S /G '`"$User`":WP;$attr;$objectClass'";
            Invoke-Expression $cmd |Out-Null;

        }
    }
}

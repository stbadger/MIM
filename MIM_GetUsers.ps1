$domains = Get-ADTrust -Filter * | Select-Object -ExpandProperty Name
$allusers = @()

foreach ($domain in $domains) {
    $domainDN = ([ADSI]"LDAP://$domain").distinguishedName
    $searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(company=*)(|(otherHomePhone=*)(gmailAddress=*)))"
    $searcher.SearchRoot = "LDAP://$domainDN"
    $results = $searcher.FindAll()

    foreach ($r in $results){
        $user = $null
        $user = new-object -TypeName PSObject

        $properties = [ordered]@{
            Domain = $domain
            DistinguishedName = $r.Properties.distinguishedname[0]
            otherHomePhone = "placeholder"
            userPrincipalName = $r.Properties.userprincipalname[0]
            givenName = $r.Properties.givenname[0]
            sn = $r.Properties.sn[0]
            Company = $r.Properties.company[0]
            UserAccountControl = $r.Properties.useraccountcontrol[0]
        }

        foreach ($name in $properties.Keys) {
            if ($name -eq "otherHomePhone") {
                if ($r.Properties.gmailaddress) {
                    $user | Add-Member -MemberType NoteProperty -Name $name -Value $r.Properties.gmailaddress[0]
                    $user | Add-Member -MemberType NoteProperty -Name "gmailAddress" -Value "true"
                } else {
                    $user | Add-Member -MemberType NoteProperty -Name $name -Value $r.Properties.otherhomephone[0]
                    $user | Add-Member -MemberType NoteProperty -Name "gmailAddress" -Value "false"
                }
            } else {
                $user | Add-Member -MemberType NoteProperty -Name $name -Value $properties[$name]
            }
        }
        
        $allusers += $user
    }
    
}

$allusers | Export-CSV -NoTypeInformation "C:\Temp\AllUsers.csv"

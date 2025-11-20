$domains = @("MOPD.STATE.MD.US")
$properties = @("distinguishedname", "samaccountname", "otherhomephone", "gmailaddress", "gmailprovisione", "company", "proxyaddresses", "mail", "givenname", "sn", "useraccountcontrol")
$allusers = @()

foreach ($domain in $domains) {
    Write-Host "Starting $domain" -ForegroundColor Yellow
    $domainDN = ([ADSI]"LDAP://$domain").distinguishedName
    $searcher = [ADSISearcher]"(&(objectCategory=person)(objectClass=user)(|(otherHomePhone=*)(gmailAddress=*)))"
    $searcher.PageSize = 1000  # Enables paging
    $searcher.SizeLimit = 0    # 0 means no limit imposed by client
    $searcher.SearchRoot = "LDAP://$domainDN"

    foreach ($p in $properties) {
        $searcher.PropertiesToLoad.Add($p) | Out-Null
    }

    $results = $searcher.FindAll()

    foreach ($r in $results){
        $user = $null
        $user = new-object -TypeName PSObject

        $user | Add-Member -MemberType NoteProperty -Name "Domain" -Value $domain

        if ($r.Properties.distinguishedname) {
            $user | Add-Member -MemberType NoteProperty -Name "DistinguishedName" -Value $r.Properties.distinguishedname[0]
        } else {
            $user | Add-Member -MemberType NoteProperty -Name "DistinguishedName" -Value ""
        }

        if ($r.Properties.samaccountname) {
            $user | Add-Member -MemberType NoteProperty -Name "SAMAccountName" -Value $r.Properties.samaccountname[0]
        } else {
            $user | Add-Member -MemberType NoteProperty -Name "SAMAccountName" -Value ""
        }

        if ($r.Properties.gmailaddress) {
            $value = [System.Text.Encoding]::ASCII.GetString($r.Properties.gmailaddress[0])
            $user | Add-Member -MemberType NoteProperty -Name "otherHomePhone" -Value $value
            $user | Add-Member -MemberType NoteProperty -Name "gmailAddress" -Value "true"
        } else {
            $user | Add-Member -MemberType NoteProperty -Name "otherHomePhone" -Value $r.Properties.otherhomephone[0]
            $user | Add-Member -MemberType NoteProperty -Name "gmailAddress" -Value "false"
        }

        if ($r.Properties.gmailprovisioned) {
            $user | Add-Member -MemberType NoteProperty -Name "gmailProvisioned" -Value $r.Properties.gmailprovisioned[0]
        } else {
            $user | Add-Member -MemberType NoteProperty -Name "gmailProvisioned" -Value ""
        }

        if ($r.Properties.company) {
            $user | Add-Member -MemberType NoteProperty -Name "Company" -Value $r.Properties.company[0]
        } else {
            $user | Add-Member -MemberType NoteProperty -Name "Company" -Value ""
        }

        if ($r.Properties.proxyaddresses) {
            $value = $r.Properties["proxyaddresses"] -join "/;/"
            $user | Add-Member -MemberType NoteProperty -Name "proxyAddresses" -Value $value
        } else {
            $user | Add-Member -MemberType NoteProperty -Name "proxyAddresses" -Value ""
        }

        if ($r.Properties.mail) {
            $user | Add-Member -MemberType NoteProperty -Name "Mail" -Value $r.Properties.mail[0]
        } else {
            $user | Add-Member -MemberType NoteProperty -Name "Mail" -Value ""
        }

        if ($r.Properties.givenname) {
            $user | Add-Member -MemberType NoteProperty -Name "givenName" -Value $r.Properties.givenname[0]
        } else {
            $user | Add-Member -MemberType NoteProperty -Name "givenName" -Value ""
        }

        if ($r.Properties.sn) {
            $user | Add-Member -MemberType NoteProperty -Name "sn" -Value $r.Properties.sn[0]
        } else {
            $user | Add-Member -MemberType NoteProperty -Name "sn" -Value ""
        }

        if ($r.Properties.useraccountcontrol) {
            $user | Add-Member -MemberType NoteProperty -Name "UserAccountControl" -Value $r.Properties.useraccountcontrol[0]
        } else {
            $user | Add-Member -MemberType NoteProperty -Name "UserAccountControl" -Value ""
        }
        
        $allusers += $user
    }
    Write-Host "Completed $domain" -ForegroundColor Green
    
}

$allusers | Export-CSV -NoTypeInformation "C:\Temp\OPDAgencyUsers_11-20.csv"

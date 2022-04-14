# set User Agent for Invoke-RestMethod
$userAgent = 'HaveIBeenPwned Powershell Script'

# configure connection URI and settings
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$pwnedURI = "https://haveibeenpwned.com/api/v2/breachedaccount/rhuizar@arb.ca.gov"

$pwnedUser = Invoke-RestMethod -Uri $pwnedURI -UserAgent $userAgent


   # Where-Object -Property Name -InputObject $pwnedUser -eq -Value 'Houzz' { Out-Host $_.Name }
    $pwnedUser | Where-Object $_ -eq 'Houzz'
    

    #$pwnedUser.Title where $pwnedUser.Name -eq 'Houzz'
    #$pwnedUser.Domain where $pwnedUser.Name -eq 'Houzz'
    #$pwnedUser.BreachDate where $pwnedUser.Name -eq 'Houzz'
    #$pwnedUser.AddedDate where $pwnedUser.Name -eq 'Houzz'
    # $pwnedUser.ModifiedDate where $pwnedUser.Name -eq 'Houzz'
    # $pwnedUser.PwnCount where $pwnedUser.Name -eq 'Houzz'
    #$pwnedUser.Description where $pwnedUser.Name -eq 'Houzz'
    # $pwnedUser.DataClasses where $pwnedUser.Name -eq 'Houzz'
    #$pwnedUser.IsVerified where $pwnedUser.Name -eq 'Houzz'
   #$pwnedUser.IsFabricated where $pwnedUser.Name -eq 'Houzz'
   #$pwnedUser.IsSensitive where $pwnedUser.Name -eq 'Houzz'
    #$pwnedUser.IsRetired where $pwnedUser.Name -eq 'Houzz'


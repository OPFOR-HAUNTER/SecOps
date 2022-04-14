function Get-ConfirmedPwned {
    [CmdletBinding()]
    param (
        [string] $logPath = 'Get-ConfirmedPwned.log',
        $activePwnedUsers = @(),
        $breaches = @()
    )
    
    begin {
        # set User Agent for Invoke-RestMethod
        $userAgent = 'HaveIBeenPwned Powershell Script'
    }
    
    process {
       
        # process each user in the active user file
        For ( $i=0; $i -lt $activePwnedUsers.length; $i++ ){

            # begin processing individual user
            Out-File -FilePath $logPath -Append -InputObject ("*********************************************")
            
            # configure connection URI and settings
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $pwnedURI = "https://haveibeenpwned.com/api/v$version/breachedaccount/" + $activePwnedUsers[$i].EmailAddress
            Out-File -FilePath $logPath -Append -InputObject ( "User " + ( $i + 1 ) + " of " + $activePwnedUsers.length + ". Checking " + $activePwnedUsers[$i].SamAccountName + " for pwnage at $pwnedURI" ) 

            try{
                # check haveibeenpwned.com against the user. If an object is returned and not a 404 error, the user was found in a breach
                $pwned = Invoke-RestMethod -Uri $pwnedURI -UserAgent $userAgent

                if($pwned){ 
                   # Out-File -FilePath $logPath -Append -InputObject ( "Pwned var:" +  $pwned ) 
                   # Out-File -FilePath $logPath -Append -InputObject ( "breaches var:" +  $breaches ) 
                    Out-File -FilePath $logPath -Append -InputObject ( "User " + $activePwnedUsers[$i].SamAccountName + ' was found in at least one historical breach. Checking if in any specified breach...' ) 
                    $pwned | ForEach-Object {
                        if ( ( $breaches.Name ).contains( $_.Name ) ){
                            $confirmedPwnedUsers += $activePwnedUsers[$i].EmailAddress
                            Out-File -FilePath $logPath -Append -InputObject ( "User " + $activePwnedUsers[$i].SamAccountName + ' was <!! pwned !!> in a breach inside the target scope: *' + $_.Name + '*. Marked for processing.' ) 
                        }else{
                            Out-File -FilePath $logPath -Append -InputObject ( "User " + $activePwnedUsers[$i].SamAccountName + ' was found in a non-specified breach ' + $_.Name + ' outside of the target scope. Disregarding...'  ) 
                        }
                    }
                }else{
                    # user not found in specified breaches
                    Out-File -FilePath $logPath -Append -InputObject ( "User " + $activePwnedUsers[$i].SamAccountName + ' was not found in any specified breach.' ) 
                }
            }catch{
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Out-File -FilePath $logPath -Append -InputObject ("There was an error checking " + $activePwnedUsers[$i].EmailAddress + ' :' + $ErrorMessage)
                Out-File -FilePath $logPath -Append -InputObject ( "User " + $activePwnedUsers[$i].SamAccountName + ' was not found in any specified breach.' ) 
            }

            # wait 1600 miliseconds between loop iterations to prevent throttling from the server (1500 is the minimum per ihavebeenpwned.com)
            Start-Sleep -m 1600
        }

    }
    
    end {
        return $confirmedPwnedUsers
    }
}
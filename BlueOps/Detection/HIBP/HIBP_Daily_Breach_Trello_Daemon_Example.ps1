# HIBP Daily Breach Trello Daemon
# Checks haveibeenpwned once a day for any new breach posted in the last day
# Creates a Trello card for each breach found in the last day for an organization's
# userbase posts EmailAddress, SamAccountName, & PasswordLastSet of confirmed pwned users.
# This script could be done so, so much better. DON'T JUDGE ME
# Author: Gualberto S. Maciel / HAUNTER
# Email: gualberto.s.maciel@gmail.com
# Github: https://github.com/OPFOR-HAUNTER

Import-Module -Name C:\Operations\HIBP\HIBP.psm1
Import-Module -Name C:\Operations\Trello\Trello.psm1

# init log
$logpath = ".\HIBP_Daily_Breach_Daemon.log"
$datetime = Get-Date -Format MM-dd-yyyyTmm:ss
Out-File -FilePath $logpath -Append -InputObject ("######################################")
Out-File -FilePath $logpath -Append -InputObject ("######################################")
Out-File -FilePath $logpath -Append -InputObject ("#### HIBP_Daily_Breach_Trello_Daemon.ps1 ####")
Out-File -FilePath $logpath -Append -InputObject ("Executing at $datetime")


# try to get confirmed pwned users from breaches posted in the last day
try{
    # note: there was a reason I didn't simply store the following command into a var...but I totally forgot why...
    Out-File -FilePath $logpath -Append -InputObject ("Trying to run Get-HIBPUsersByBreach...")
    Get-HIBPUsersByBreach -HIBPUsers ($HIBPUsers = Get-HIBPUsers -logpath $logpath) -HIBPBreaches (Get-HIBPBreaches -dayperiod -1 -HIBPToken (Get-HIBPToken -logpath $logpath) -logpath $logpath ) -HIBPToken (Get-HIBPToken) -logpath $logpath

}catch{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    Out-File -FilePath $logpath -Append -InputObject ("There was an error running Get-HIBPUsersByBreach: " + $ErrorMessage + '. Aborting.')
    break
}

# try to get json object of users by breach(es)
try{
    Out-File -FilePath $logpath -Append -InputObject ("Trying to get HIBPUsersByBreach from JSON file....")
    $HIBPUsersByBreach =  Get-Content -Path C:\Operations\HIBP\HIBPUsersByBreach.json | ConvertFrom-Json
}catch{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    Out-File -FilePath $logpath -Append -InputObject ("There was an error getting HIBPUsersByBreach: " + $ErrorMessage + '. Aborting.')
    break
}

# try to get current IR cards from Trello
try{
    Out-File -FilePath $logpath -Append -InputObject ("Trying to get IR cards from Trello...")
    $IRCards = Get-Trello -list -listId $listId -listCards -logPath $logpath 
}catch{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    Out-File -FilePath $logpath -Append -InputObject ("There was an error getting existing Trello cards: " + $ErrorMessage + '. Aborting.')
    break
}

# try to create a Trello card for each breach
try{

    $HIBPUsersByBreach.Psobject.Properties.Name  | ForEach-Object { # process each breach
    
        Out-File -FilePath $logpath -Append -InputObject ("Trying to build Trello card for breach $_")
        $name = "HIBP Breach: $_"

        # we need to check to see if the card already exists
        foreach($card in $IRCards.name){ 
            $isDuplicate = $false
            if($card.Contains($_)){
                $isDuplicate = $true
                Out-File -FilePath $logpath -Append -InputObject ("Trello card for breach $_ already exists. Discarding breach.")
                break
            }
            else{
                continue
            }   
        }

        # card creation
        try{      
            if(($HIBPUsersByBreach.$_ -ne '') -and (-not $isDuplicate)){ # proceed if the breach does not have a card already and has users
                
                Out-File -FilePath $logpath -Append -InputObject ("Card is not a duplicate." )
                $breach = (Get-HIBPBreach -breachName $_ -logpath $logpath)  
                
                # card stuffs
                $description = ''
                $listId = '1234567890' # replace this with your target Trello listid value
                $idLabels = '1234567890' # replace this with your desired default label for the card
                
                if($breach.DataClasses.Contains('Passwords')){ # if we see exposed creds, we apply another tag for higher risk visibility
                    $name += " - Exposed Passwords"
                    $description += "<!!! BREACH CONTAINS EXPOSED PASSWORDS !!!>%0A%0A"
                    $idLabels += ',1234567890' # replace this with your high risk label value
                }else{
                    $description += "Breach does not contain exposed passwords. Review the breach dataclasses to determine risk. %0A%0A"
                    $idLabels += ',`1234567890' # replace this with your low risk label value
                }

         
                $description += "$_ %0A " # the special characters here are newline characters in Trello cards
                $description += $breach.Description
                $description += ("%0A%0AAdded Date: " + $breach.AddedDate + "%0A")
                $description += ("%0ABreach Date: " + $breach.BreachDate + "%0A")
                $description += ("%0AData classes: " + $breach.DataClasses + "%0A")
                $description += "%0A%0A%0A $_ Pwned users:%0A "

                # dedupe users
                foreach($user in $HIBPUsersByBreach.$_){
                    $lastSet = ''   
           
                    if($description.Contains($user) -ne $true ){# if description does not already contain the user email, continue
                        Out-File -FilePath $logpath -Append -InputObject ("User: " + $user )
                        foreach($pwnedUser in $HIBPUsers ){
                            if(($pwnedUser.EmailAddress) -eq ($user)){
                              Out-File -FilePath $logpath -Append -InputObject ("SamAccountName: " + $pwnedUser.SamAccountName )
                              $lastSet =  Get-aduser -identity $pwnedUser.SamAccountName -Properties PasswordLastSet -Server HQDC1 | Select -ExpandProperty PasswordLastSet
                              Out-File -FilePath $logpath -Append -InputObject ("PasswordLastSet: " + $lastSet )
                              $description += ("$user - SamAccountName: " + $pwnedUser.SamAccountName + " PasswordLastSet: $lastSet %0A ")

                            }
                        }
                    
                    }
                      
                }
                
                $description += "%0A%0A%0A Note: haveibeenpwned reports ALL organization emails found in a breach. 
                                 The HIBP Daily Breach daemon verifies currently Enabled users only. There
                                 may be disabled users reported by haveibeenpwned that are not included here."



                Out-File -FilePath $logpath -Append -InputObject ("Attempting to post card on Trello with the following details:")
                Out-File -FilePath $logpath -Append -InputObject ($description)
                New-Trello -card -listId $listId -name $name -desc $description -logPath $logpath -idLabels $idLabels
            }else{
                Out-File -FilePath $logpath -Append -InputObject ("Could not create trello card for $_")
            }
         }catch{
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Out-File -FilePath $logPath -Append -InputObject ("There was an error creating trello cards: " + $ErrorMessage + '. Aborting.')
         }
    }
}catch{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    Out-File -FilePath $logPath -Append -InputObject ("There was an error creating trello cards: " + $ErrorMessage + '. Aborting.')
    break
}
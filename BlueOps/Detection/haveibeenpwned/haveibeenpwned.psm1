<#
.SYNOPSIS
        Gets list of users with emails/passwords exposed in third-party data breaches as resported by by haveibeenpwned.com.
        Then expires users' passwords that are enabled and have been pwned in a breach that contained password info. Finally,
        emails those users with details concerning tget-he breach and notificaiton of their password reset.

.DESCRIPTION
    This command takes in a list of active CARB AD users to check against haveibeenpwned.com to see if an email address has 
    been found in a breach. A breach can be specified by name or the script can pull recently added breaches that contained
    password data from x days ago, where  -30 < x <= 0. Default is -1 days ago (day before script run) for use in daily scheduled
    run. The source file must have the column 'EmailAddress' with each user on a seperate row in the format username@arb.gov. 
    The source file path can be specified by using the filepath flag or the default can be set in the script. Each 
    user in the script will return an object if they are found within the breach database. If they are NOT found, they return 
    an error 404. The command places pwned users in an object for output, each user is processed to have their password set 
    to expired, and an email is sent out with the breach details.

.INPUTS
    Description of objects that can be piped to the script

.OUTPUTS
    An array, pwnedUsers, is output for users found in 1 or more breaches. The object contains the username, email, breach name,
    breach description, and breach date.

.EXAMPLE
    Get pwned users for any breaches (with passwords) published in the last 7 days, checks against all Enabled AD users. Default is -1 day (day before). Range 0 to -30
        Get-PwnedUsers -dayperiod -7
    
    Get pwned users for a specific breach (e.g., 'Houzz'). checks against all Enabled AD users.
        Get-PwnedUsers -filepath H:\raw\ADActiveUsers.csv -breachName Houzz

    Get specific list of users against all breaches in the last default time period (one day before script runtime) 
        Get-PwnedUsers -filepath H:\Code\Powershell\raw\ADEnabledUsers.csv
    
    Get specific list of users against a specific breach (time period is irrelevant)
        Get-PwnedUsers -filepath H:\raw\ADActiveUsers.csv -breachName houzz  

.LINK
    https://haveibeenpwned.com/API/v2

.NOTES
    Author: William Maciel <william.maciel@arb.ca.gov>
    Security Information Specialist
    Security Operations Center
#>
function Get-PwnedUsers {
    [CmdletBinding()]
    
    param (
        # specificy API version to use, v1 is available but v2 is default
        [ValidateRange(1, 2)]
        [int] $version = 2,

        # specify a certain breach by name
        [string] $breachName,

        # specify days from current date to search breaches. E.g., enter -7 for breaches published in the previous week. Default is -1 ( day before )
        [ValidateRange(-30, 0)]
        [int] $dayperiod = -1,

        # specify the path to the CARB active user list file. Default behavior Get-ActiveADusers will run and pull all Enabled AD users to process
        [string] $filepath
    )

    begin {

        # create array for breach objects
        $breaches = @()

        # set datetime of script runtime for logging and initialize log
        $runtimestamp = Get-Date -Format MM-dd-yyyyTmm:ss
        $logPath = $PSScriptRoot + '\Get-PwnedUsers.log'
        Out-File -FilePath $logPath -Force -InputObject "Get-PwnedUsers Log: Run time $runtimestamp" 

    }  

    process {

        # get breach info
        # try to get breach details if one was specified
        if ( ( $NULL -ne $breachName ) -and ( $breachName -gt '' ) ) {
            try {
                Out-File -FilePath $logPath -Force -InputObject ( "Trying to get specified breach " + $breachName + " info..." ) -Append
                $breaches = Get-BreachInfo -breachName $breachName -logPath $logPath
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Out-File -FilePath $logPath -Append -InputObject ( "There was an error getting breach info for" + $breachName + " : " + $ErrorMessage )
                break
            }
        }
        else {
            # else if no specific breach specified, try getting recent breaches that meet the date/password criteria
            try {
                Out-File -FilePath $logPath -Force -InputObject ( "Trying to get recent breaches with compromised passwords..." ) -Append
                $breaches = Get-Breaches -logPath $logPath -dayperiod $dayperiod
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Out-File -FilePath $logPath -Append -InputObject ("There was an error getting breaches from haveibeenpwned.com : " + $ErrorMessage)
                break
            }
        }

        
        # import users from specified file or from AD
        try {
            $activePwnedUsers = Import-ActivePwnedUsers -logPath $logPath -FilePath $filepath
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Out-File -FilePath $logPath -Append -InputObject "There was an error importing activePwnedUsers: $ErrorMessage at $FailedItem"
            break
        }

        # process confirmed users are in targeted breaches
        try {
            $confirmedPwned = Get-ConfirmedPwned -logPath $logPath -breaches $breaches -activePwnedUsers $activePwnedUsers
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Out-File -FilePath $logPath -Append -InputObject "There was an error processing confirmedPwned users: $ErrorMessage at $FailedItem"
            break
        } 

        # export activePwnedUsers
        try {
            Out-File -FilePath ($PSScriptRoot + '\pwnedUsers.csv') -Append -InputObject ($confirmedPwned)
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Out-File -FilePath $logPath -Append -InputObject "There was an error exporting pwned users: $ErrorMessage at $FailedItem"
            break
        } 

        <#
        # implement actions 
        # send email to pwnedUsers
        try{
           # Send-PwnedEmail -breach $breach -pwnedUsers $pwnedUsers
        }catch{
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Out-File -FilePath $logPath -Append -InputObject ("There was an error sending the email to pwned users: " + $ErrorMessage)
        } #>
    }

    end {
        Out-File -FilePath $logPath -Append -InputObject ( "*********************************************" )
        Out-File -FilePath $logPath -Append -InputObject ( "The script completed running at " + ( Get-Date -Format MM-dd-yyyyTmm:ss ) )
    }
}

function Get-Breaches {
    [CmdletBinding()]
    param (
        [int] $dayperiod = -1,
        [string] $logPath = 'Get-BreachInfo.log'
    )
    
    begin {
        $breaches = @()
    }
    
    process {

        Out-File -FilePath $logPath -Force -InputObject ( "Getting breaches..." ) -Append

        # get recent breaches from current date minus the dayperiod
        $pwnedBreaches = ( Get-RecentBreach -dayperiod $dayperiod -logPath $logPath )

        # get info object for each breach
        $pwnedBreaches | ForEach-Object {
            $breaches += Get-BreachInfo -breachName $_ -logPath $logPath 
        } 
    }
    
    end {
        # if any breach found and returned an object, continue. Else, break.
        if ( $breaches ) {
            Out-File -FilePath $logPath -Append -InputObject ( "*********************************************" )
            Out-File -FilePath $logPath -Append -InputObject ("Identified " + $breaches.count + " breaches. Ready for processing.")
            Out-File -FilePath $logPath -Force -InputObject ( "Returning breaches..." ) -Append
            return $breaches
            # Out-File -FilePath $logPath -Append -InputObject ($breaches)
        }
        else {
            Out-File -FilePath $logPath -Append -InputObject ( "Could not get breach info, aborting script." )
            break 
        }
    }
}
function Get-BreachInfo {
    [CmdletBinding()]
    param ( 
        [string] $breachName = $NULL,
        [string] $logPath = 'Get-BreachInfo.log'
    )
    
    begin {
        # set User Agent for Invoke-RestMethod
        $userAgent = 'HaveIBeenPwned Breach Powershell Script'

        # configure connection URI and settings
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # breach URI for API call
        $breachURI = "https://haveibeenpwned.com/api/v2/breach/$breachName"
    }
    
    process {
        try {
            $breach = Invoke-RestMethod -Uri $breachURI -UserAgent $userAgent
            Out-File -FilePath $logPath -Append -InputObject ( "*********************************************" )
            Out-File -FilePath $logPath -Force -InputObject "Getting breach info for $breachName at $breachURI" -Append
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Out-File -FilePath $logPath -Append -InputObject ("There was an error checking " + $breachName + ' :' + $ErrorMessage)
        }
    }
    end {
        return $breach
    }
}

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
        For ( $i = 0; $i -lt $activePwnedUsers.length; $i++ ) {

            # begin processing individual user
            Out-File -FilePath $logPath -Append -InputObject ("*********************************************")
            
            # configure connection URI and settings
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $pwnedURI = "https://haveibeenpwned.com/api/v$version/breachedaccount/" + $activePwnedUsers[$i].EmailAddress
            Out-File -FilePath $logPath -Append -InputObject ( "User " + ( $i + 1 ) + " of " + $activePwnedUsers.length + ". Checking " + $activePwnedUsers[$i].SamAccountName + " for pwnage at $pwnedURI" ) 

            try {
                # check haveibeenpwned.com against the user. If an object is returned and not a 404 error, the user was found in a breach
                $pwned = Invoke-RestMethod -Uri $pwnedURI -UserAgent $userAgent

                if ($pwned) { 
                    # Out-File -FilePath $logPath -Append -InputObject ( "Pwned var:" +  $pwned ) 
                    # Out-File -FilePath $logPath -Append -InputObject ( "breaches var:" +  $breaches ) 
                    Out-File -FilePath $logPath -Append -InputObject ( "User " + $activePwnedUsers[$i].SamAccountName + ' was found in at least one historical breach. Checking if in any specified breach...' ) 
                    $pwned | ForEach-Object {
                        if ( ( $breaches.Name ).contains( $_.Name ) ) {
                            $confirmedPwnedUsers += $activePwnedUsers[$i].EmailAddress
                            Out-File -FilePath $logPath -Append -InputObject ( "User " + $activePwnedUsers[$i].SamAccountName + ' was <!! pwned !!> in a breach inside the target scope: *' + $_.Name + '*. Marked for processing.' ) 
                        }
                        else {
                            Out-File -FilePath $logPath -Append -InputObject ( "User " + $activePwnedUsers[$i].SamAccountName + ' was found in a non-specified breach ' + $_.Name + ' outside of the target scope. Disregarding...'  ) 
                        }
                    }
                }
                else {
                    # user not found in specified breaches
                    Out-File -FilePath $logPath -Append -InputObject ( "User " + $activePwnedUsers[$i].SamAccountName + ' was not found in any specified breach.' ) 
                }
            }
            catch {
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

function Get-RecentBreach {
    [CmdletBinding()]
    param ( 
        [int] $dayperiod = -1,
        [string] $logPath = 'Get-RecentBreach.log'
    )
    
    begin {
        # set User Agent for Invoke-RestMethod
        $userAgent = 'HaveIBeenPwned Recent Breach Powershell Script'

        # set date range
        $today = Get-Date -Format yyyy-MM-ddThh:mm:ss
        $dayperiodDate = (get-date).AddDays($dayperiod)
        $dayperiodDate = get-date $dayperiodDate -Format yyyy-MM-ddThh:mm:ss

        # configure connection URI and settings
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # try to get breach info
        $breachesURI = "https://haveibeenpwned.com/api/v2/breaches"
        
        # initialize log
        Out-File -FilePath $logPath -Append -InputObject ( "*********************************************" )
        Out-File -FilePath $logPath -Force -InputObject "Getting recent breaches info for $today back to $dayperiodDate" -Append

        # create array for breach objects to return
        $recentBreaches = @()
    }
    
    process {

        try {
            $breaches = Invoke-RestMethod -Uri $breachesURI -UserAgent $userAgent
           
            # check if any breaches were within the interval time period
            $breaches | ForEach-Object {
                if ( ( get-date $_.AddedDate ) -gt ( get-date $dayperiodDate ) ) {

                    # then check if the breach contained passwords
                    if ( ( $_.DataClasses ).contains( 'Passwords' ) ) {

                        Out-File -FilePath $logPath -Force -Append -InputObject ( 'Breach ' + $_.Name + ' was added in the specified interval of ' + $intervalAmount + ' days on ' + $_.AddedDate + ' & contained compromised passwords.' )
                        $recentBreaches += $_.Name
                        #$_.AddedDate
                        #$_.BreachDate
                        #$_.Pwnedcount
                        #$_.DataClasses
                        #$_.Description

                    }
                    else {
                        Out-File -FilePath $logPath -Force -Append -InputObject ( 'Breach ' + $_.Name + ' was added in the specified interval of ' + $intervalAmount + 'but did not contain any compromised passwords.' )
                    }
                }
            }
           
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Out-File -FilePath $logPath -Append -InputObject ("There was an error checking for breaches:" + $ErrorMessage)
        }
    }
    end {
        
        # return breaches that meet the date interval & contained passwords for processing
        Out-File -FilePath $logPath -Append -InputObject ( "*********************************************" )
        Out-File -FilePath $logPath -Append -InputObject ( "Returning " + $recentBreaches.count + " for processing. Breaches are as follows: " )
        Out-File -FilePath $logPath -Append -InputObject ( $recentBreaches )
        return $recentBreaches

    }
}

function Import-ActivePwnedUsers {
    [CmdletBinding()]
    param (
        [string] $logPath = 'Import-PwnedUsers.log',
        [string] $filepath
    )
    
    begin {
        # create output file
        $currentDatetime = Get-Date -Format MM-dd-yyyyTmm:ss
    }
    
    process {
        # get CARB active users file to process and validate
        # if an AD user file was specified
        if ( $filepath ) {
            Out-File -FilePath $logPath -Append -InputObject "Importing enabled AD users from $filepath"
            $activePwnedUsers = Import-CSV ( $filepath )
        }
        else {
            # get all AD users that are enabled & have an email address
            Out-File -FilePath $logPath -InputObject "Fetching all enabled AD users. Commencing at $currentDatetime" -Append
            $activePwnedUsers = Get-ADUser -Filter { ( Enabled -eq $true ) -and ( EmailAddress -ne $false ) } -Properties SamAccountName, DisplayName, EmailAddress, Title, Enabled | Select SamAccountName, DisplayName, EmailAddress, Title, Enabled
            Out-File -FilePath $logPath -InputObject ( "Total of " + $activePwnedUsers.count + " enabled AD users found at " + ( Get-Date -Format MMddyyyymmss ) ) -Append
            Out-File -FilePath $logPath -InputObject ( "Get-ActiveADUsers completed at " + ( Get-Date -Format MM-dd-yyyyTmm:ss ) ) -Append
        }
  
        # validate the active user list
        if ( $activePwnedUsers ) {
            Out-File -FilePath $logPath -Append -InputObject ( "Successfully imported " + $activePwnedUsers.count + " activePwnedUsers for processing." )
        }
        else {
            # user import failed
            Out-File -FilePath $logPath -Append -InputObject ( "Failed to import activePwnedUsers for processing. Aborting Script." )
            break
        }
    }
    
    end {
        return $activePwnedUsers
    }
}
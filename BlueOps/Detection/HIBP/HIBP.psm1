# HIBP.psm1 - haveibeenpwned API Powershell Module
# Author: Gualberto S. Maciel / HAUNTER
# Email: gualberto.s.maciel@gmail.com
# Github: https://github.com/OPFOR-HAUNTER

function Get-HIBPToken {
<#
.SYNOPSIS
    Gets the haveibeenpwned API token required for all API calls.

.DESCRIPTION
    Gets the haveibeenpwned API token required for all API calls from a text file. Returns token as a string.

.PARAMETERS
    -filepath
        [mandatory][string] Path to file containing API token.
    -logpath
        [string] Path to file to write log infos.

.OUTPUTS
    $HIBPToken
        [string] Content from -filepath.

.EXAMPLE
   Get-HIBPToken
        Gets API token from default filepath and logs in the current directory.
   
   Get-HIBPToken -filepath $filepath -logpath $logpath
        Gets API token from specified path and logs at $logpath string.

   Get-HIBPUsersByBreach -HIBPUsers ($HIBPUsers = Get-HIBPUsers -logpath $logpath) -HIBPBreaches (Get-HIBPBreaches -dayperiod -365 -HIBPToken (Get-HIBPToken -logpath $logpath) -logpath $logpath ) -HIBPToken (Get-HIBPToken) -logpath $logpath        
        Gets API token for nested HIBP function calls.

.LINK
    https://haveibeenpwned.com/API/v3
#>
    [CmdletBinding()]
    
    param (
        # path to API token
        [string] $filepath = "Tokens\HIBP_Token.txt",
        [string] $logpath = "HIBP.log"
    )

    begin{
        # initialize log
        $datetime = Get-Date -Format MM-dd-yyyyTmm:ss
        Out-File -FilePath $logpath -Append -InputObject ( "*********************" )
        Out-File -FilePath $logpath -Force -InputObject "Get-HIBPToken executing at $datetime" -Append
    }
    process{
        try{
            # get HIBP API Token
            Out-File -InputObject "Getting HIBP API Token from $filepath" -FilePath $logpath -Force -Append
            $HIBPToken = Get-Content -Path $filepath 
        }
        catch{
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Out-File -FilePath $logpath -Append -InputObject ( "There was an error fetching the HIBP API Token: " + $ErrorMessage )
            break
        }
    }
    end{
        Out-File -FilePath $logpath -Force -InputObject "Returning token..." -Append
        Out-File -FilePath $logpath -Append -InputObject ( "Get-HIBPToken End" )
        Out-File -FilePath $logpath -Append -InputObject ( "*********************" )
        return $HIBPToken
    }
}
function Get-HIBPBreachByPeriod {
<#
.SYNOPSIS
    Gets all posted breaches from haveibeenpwned.com and filters results based on dayperiod provided.

.DESCRIPTION
    Gets all posted breaches from haveibeenpwned.com and filters results based on the date the breach was posted.
    Dayperiod is the amound of days back from present day. Default is -1 days ago (day before script run) for use in daily scheduled
    run. $dayperiod = -1 is used to get any breaches posted the past day only, and to prevent pulling other previous breaches processed.
    A lesser value (e.g. -365) is useful for less intensive scripts.

.PARAMETERS
    -dayperiod
        [int] Value of days back from present day to retrieve breaches posted on haveibeenpwned.com
    -logpath
        [string] Path to file to write log infos.
    -HIBPToken
        [string] API token value.

.OUTPUTS
    $HIBPBreachByPeriod
        [array] Array of filtered breach names.

.EXAMPLE
   Get-HIBPBreachByPeriod
        Gets all breaches posted on haveibeenpwned.com that were posted at the default dayperiod of -1 (within the last day).
   
   Get-HIBPToken -dayperiod -365 -logpath $logpath -HIBPToken $HIBPToken
        Gets all breaches posted on haveibeenpwned.com that were posted at the dayperiod of -365 (within the last year), and uses defined logpath and HIBPToken values.

.LINK
    https://haveibeenpwned.com/API/v3
#>
    [CmdletBinding()]
    param ( 
        [int] $dayperiod = -1,

        # logpath
        [string] $logpath = "HIBP.log",

        # HIBP API Token
        $HIBPToken = (Get-HIBPToken)
    )
    
    begin {
        # web request stuff
        $userAgent = 'HaveIBeenPwned Recent Breach Powershell Script'
        $headers = @{'hibp-api-key'= $HIBPToken}
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $breachesURI = "https://haveibeenpwned.com/api/v3/breaches"

        # init log
        $datetime = Get-Date -Format yyyy-MM-ddThh:mm:ss
        $dayperiodDate = (get-date).AddDays($dayperiod)
        $dayperiodDate = get-date $dayperiodDate -Format yyyy-MM-ddThh:mm:ss
        Out-File -FilePath $logpath -Append -InputObject ( "*********************" )
        Out-File -FilePath $logpath -Force -InputObject "Get-HIBPBreachByPeriod executing at $datetime..." -Append
        Out-File -FilePath $logpath -Force -InputObject "Getting recent breaches info for $datetime back to $dayperiodDate" -Append

        # create array for breach objects to return
        $HIBPBreachByPeriod = @()
    }
    
    process {

        try {
            $breaches = Invoke-RestMethod -Uri $breachesURI -UserAgent $userAgent -Headers $headers
           
            # check if any breaches were within the interval time period
            $breaches | ForEach-Object {
                if ( ( get-date $_.AddedDate ) -gt ( get-date $dayperiodDate ) ) {
                    Out-File -FilePath $logpath -Force -Append -InputObject ( 'Breach ' + $_.Name + ' was added in the specified interval of ' + $dayperiod + ' days on ' + $_.AddedDate + ' & contained '+ $_.DataClasses)
                    $HIBPBreachByPeriod += $_.Name
                }
            }
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Out-File -FilePath $logpath -Append -InputObject ("There was an error checking for breaches:" + $ErrorMessage)
        }
    }
    end {
        
        # return breaches that meet the date interval
        Out-File -FilePath $logpath -Append -InputObject ( "Returning " + $HIBPBreachByPeriod.count + " for processing." )
        Out-File -FilePath $logpath -Append -InputObject ( "Get-HIBPBreachByPeriod End" )
        Out-File -FilePath $logpath -Append -InputObject ( "*********************" )
        return $HIBPBreachByPeriod
    }
}
function Get-HIBPBreach {
<#
.SYNOPSIS
    Gets the breach JSON data object for a specified breach from haveibeenpwned.com.

.DESCRIPTION
    Gets the breach JSON data object for a specified breach from haveibeenpwned.com. The breach model can be referenced here
    for the total attribite list returned: https://haveibeenpwned.com/API/v3#BreachModel

.PARAMETERS
    -breachName
        [string] Name of a single breach to poll from haveibeenpwned.com. Name must match HIBP API schema.
    -logpath
        [string] Path to file to write log infos.
    -HIBPToken
        [string] API token value.

.OUTPUTS
    $HIBPBreach
        [object] JSON raw object containing all breach model data for the specified breach.

.EXAMPLE
   Get-HIBPBreach -breachName "MGM"
        Gets the breach data object for the MGM breach.
           
   Get-HIBPBreachByPeriod -dayperiod -30 | ForEach-Object { Get-HIBPBreach -breachName $_ }
        Gets all breach data objects for all breaches within the last 30 days.

#>
    [CmdletBinding()]
    param ( 
        
        [string] $breachName = $NULL,
        
        [string] $logpath = 'HIBP.log',
        
        # HIBP API Token
        $HIBPToken = (Get-HIBPToken)
    )
    
    begin {
        # web request stuffs
        $userAgent = 'HaveIBeenPwned Breach Powershell Script'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $breachURI = "https://haveibeenpwned.com/api/v3/breach/$breachName"
        $headers = @{'hibp-api-key'= $HIBPToken}

        
        # init log
        $datetime = Get-Date -Format yyyy-MM-ddThh:mm:ss
        Out-File -FilePath $logpath -Append -InputObject ( "*********************" )
        Out-File -FilePath $logpath -Append -InputObject ( "Executing Get-HIBPBreach at $datetime..." )
        Out-File -FilePath $logpath -Force -InputObject "Getting breach info for $breachName..." -Append
    }
    
    process {
        try {
            $HIBPBreach = Invoke-RestMethod -Uri $breachURI -UserAgent $userAgent -Headers $headers
            Out-File -FilePath $logpath -Force -InputObject "$breachName via $breachURI" -Append
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Out-File -FilePath $logpath -Append -InputObject ("There was an error checking " + $breachName + ' :' + $ErrorMessage)
        }
    }
    end {
        return $HIBPBreach
        Out-File -FilePath $logpath -Append -InputObject ( "Get-HIBPBreach End" )
        Out-File -FilePath $logpath -Append -InputObject ( "*********************" )

    }
}
function Get-HIBPBreaches {
<#
.SYNOPSIS
    Gets the breach JSON data objects for all breaches posted on haveibeenpwned.com within 
    the specied dayperiod.

.DESCRIPTION
    Wrapper function for Get-HIBPBreach & Get-HIBPBreachByPeriod. Passes dayperiod and gets 
    all JSON data objects for breaches with the specified dayperiod.

.PARAMETERS
    -dayperiod
        [int] Value of days back from present day to retrieve breaches posted on haveibeenpwned.com.
    -logpath
        [string] Path to file to write log infos.
    -HIBPToken
        [string] API token value.

.OUTPUTS
    $HIBPBreaches
        [array] Collection of JSON objects for breaches posted within the specified dayperiod.

.EXAMPLE
   Get-HIBPBreaches
        Gets all breaches from the default dayperiod -1 and their respective breach model objects.
           
   Get-HIBPBreaches -dayperiod -30
        Gets all breach data objects for all breaches within the last 30 days.

#>
    [CmdletBinding()]
    param (
        # 
        [int] $dayperiod = -1,
        
        # logpath
        [string] $logpath = "HIBP.log",

        # HIBP API Token
        $HIBPToken = (Get-HIBPToken)
    )
    
    begin {
        # init log
        $datetime = Get-Date -Format yyyy-MM-ddThh:mm:ss
        $dayperiodDate = (get-date).AddDays($dayperiod)
        $dayperiodDate = get-date $dayperiodDate -Format yyyy-MM-ddThh:mm:ss
        Out-File -FilePath $logpath -Append -InputObject ( "*********************" )
        Out-File -FilePath $logpath -Append -InputObject ( "Get-HIBPBreaches executing at $datetime..." )
        Out-File -FilePath $logpath -Force -InputObject "Getting recent breaches info from $datetime back to $dayperiodDate" -Append

        $HIBPBreaches = @()
    }
    
    process {

        # get recent breaches from current date minus the dayperiod
        $breachesByPeriod = ( Get-HIBPBreachByPeriod -dayperiod $dayperiod -logpath $logpath -HIBPToken $HIBPToken)

        # get info object for each breach
        $breachesByPeriod | ForEach-Object {
           $HIBPBreaches += Get-HIBPBreach -breachName $_ -logpath $logpath -HIBPToken $HIBPToken
        } 
    }
    
    end {
        # if any breach found and returned an object, continue. Else, break.
        if ($HIBPBreaches) {
            Out-File -FilePath $logpath -Append -InputObject ("Identified " + $HIBPBreaches.count + " breaches. Ready for processing.")
            Out-File -FilePath $logpath -Force -InputObject ( "Returning breaches..." ) -Append
            return $HIBPBreaches
            Out-File -FilePath $logpath -Append -InputObject ($HIBPBreaches)
        }
        else {
            Out-File -FilePath $logpath -Append -InputObject ( "Could not get breach info, aborting script." )
            break 
        }
        Out-File -FilePath $logpath -Append -InputObject ( "Get-HIBPBreaches End" )
        Out-File -FilePath $logpath -Append -InputObject ( "*********************" )
    }
}
function Get-HIBPUsers {
<#
.SYNOPSIS
    Gets AD users to process against haveibeenpwned breaches.

.DESCRIPTION
    Gets AD users to process against haveibeenpwned breaches. Can import a CSV of users or pull directly
    from Active Directory. CSV should include EmailAddress a header. Active Directory import will only 
    ingest Enabled users for processing. Outputs an array of organization user's EmailAddress values. 
    haveibeenpwned.com stores breach data for users via email address calls.

.PARAMETERS
    -logpath
        [string] Path to file to write log infos.
    -filepath
        [string] Path to file containing users to import. Headers should inclue at least AD EmailAddress.

.OUTPUTS
    $HIBPUsers
        [array] Array of enabled AD user EmailAddress values. 

.EXAMPLE
   Get-HIBPUsers
        Gets all enabled Active Directory user EmailAddress values for processing.
           
   Get-HIBPUsers -filepath ".\users.csv"
        Gets all users from file. EmailAddress header is required.

#>
    [CmdletBinding()]
    param (
        [string] $logpath = 'HIBP.log',
        [string] $filepath
    )
    
    begin{
        # init log
        $datetime = Get-Date -Format yyyy-MM-ddThh:mm:ss
        Out-File -FilePath $logpath -Append -InputObject ( "*********************" )
        Out-File -FilePath $logpath -Force -InputObject "Get-HIBPUsers executing at $datetime..." -Append
    }
    
    process{
        # get active users file to process and validate
        # if an AD user file was specified
        if($filepath){
            Out-File -FilePath $logpath -Append -InputObject "Using file at $filepath"
            $HIBPUsers = Import-CSV ($filepath) -Delimiter ','
        }
        else{
            # get all AD users that are enabled & have an email address
            Out-File -FilePath $logpath -InputObject "Fetching all enabled user from Active Directory..." -Append
            $HIBPUsers = Get-ADUser -Filter { ( Enabled -eq $true ) -and ( EmailAddress -ne $false ) } -Properties SamAccountName, DisplayName, EmailAddress, Title, Enabled | Select SamAccountName, DisplayName, EmailAddress, Title, Enabled
            Out-File -FilePath $logpath -InputObject ( ($HIBPUsers.count).ToString() + " enabled AD users found at " + ( Get-Date -Format MMddyyyymmss ) ) -Append
            Out-File -FilePath $logpath -InputObject ( "Get-ActiveADUsers completed at " + ( Get-Date -Format MM-dd-yyyyTmm:ss ) ) -Append
        }
  
        # validate the active user list
        if($HIBPUsers){
            Out-File -FilePath $logpath -Append -InputObject ( "Successfully imported " + $HIBPUsers.count + " HIBPUsers for processing." )
        }
        else {
            # user import failed
            Out-File -FilePath $logpath -Append -InputObject ( "Failed to import HIBPUsers for processing. Aborting Script." )
            break
        }
    }
    
    end {
        return $HIBPUsers
        Out-File -FilePath $logpath -Append -InputObject ( "Get-HIBPusers End" )
        Out-File -FilePath $logpath -Append -InputObject ( "*********************" )
    }
}
function Get-HIBPUsersByBreach {
<#
.SYNOPSIS
    Gets all AD users from an organization and verifies they are in breaches posted on haveibeenpwned in a given dayperiod.

.DESCRIPTION
    Wrapper function for Get-HIBPUsers and Get-HIBPBreaches. Gets all AD users from an organization and verifies they 
    are in breaches posted on haveibeenpwned in a given dayperiod.Returns an object containing the breaches with arrays 
    of confirmed pwned users in each respective breach's array.

.PARAMETERS
    -logpath
        [string] Path to file to write log infos.
    -HIBPUsers
        [array] List of organization user's email addresses for processes against haveibeenpwned.com.
    -HIBPBreaches
        [array] Collection of breach data objects from a specified dayperiod.
    -breachExportPath
        [string] Path to store breach JSON data with confirmed pwned users.

.OUTPUTS
    $HIBPUsersByBreach
        [object] Hashtable of breach arrays. Breach arrays contain confirmed pwned organization users from specified breaches in the given dayperiod.

.EXAMPLE
   Get-HIBPUsersByBreach 
        Gets all enabled Active Directory user EmailAddress values for the organization, sorts by breaches in the default dayperiod -1 (within the last day).
            
    Get-HIBPUsersByBreach -HIBPUsers (Get-HIBPUsers -logpath $logpath -filepath ".\users.csv) -HIBPBreaches (Get-HIBPBreaches -dayperiod -365 -HIBPToken (Get-HIBPToken -logpath $logpath) -logpath $logpath ) -HIBPToken (Get-HIBPToken) -logpath $logpath
         Gets all users from a CSV with EmailAddress values, sorts by breaches from the last 365 days, and exports JSON files for each breach. 
#>
    [CmdletBinding()]
    param (
        [string] $logpath = 'HIBP.log',
        $HIBPUsers = (Get-HIBPUsers),
        $HIBPBreaches = (Get-HIBPBreaches),
        $HIBPToken = (Get-HIBPToken),
        $breachExportPath = ".\breaches\"
    )
    
    begin {
        # web request stuffs
        $userAgent = 'HaveIBeenPwned Breach Powershell Script'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $breachURI = "https://haveibeenpwned.com/api/v3/breachedaccount/"
        $headers = @{'hibp-api-key'= $HIBPToken}
        
        # init log
        $datetime = Get-Date -Format yyyy-MM-ddThh:mm:ss
        Out-File -FilePath $logpath -Append -InputObject ( "*********************" )
        Out-File -FilePath $logpath -Append -InputObject ( "Get-HIBPUsersByBreach executing at $datetime..." )
    }
    
    process {

        # create a hasthtable of arrays for each breach to store users later
        $HIBPUsersByBreach = @{}
        foreach($breach in $HIBPBreaches.Name){
            $HIBPUsersByBreach += @{
                $breach = @() 
            }
        }

        # process each user
        For ( $i = 0; $i -lt $HIBPUsers.length; $i++ ) {

            # begin processing individual user
            Out-File -FilePath $logpath -Append -InputObject ("***")
            
            # web request stuffs
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $pwnedURI = $breachURI + $HIBPUsers[$i].EmailAddress + "?truncateResponse=false" # the truncateReponse value must be false as of API v3
            Out-File -FilePath $logpath -Append -InputObject ( "User " + ( $i + 1 ) + " of " + $HIBPUsers.length + ". Checking " + $HIBPUsers[$i].SamAccountName + " for pwnage at $pwnedURI" ) 

            try {
                # check haveibeenpwned.com against the user. If an object is returned and not a 404 error, the user was found in a breach
                $pwned = Invoke-RestMethod -Uri $pwnedURI -UserAgent $userAgent -Headers $headers
                
                   if ($pwned) { 
                    Out-File -FilePath $logpath -Append -InputObject ( "User " + $HIBPUsers[$i].SamAccountName + ' was found in at least one historical breach. Checking if in any specified breach...' ) 
                    $pwned | ForEach-Object {
                        if ( ( $HIBPBreaches.Name ).contains( $_.Name ) ) {
                            $HIBPUsersByBreach.($_.Name) += $HIBPUsers[$i].EmailAddress
                            Out-File -FilePath $logpath -Append -InputObject ( "User " + $HIBPUsers[$i].SamAccountName + ' was <!! pwned !!> in a breach inside the target scope: *' + $_.Name + '*. Marked for processing.' ) 
                        }
                        else {
                            Out-File -FilePath $logpath -Append -InputObject ( "User " + $HIBPUsers[$i].SamAccountName + ' was found in a non-specified breach ' + $_.Name + ' outside of the target scope. Disregarding...'  ) 
                        }
                    }
                }
                else {
                    # user not found in specified breaches
                    Out-File -FilePath $logpath -Append -InputObject ( "User " + $HIBPUsers[$i].SamAccountName + ' was not found in any specified breach.' ) 
                }     
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                $FailedItem = $_.Exception.ItemName
                Out-File -FilePath $logpath -Append -InputObject ("There was an error checking " + $HIBPUsers[$i].EmailAddress + ' :' + $ErrorMessage)
                Out-File -FilePath $logpath -Append -InputObject ( "User " + $HIBPUsers[$i].SamAccountName + ' was not found in any specified breach.' ) 
            }

            # wait 1600 miliseconds between loop iterations to prevent throttling from the server (1500 is the minimum per ihavebeenpwned.com)
            Start-Sleep -m 1600
        }

        $HIBPUsersByBreach =  Get-Content -Path HIBP\HIBPUsersByBreach.json | ConvertFrom-Json
        $HIBPUsersByBreach | ConvertTo-Json -Depth 10| Out-File -FilePath "HIBPUsersByBreach.json" # file for automations
        $HIBPUsersByBreach.Psobject.Properties.Name | ForEach-Object{ # files for records
            if($HIBPUsersByBreach.$_ -ne ''){
                $HIBPUsersByBreach.$_ | ConvertTo-Json -Depth 10| Out-File -FilePath ("$breachExportPath" +$datetime.Substring(0,10) + "-" + $_ + ".json")
            }
        }
    }
    
    end {
        return $HIBPUsersByBreach
        Out-File -FilePath $logpath -Append -InputObject ( "Get-HIBPUsersByBreach End" )
        Out-File -FilePath $logpath -Append -InputObject ( $HIBPUsersByBreach )
        Out-File -FilePath $logpath -Append -InputObject ( "*********************" )
    }
}
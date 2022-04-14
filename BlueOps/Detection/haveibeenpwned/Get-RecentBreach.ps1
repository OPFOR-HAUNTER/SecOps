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
        $dayperiodDate =  (get-date).AddDays($dayperiod)
        $dayperiodDate =  get-date $dayperiodDate -Format yyyy-MM-ddThh:mm:ss

        # configure connection URI and settings
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # try to get breach info
        $breachesURI = "https://haveibeenpwned.com/api/v2/breaches"
        
        # initialize log
        Out-File -FilePath $logPath -Append -InputObject ( "*********************************************" )
        Out-File -FilePath $logPath -Force -InputObject "Getting recent breaches info for $today back to $dayperiodDate" -Append

        # create array for breach objects to return
        $recentBreaches =  @()
    }
    
    process {

        try{
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

                    } else {
                        Out-File -FilePath $logPath -Force -Append -InputObject ( 'Breach ' + $_.Name + ' was added in the specified interval of ' + $intervalAmount + 'but did not contain any compromised passwords.' )
                    }
               }
            }
           
        }catch{
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
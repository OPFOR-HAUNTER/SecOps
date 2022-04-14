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
        if ( $breaches ){
            Out-File -FilePath $logPath -Append -InputObject ( "*********************************************" )
            Out-File -FilePath $logPath -Append -InputObject ("Identified " + $breaches.count + " breaches. Ready for processing.")
            Out-File -FilePath $logPath -Force -InputObject ( "Returning breaches..." ) -Append
            return $breaches
            # Out-File -FilePath $logPath -Append -InputObject ($breaches)
        }else{
            Out-File -FilePath $logPath -Append -InputObject ( "Could not get breach info, aborting script." )
            break 
        }
    }
}
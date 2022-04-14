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
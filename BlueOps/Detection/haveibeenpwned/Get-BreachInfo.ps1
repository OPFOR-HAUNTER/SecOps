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
        try{
            $breach = Invoke-RestMethod -Uri $breachURI -UserAgent $userAgent
            Out-File -FilePath $logPath -Append -InputObject ( "*********************************************" )
            Out-File -FilePath $logPath -Force -InputObject "Getting breach info for $breachName at $breachURI" -Append
        }catch{
            $ErrorMessage = $_.Exception.Message
            $FailedItem = $_.Exception.ItemName
            Out-File -FilePath $logPath -Append -InputObject ("There was an error checking " + $breachName + ' :' + $ErrorMessage)
        }
    }
    end {
        return $breach
    }
}
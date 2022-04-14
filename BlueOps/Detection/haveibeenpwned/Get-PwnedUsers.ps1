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
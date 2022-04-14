function Send-PwnedEmail {
    [CmdletBinding()]
    param (
        [string] $logPath = 'Send-PwnedEmail.log',
        [string] $to = 'informationsecurity@arb.ca.gov',
        $breach,
        $pwnedUsers = @(),
        $filePath,
        [switch] $passwordReset,
        [switch] $dryrun
    )
    
    begin {
        $usersFromFile = Import-CSV -Path ($PSScriptRoot + '\' + $filePath)
        $breach = Get-Breachinfo -breachName $breach
        $smtp = 'smtp.office365.com'
        $port = '587'
        $to = $to
        $cc = ''
        $bcc = ''
        $from = $to

    }
    process {
        # construct email
        $emailMessage = New-Object System.Net.Mail.MailMessage( $from , $to )
        $subject = $breach.Name + " Breach Advisory"
        if($passwordReset) {
            $subject += " - Password Reset Required"
        }
    
        if ($pwnedUsers -ne $false){
            $pwnedUsers | ForEach-Object { 
                $emailMessage.bcc.add( $_.EmailAddress )
            }
        }elseif($filePath -ne $false){
            $usersFromFile | ForEach-Object { 
                $emailMessage.bcc.add( $_.EmailAddress )
            }
        }
    
        #$emailMessage.cc.add($emailcc)
        $emailMessage.Subject = $subject
        $emailMessage.Sender = 'informationsecurity@arb.ca.gov'
        $emailMessage.ReplyTo =  'informationsecurity@arb.ca.gov'
        $emailMessage.IsBodyHtml = $true #true or false depends
        $SMTPClient = New-Object System.Net.Mail.SmtpClient( $smtp , $port )
        $SMTPClient.EnableSsl = $True
        $credential = Get-Credential
        $SMTPClient.Credentials = New-Object System.Net.NetworkCredential( $credential.UserName , $credential.Password, 'arb.ca.gov' );

        # build body message
        $emailMessage.Body = "The CARB Security Operations Center has received an indication that your work email address was included in a data breach from the third-party organization named <em>" + $breach.name + "</em>.<br/<br/>

 

          The breach included sensitive information including password hashes. It is CARB policy that passwords associated to emails compromised by breaches must be reset. Also, CARB policy dictates that work email addresses must not be utilized for personal accounts.<br/><br/>"
          
         # if user's passwords were reset  
          if ($passwordReset){
            $emailMessage.Body += "Your password will be reset upon your next login.<br/><br/>"
          }
           
          
          $emailMessage.Body += "Please review password best-practices here: <a href='http://inside.arb.ca.gov/is/security/?p=135'> Air Resources Board - Password Best-Practices</a><br/><br/>
          
          The details for the <em>" + $breach.Name + "</em> breach are as follows:<br/>
          <table>
            <theader><td>Breach</td><td>" + $breach.Name + "</td></theader>
            <tr><td>Domain</td><td>" + $breach.Domain + "</td></tr>
            <tr><td>Breach Date</td><td>" + $breach.BreachDate + "</td></tr>
            <tr><td>Published Date</td><td>" + $breach.AddedDate + "</td></tr>
            <tr><td>Total Exposed Accounts</td><td>" + $breach.PwnCount + "</td></tr>
            <tr><td>Info Exposed</td><td>" + $breach.DataClasses + "</td></tr>
            <tr><td>Breach Details</td><td>" + $breach.Description + "</td></tr>
          </table>"
    }
    
    end {
        # send pwned email
        if ($dryrun -eq $false){
            Out-File -FilePath $logPath -Force -InputObject "Sending email to recipients..."
            $SMTPClient.Send( $emailMessage )
        }else{
            Out-File -FilePath $logPath -Force -InputObject "Dryrun mode enabled, not sending email to recipients."           
        }
        Out-File -FilePath "pwnedEmail.html" -Force -InputObject $emailMessage
    }
} 
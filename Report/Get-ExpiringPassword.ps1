function Get-ExpiringPassword {
    <#
    .SYNOPSIS
        Get a list of users that have expired passwords for the day.

    .DESCRIPTION
        Get a list of users that have expired passwords for the day.
    .EXAMPLE
        PS C:\> Get-ExpiringPasswords
        Get a list of users that have expired passwords for the day.
    #>

    [CmdletBinding()]
    param (
        [parameter(DontShow = $true)]
        $email = @{
            From = 'Share_Update@Business.com'
            To = @('HelpDesk@Business.com')
            subject = ""
            body = ""
            smtpServer = 'relay.Namehere.root.local'
        }
    )
    
    begin {
        $date = (Get-Date).ToString("MM-dd-yyyy")

        $Properties = @(
            "DisplayName",
            "SamAccountName", 
            "msDS-UserPasswordExpiryTimeComputed"
        )

        $email.subject = "$date Expiring Passwords:"
    }
    
    process {
        $email.body = ((Get-ADUser -filter {Enabled -eq $True -and PasswordNeverExpires -eq $False -and PasswordLastSet -gt 0}  -Properties $Properties |  
            Select-Object -Property "Displayname","SamAccountName",@{Name="ExpiryDate";Expression={[datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed")}} | 
            Sort-Object displayname | Where-Object {$_.ExpiryDate -match (get-date).ToShortDateString()} | format-list)) | Out-String
    }
    
    end {
        if (!([string]::IsNullOrWhiteSpace($email.body))){
            send-mailmessage @email
        }
    }
}
Get-ExpiringPassword
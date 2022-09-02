# Set variables. Best to use a temporary SMTP account and password to prevent abuse after use of script is complete.
# Designed to be deployed via Intune to get Autopilot hash to re-import.

$FolderName = "C:\Autopilot\"
$email = "email@domain.com"
$sender = "noreply@domain.com"
$smtp = "smtp.sendgrid.net"
$smtpuser = "apikey"
$smtppass = "{sendgridtoken}"

#Create folder if required

if(Get-Item -Path $FolderName -ErrorAction Ignore)
{
    #Skip create directory if exists.
    Write-Host "$FolderName Folder already exists."
}
else
{
    #Create directory if not exists
    Write-Host "Creating Folder $FolderName"
    New-Item $FolderName -ItemType Directory
}

#Install Autopilot script and get hash
Set-Location -Path $FolderName
$env:Path += ";C:\Program Files\WindowsPowerShell\Scripts"
$filename = "$env:computername.csv"
Install-Script -Name Get-WindowsAutopilotInfo
Get-WindowsAutopilotInfo -OutputFile $filename

#Get current intune enrollment status
$Dsregcmd = New-Object PSObject ; Dsregcmd /status | Where {$_ -match ' : '}|ForEach {$Item = $_.Trim() -split '\s:\s'; $Dsregcmd|Add-Member -MemberType NoteProperty -Name $($Item[0] -replace '[:\s]','') -Value $Item[1] -EA SilentlyContinue}
$intuneoutput = $Dsregcmd -replace ";", "<br>"

## Build parameters for Email
$secpasswd = ConvertTo-SecureString $smtppass -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential ($smtpuser, $secpasswd)
$mailParams = @{
    SmtpServer                 = $smtp
    Port                       = '25'
    UseSSL                     = $true
    BodyAsHtml                 = $true
    From                       = $noreply
    To                         = $Email
    Subject                    = "Device $filename Autopilot Hash Attached $(Get-Date -Format g)"
    Body                       = $FolderName + $filename + '<br><br>' + $intuneoutput
    DeliveryNotificationOption = 'OnFailure', 'OnSuccess'
    Attachments                = $FolderName + $filename
}

## Send the email with CSV attachment
Send-MailMessage -Credential $creds @mailParams
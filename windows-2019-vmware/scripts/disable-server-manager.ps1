Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

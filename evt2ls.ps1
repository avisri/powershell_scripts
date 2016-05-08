#
# evt2ls.ps1
#
# Send Windows Event logs to a remote LogStash instance
# Note:Required PowerShell V3
#
# Author: Xavier Mertens <xavier(at)rootshell(dot).be>
# Copyright: GPLv3 (http://gplv3.fsf.org)
# Feel free to use the code but please share the changes you've made
#

#Requirements
# 1.Get-WinEvent   [https://technet.microsoft.com/en-us/library/hh849682.aspx]
# 2.ConvertTo-Json [https://technet.microsoft.com/en-us/library/hh849922.aspx]

#optional  Note
#Windows security audit events -[https://www.microsoft.com/en-us/download/confirmation.aspx?id=50034 ]

#Sample event codes 
#Event code	Description
############################
#512 / 4608 	STARTUP
#513 / 4609 	SHUTDOWN
#528 / 4624	LOGON
#538 / 4634	LOGOFF
#551 / 4647	BEGIN_LOGOFF
#N/A / 4778 	SESSION_RECONNECTED
#N/A / 4779 	SESSION_DISCONNECTED
#N/A / 4800	WORKSTATION_LOCKED
#*   / 4801 	WORKSTATION_UNLOCKED
#N/A / 4802	SCREENSAVER_INVOKED
#N/A / 4803	SCREENSAVER_DISMISSED

#Note
#https://social.technet.microsoft.com/Forums/scriptcenter/en-US/31817f79-cb3f-4451-bfe8-e8ff8678b806/powershell-schedule-task-and-infnity-loop?forum=ITCG
#not using loops as they are killed after 2 days :P, 
#Will Need a simple cron like schduler which runs every min as default 


Function Dump2Logstash {
	param (
		[ValidateNotNullOrEmpty()]
		[string] $server,
		[int] $port,
		$jsondata)

	$ip = [System.Net.Dns]::GetHostAddresses($server)
	$address = [System.Net.IPAddress]::Parse($ip)
	$socket = New-Object System.Net.Sockets.TCPClient($address, $port)
	$stream = $socket.GetStream()
	$writer = New-Object System.IO.StreamWriter($stream)

	# Convert the existing data into a JSON array to process events one by one
	$buffer = '{ "Events": ' + $jsondata + ' }' | ConvertFrom-Json
	foreach($event in $buffer.Events) {
		echo "Processing:"
		echo $event
		# Convert to a 1-line JSON event
		$x = $event | ConvertTo-Json -depth 3
		$x= $x -replace "`n",' ' -replace "`r",''

		$writer.WriteLine($x)
		$writer.Flush()
	}
	$stream.Close()
	$socket.Close()
}

###########MAIN#####################
param (
    #set your default like logstash server, port, time  here 
    [string]$LOGSTASH_SERVER = "logstash",
    [int]$LOGSTASH_PORT = 5001,
    [int]$mins   =1,
    [int]$window =1,
    [string]$logname="*",
    [int[]]$IDs= @(0)
)

# Send events from the startime.   
[System.DateTime]$starttime = (get-date).AddMinutes(-$mins).date()
#[System.DateTime]$endtime =   starttime.AddMinutes($window)
if ( $IDs[0] -eq 0 ){
	#get all IDS
	$data = Get-WinEvent -FilterHashtable @{logname=$logname; StartTime=$starttime; } | ConvertTo-Json -depth 3
}
else{
	#TODO : test! 
	$data = Get-WinEvent -FilterHashtable @{logname=$logname; starttime=$starttime; ID=$IDs } | ConvertTo-Json -depth 3
}	
Dump2Logstash $LOGSTASH_SERVER $LOGSTASH_PORT "$data"
#echo "Done!"

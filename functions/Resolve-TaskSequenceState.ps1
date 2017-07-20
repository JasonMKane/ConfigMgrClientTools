function Resolve-TaskSequenceState {
    [cmdletbinding(DefaultParameterSetName = 'RemoteTarget')]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = 'RemoteTarget')]
        [string]$ComputerName = 'LocalHost',

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]$LogPath
    )

    

    $SMSTSLog = @();
    $SMSLogFiles = @();

    $SMSTSLogLocations = @(
        "C:\_SMSTaskSequence\logs\smstslog\"
        , "C:\Windows\CCM\Logs\"
        , "C:\Temp\Logs\"
    )

    if ($PSCmdlet.ParameterSetName -eq 'RemoteTarget') {
        Write-Host "Identifying log locations on $ComputerName" -ForegroundColor Green;
        Foreach ($Loglocation in $SMSTSLogLocations) {
            $LogParsePath = $Loglocation;

            if ($ComputerName -ne 'LocalHost') {
                $LogParsePath = $Loglocation -replace 'C:', "\\$ComputerName\C$";
            }

            if (Test-Path $LogParsePath) {
                $SMSLogFiles += Get-ChildItem -Path $LogParsePath -Filter "SMSTS*.log";
            }
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'File') {
        if (!(Test-Path $LogPath)) {
            throw 'Path not found!';
            return;
        }
        if ($(Get-Item $LogPath).PSIsContainer) {
            $SMSLogFiles += Get-ChildItem -Path $LogPath -Filter "SMSTS*.log";
        }
        else {
            $SMSLogFiles += Get-Item $LogPath;
        }
    }

    if ($SMSLogFiles.Count -eq 0) {
        Write-Host "No Log files were found!  The client is offline or SCCM was not used to image this client." -ForegroundColor Red;
        return;
    }


    Write-Host "Found $($SMSLogFiles.count) Task Sequence Logs on $ComputerName" -ForegroundColor Green;
    Write-Host "Collating and parsing Logs from $ComputerName.  This may take a minute or two, possibly longer over network connections.  You may also see parse errors.  Sometimes the resultant log is non-standard." -ForegroundColor Green;

    Foreach ($SMSTS in $SMSLogFiles) {
    
        $SMSTSLog += Import-ConfigMgrLog $SMSTS.FullName;
    }

    $NameLog = $SMSTSLog | ? { $_.Message -like 'Computer Name: *' } | Sort-Object -Descending -Property Date | select -First 1
    if ($Namelog -eq $null) {
        $NameLog = $SMSTSLog | ? { $_.Message -like '*Netbios name: *' } | Sort-Object -Descending -Property Date | select -First 1
    }

    $ImagedComputerName = $NameLog.Message.Substring($NameLog.Message.IndexOf(':') + 2);

    Write-Host "Client Name Used: $ImagedComputerName";
    Write-Host "Checking Active Directory for $ImagedComputerName";

    $search = [adsisearcher]"(&(CN=$ImagedComputerName)(objectclass=computer))"
    $SearchResult = $search.findone();

    if ($SearchResult -ne $null) {
        Write-Host "AD account verified.";
    }
    else {
        Write-Host "NO AD ACCOUNT FOUND!" -ForegroundColor Yellow;
    }

    Write-Host "Finding Task Sequence exit amoung $($SMSTSLog.Count) log entries";
    $Matches = $null;
    $TSComplete = $SMSTSLog | ? { $_.Message -like 'Task Sequence Completed*' } | Sort-Object -Descending -Property Date | select -First 1;
    $TSComplete.Message -match '0x[0-9a-fA-F]{8}' | Out-Null;

    [string]$TSExitCode = $Matches.Values;

    if ($TSExitCode -eq $null -or $TSExitCode.Length -eq 0) {
        Write-Host "Your Task Sequnece never started.  Please check your connections.";
        $TSExitCode = 'Task Seqennce Not started, or failed to finish properly.'
    }


    Write-Host "Task Sequence Exit Code: $TSExitCode";

    if ($TSExitCode -eq "0x00000000") {
        Write-Host 'Your Task Sequence completed successfully!' -ForegroundColor Green;
    }
    else {
        Write-Host 'Your Task sequence failed' -ForegroundColor red;

        switch ($TSExitCode.ToUpper()) {
            "0x80004004" { Write-Host "Application failed to enforce." -ForegroundColor red }
            "0x80072EE7" { Write-Host "Network error occured Check your connection" -ForegroundColor red }
            "0x87D00269" { Write-Host "Management Point not found.  Check your network connection" -ForegroundColor red }
            "0x8007000F" { Write-Host "Hard Drive not found.  Check file system type and verify drive is not encrypted." -ForegroundColor red  }
            "0x80004005" { Write-Host "This is a generic error.  Most cases this is caused by an application that failed to install.  Check the AppEnforce.log" -ForegroundColor red }
        }
    }
}
function Import-ConfigMgrLog {
    [cmdletBinding()]

        param([Parameter(Mandatory = $true)]$Path)

        $contents = Get-Content $Path

        $contents = $contents -replace '(?:\s|\r|\n)', ' ';

        $logObjects = @();
        $logEntries = $MatchLine = ([regex]'(?<=\<!).*?(?=c[a-zA-Z]{2}:[0-9]{1,}"\>)').matches($contents)
        $EntryTotal = $logEntries.Count;
        $WorkingSet = 0;
    
        Foreach ($group in $logEntries.Groups) {
        
            #Write-Host 'ReadingLine' -ForegroundColor Yellow;
            $line = $group.value;
    
            $MatchLine = ([regex]'(?<=\[LOG\[).*?(?=\]LOG\]!\>)').matches($line);
            $LogString = $MatchLine.Groups.Value.Trim();
    
            #take the message out of the log string to not interfere with the rest of the regular expressions.
            if ($LogString.Length -gt 0) { $line = $line.Replace($LogString, ''); }

            $MatchLine = ([regex]'(?<=time=").*?(?=")').matches($line);
            $TimeString = $MatchLine.Groups.Value;

            $MatchLine = ([regex]'(?<=date=").*?(?=")').matches($line);
            $DateString = $MatchLine.Groups.Value;

            $MatchLine = ([regex]'(?<=component=").*?(?=")').matches($line);
            $ComponentString = $MatchLine.Groups.Value;

            $MatchLine = ([regex]'(?<=type=").*?(?=")').matches($line);
            $SeverityString = $MatchLine.Groups.Value;
        
            $DateTime = Get-Date "$DateString $($TimeString.Substring(0, $TimeString.IndexOf('+')))";

            $EntryObject = New-Object psobject -Property @{Message = $LogString; Date = $DateTime; Component = $ComponentString; Severity = $SeverityString }
    
            $LogObjects += $EntryObject;
            $WorkingSet++;
        }
        Write-Output $logObjects;
    }
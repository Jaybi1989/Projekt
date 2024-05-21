#Mein erstes Script mit Powershell fuer eine Versionierung von Dateien ohne Anbindung zu einem Github
# Funktion zum Auswahl eines Verzeichnisses oder einer Datei
function Select-Item {
    param (
        [string]$prompt = "Bitte waehlen Sie eine Datei oder ein Verzeichnis.",
        [string]$path = (Get-Location),
        [switch]$isFolder = $false
    )

    $selection = if ($isFolder) {
        Get-ChildItem -Path $path -Directory | Out-GridView -Title $prompt -PassThru
    } else {
        Get-Item -Path (Get-ChildItem -Path $path | Out-GridView -Title $prompt -PassThru).FullName
    }

    return $selection
}

# Funktion zur Protokollierung von Aenderungen
function Log-Changes {
    param (
        [string]$path,
        [string]$changeType
    )

    $logEntry = "{0} - {1}: {2}" -f (Get-Date), $changeType, $path
    Add-Content -Path "ChangeLog.txt" -Value $logEntry

    if ($changeType -eq "Aenderung") {
        Create-Version -path $path
    }
}

# Funktion zum Erstellen einer neuen Version der Datei
function Create-Version {
    param (
        [string]$path
    )

    $versionDirectory = "Versionen"
    if (-not (Test-Path -Path $versionDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $versionDirectory | Out-Null
    }

    $timestamp = (Get-Date -Format "yyyyMMdd_HHmmss")
    $versionedFilePath = Join-Path $versionDirectory ($timestamp + "_" + (Split-Path $path -Leaf))

    Copy-Item -Path $path -Destination $versionedFilePath
    Write-Host "Neue Version erstellt: $versionedFilePath"
}


# Funktion zum Anzeigen des Versionsverlaufs einer Datei
function Show-Version-History {
    param (
        [string]$path
    )

    $versionDirectory = "Versionen"
    $versions = Get-ChildItem -Path $versionDirectory -Filter (Split-Path $path -Leaf) | 
                Sort-Object LastWriteTime -Descending |
                ForEach-Object {
                    [PSCustomObject]@{
                        Timestamp = $_.BaseName -split ('_')[0]
                        Version   = $_.Name
                        FullPath  = $_.FullName
                    }
                }

    if ($versions.Count -gt 0) {
        Write-Host "Versionsverlauf von $path"
        $versions | Format-Table -AutoSize
    } else {
        Write-Host "Es gibt keine frueheren Versionen von $path."
    }
}


# Funktion zum Wiederherstellen einer frueheren Version einer Datei
function Restore-Version {
    param (
        [string]$path,
        [string]$timestamp
    )

    $versionDirectory = "Versionen"
    $versionedFilePath = Join-Path $versionDirectory ($timestamp + "_" + (Split-Path $path -Leaf))

    if (Test-Path $versionedFilePath) {
        Copy-Item -Path $versionedFilePath -Destination $path -Force
        Write-Host "Datei erfolgreich wiederhergestellt: $path"
    } else {
        Write-Host "Die angegebene Version existiert nicht."
    }
}

# Auswahl einer Datei oder eines Verzeichnisses
$ausgewaehltes_item = Select-Item -prompt "Waehlen Sie eine Datei oder ein Verzeichnis zum Ueberwachen aus."

# Ueberpruefen, ob das ausgewaehlte Element existiert
if (Test-Path $ausgewaehltes_item.FullName) {
    # Initialisieren des FileSystemWatcher
    $fileSystemWatcher = New-Object System.IO.FileSystemWatcher
    $fileSystemWatcher.Path = $ausgewaehltes_item.FullName
    $fileSystemWatcher.IncludeSubdirectories = $true
    $fileSystemWatcher.EnableRaisingEvents = $true

    # Event Handler fuer Aenderungen
    $onChange = Register-ObjectEvent -InputObject $fileSystemWatcher -EventName Changed -Action {
        $path = $eventArgs.FullPath
        Log-Changes -path $path -changeType "Aenderung"
    }

    # Timer fuer periodische Ueberpruefung
    $timer = New-Object System.Timers.Timer
    $timer.Interval = 60000  
    $timer.Enabled = $true

    # Event Handler fuer Timer
    $onTimerElapsed = Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
        Write-Host "Periodische Ueberpruefung..."
        Get-ChildItem -Path $ausgewaehltes_item.FullName -Recurse | ForEach-Object {
            Log-Changes -path $_.FullName -changeType "Periodische Ueberpruefung"
        }
    }

    Write-Host "Ueberwache Aenderungen in $($ausgewaehltes_item.FullName). Druecken Sie 'Ctrl + C', um die Ueberwachung zu beenden."
    Write-Host "Verwenden Sie 'Show-Version-History -path <Dateipfad>' zum Anzeigen des Versionsverlaufs."
    Write-Host "Verwenden Sie 'Restore-Version -path <Dateipfad> -timestamp <Zeitstempel>' zum Wiederherstellen einer frueheren Version

    # Warten, bis das Skript beendet wird
    try {
        Wait-Event -Timeout ([TimeSpan]::MaxValue)
    } finally {
        # Aufraeumen und Event Handler entfernen
   #auskommentiert $onChange | Unregister-Event
   #auskommentiert $onTimerElapsed | Unregister-Event
   #auskommentiert $onChange.Action.Dispose()
   #auskommentiert $onTimerElapsed.Action.Dispose()
   #auskommentiert $fileSystemWatcher.Dispose()
   #auskommentiert $timer.Dispose()
    }
} else {
    Write-Host "Das ausgewaehlte Element existiert nicht."
}
# Installs the BIMCraft plugin bimcraft-scripts 0.2.0 into the user's plugins folder.
#
# Run it from the delivery site:
#     iwr -useb <site>/v1/install.ps1 | iex
#
# Environment:
#     BIMCRAFT_PLUGINS          the plugins folder to use; an empty value means plugins are off
#     BIMCRAFT_INSTALL_YES      set to 1 to skip the confirmation prompt (automation)
#     BIMCRAFT_INSTALL_NO_PAUSE set to 1 to skip the final pause
#
# The archive is checked against its SHA-256 before anything lands where the application
# reads plugins. An earlier install of the same plugin is moved aside, not deleted.

#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PluginId = 'bimcraft-scripts'
$PluginVersion = '0.2.0'
$ArchiveUrl = 'https://github.com/dronov-dmitry/bimcraft-run-scripts/releases/download/v0.2.0/bimcraft-scripts-0.2.0.zip'
$ArchiveSha256 = 'f5348a02fc7a3367259c55e6d130700e0a8ec6259c85c5b55dc5838323d52518'

function Pause-IfInteractive {
    if ($env:BIMCRAFT_INSTALL_NO_PAUSE -ne '1') {
        Read-Host 'Press Enter to close this window...' | Out-Null
    }
}

function Fail([string] $Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    Pause-IfInteractive
    exit 1
}

$plugins = [Environment]::GetEnvironmentVariable('BIMCRAFT_PLUGINS')
if ($null -ne $plugins) {
    if ([string]::IsNullOrWhiteSpace($plugins)) {
        Fail 'BIMCRAFT_PLUGINS is empty: plugins are disabled on this machine'
    }
} elseif ($env:APPDATA) {
    $plugins = Join-Path $env:APPDATA 'BIMCraft\plugins'
} else {
    Fail 'APPDATA is not set; set BIMCRAFT_PLUGINS to the plugins folder'
}

Write-Host "Plugin:  $PluginId $PluginVersion"
Write-Host "Folder:  $plugins"
Write-Host "Archive: $ArchiveUrl"

if ($env:BIMCRAFT_INSTALL_YES -ne '1') {
    $answer = Read-Host "Install $PluginId $PluginVersion into ${plugins}? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        # Enter alone means yes: the default is marked in the prompt.
        $answer = 'y'
    }
    if ($answer -notmatch '^(y|yes)$') {
        Fail 'the user cancelled the install'
    }
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ('bimcraft-install-' + [System.Guid]::NewGuid().ToString('n'))
$destination = Join-Path $plugins $PluginId

New-Item -ItemType Directory -Path $work | Out-Null
try {
    $archive = Join-Path $work 'plugin.zip'
    Write-Host 'Downloading...'
    Invoke-WebRequest -Uri $ArchiveUrl -OutFile $archive -UseBasicParsing

    $actual = (Get-FileHash -Path $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $ArchiveSha256) {
        Fail "the archive does not match its SHA-256: got $actual, expected $ArchiveSha256; nothing was installed"
    }

    $unpacked = Join-Path $work 'unpacked'
    Expand-Archive -Path $archive -DestinationPath $unpacked -Force
    if (-not (Test-Path (Join-Path $unpacked 'plugin.json'))) {
        Fail 'the archive has no plugin.json; nothing was installed'
    }

    New-Item -ItemType Directory -Path $plugins -Force | Out-Null
    if (Test-Path $destination) {
        $backup = "$destination.backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Move-Item -Path $destination -Destination $backup
        Write-Host "The earlier install was moved to $backup"
    }
    Move-Item -Path $unpacked -Destination $destination
} finally {
    if (Test-Path $work) {
        Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host "Installed: $destination" -ForegroundColor Green
Write-Host 'Restart BIMCraft: plugins are read when the application starts.'
Pause-IfInteractive

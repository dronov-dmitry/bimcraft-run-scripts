# Installs the BIMCraft plugin bimcraft-scripts 0.2.1 into the user's plugins folder.
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
# reads plugins. Every earlier copy of the same plugin is removed from the plugins folder:
# BIMCraft reads every subfolder that has plugin.json, so a leftover copy makes it report
# a second plugin with the same id as broken.

#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PluginId = 'bimcraft-scripts'
$PluginVersion = '0.2.1'
$ArchiveUrl = 'https://github.com/dronov-dmitry/bimcraft-run-scripts/releases/download/v0.2.1/bimcraft-scripts-0.2.1.zip'
$ArchiveSha256 = 'f97c40246d42bc749614ff56a78eb03b37b7f92cf318245c0645a82090270bda'

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

# Reads the plugin id from a folder's plugin.json; $null when the file is absent or broken,
# so a folder that only looks like a plugin is left alone.
function Get-PluginId([string] $Folder) {
    $manifest = Join-Path $Folder 'plugin.json'
    if (-not (Test-Path -Path $manifest -PathType Leaf)) {
        return $null
    }
    try {
        $json = Get-Content -Path $manifest -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
    if ($null -eq $json) {
        return $null
    }
    $property = $json.PSObject.Properties['id']
    if ($null -eq $property) {
        return $null
    }
    return [string] $property.Value
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
$staging = Join-Path $plugins ('.tmp-install-' + $PluginId + '-' + [System.Guid]::NewGuid().ToString('n'))

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

    # The new copy waits inside the plugins folder under a temporary name, so the final
    # move is a rename on the same volume: either the new install is in place or the
    # folder is unchanged.
    if (Test-Path $staging) {
        Remove-Item -Path $staging -Recurse -Force
    }
    Move-Item -Path $unpacked -Destination $staging

    # A copy left next to the new one is read as a second plugin with the same id, and
    # BIMCraft lists it as broken. Remove the old folder, its backups, and any folder
    # whose plugin.json declares the same id.
    $earlier = @(Get-ChildItem -Path $plugins -Directory -Force | Where-Object {
        $_.FullName -ne $staging -and (
            $_.Name -eq $PluginId -or
            $_.Name -like "${PluginId}.backup-*" -or
            $_.Name -like "${PluginId}.old-*" -or
            (Get-PluginId $_.FullName) -eq $PluginId
        )
    })
    foreach ($folder in $earlier) {
        Remove-Item -Path $folder.FullName -Recurse -Force
        Write-Host "Removed the earlier install: $($folder.FullName)"
    }

    Move-Item -Path $staging -Destination $destination
} finally {
    if (Test-Path $staging) {
        Remove-Item -Path $staging -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $work) {
        Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host "Installed: $destination" -ForegroundColor Green
Write-Host 'Restart BIMCraft: plugins are read when the application starts.'
Pause-IfInteractive

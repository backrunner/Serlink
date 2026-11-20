<#
.SYNOPSIS
  Launch smoke test for a packaged Serlink Windows bundle.

.DESCRIPTION
  Starts serlink.exe, waits for the first rendered frame (the window is shown
  only after Flutter draws), checks the process stays up, verifies a second
  launch hands off to the running instance, then closes the window and
  expects a clean exit. Writes a screenshot and the app's redacted diagnostic
  logs to -ArtifactsDir. Intended for disposable CI machines.

.EXAMPLE
  pwsh tool/smoke_test_windows.ps1 -Exe build\windows\x64\runner\Release\serlink.exe
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string]$Exe,
  [string]$ArtifactsDir = 'build\smoke',
  [int]$StartupTimeoutSeconds = 60,
  [int]$StableSeconds = 15
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Exe = (Resolve-Path $Exe).Path
New-Item -ItemType Directory -Path $ArtifactsDir -Force | Out-Null
$ArtifactsDir = (Resolve-Path $ArtifactsDir).Path

function Save-Screenshot([string]$Name) {
  try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $path = Join-Path $ArtifactsDir $Name
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose()
    Write-Host "Screenshot: $path"
  } catch {
    Write-Warning "Screenshot failed: $_"
  }
}

function Save-Logs {
  $logs = Join-Path $env:APPDATA 'BackRunner\Serlink\Serlink\logs'
  if (Test-Path $logs) {
    Copy-Item $logs (Join-Path $ArtifactsDir 'logs') -Recurse -Force
  }
}

$failure = $null
$app = Start-Process -FilePath $Exe -WorkingDirectory (Split-Path $Exe) -PassThru
try {
  $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
  while ($true) {
    $app.Refresh()
    if ($app.HasExited) { throw "Serlink exited during startup with code $($app.ExitCode)." }
    if ($app.MainWindowHandle -ne [IntPtr]::Zero) { break }
    if ((Get-Date) -gt $deadline) { throw "Serlink showed no window within $StartupTimeoutSeconds s." }
    Start-Sleep -Milliseconds 500
  }
  Write-Host "Window shown: '$($app.MainWindowTitle)'"
  if ($app.MainWindowTitle -ne 'Serlink') { throw "Unexpected window title '$($app.MainWindowTitle)'." }

  Start-Sleep -Seconds $StableSeconds
  $app.Refresh()
  if ($app.HasExited) { throw "Serlink exited after startup with code $($app.ExitCode)." }
  Save-Screenshot 'serlink-started.png'

  # A second launch must activate the running window and exit on its own.
  $second = Start-Process -FilePath $Exe -WorkingDirectory (Split-Path $Exe) -PassThru
  if (-not $second.WaitForExit(15000)) {
    $second.Kill()
    throw 'Second launch did not hand off to the running instance.'
  }
  $app.Refresh()
  if ($app.HasExited) { throw 'The first instance exited when a second launch started.' }
  Write-Host "Second launch handed off (exit code $($second.ExitCode))."

  if (-not $app.CloseMainWindow()) { throw 'Could not send close to the Serlink window.' }
  if (-not $app.WaitForExit(20000)) { throw 'Serlink did not exit within 20 s of closing its window.' }
  Write-Host "Serlink closed cleanly (exit code $($app.ExitCode))."
} catch {
  $failure = $_
  Save-Screenshot 'serlink-failure.png'
} finally {
  if (-not $app.HasExited) { $app.Kill() }
  Save-Logs
}

if ($failure) { throw $failure }
Write-Host 'Smoke test passed.'

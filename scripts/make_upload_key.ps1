# Makes the upload key that signs Scorched Knight for Google Play, once.
#
# Run from the project folder (C:\scorchedknight):
#   powershell -ExecutionPolicy Bypass -File scripts\make_upload_key.ps1
#
# It:
#   1. asks you for a password (you type it; nobody else sees it),
#   2. makes the key in your user folder, outside the project, so it's never committed:
#      %USERPROFILE%\ScorchedKnightKeys\upload-keystore.jks
#   3. writes android\key.properties so release builds on this PC are signed
#      (that file is in .gitignore and never committed),
#   4. prints the key's fingerprints for Firebase (so Google sign-in works in release builds).
#
# Scorched Knight gets its own upload key, separate from The Calorie Card's: the same Play account
# is fine, but if one key ever leaks or is lost, only one game is affected.
# Keep a backup of the key file and its password (e.g. in your password manager). If you lose
# them, Google can reset the upload key, but it takes a few days.

$ErrorActionPreference = "Stop"

function Find-Keytool {
    $candidates = @()
    if ($env:JAVA_HOME) { $candidates += Join-Path $env:JAVA_HOME "bin\keytool.exe" }
    $candidates += "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    $candidates += "C:\Program Files\Android\Android Studio\jre\bin\keytool.exe"
    $candidates += "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe"
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    $onPath = Get-Command keytool -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    $jdks = Get-ChildItem "C:\Program Files\Java", "C:\Program Files\Eclipse Adoptium", "C:\Program Files\Microsoft" `
        -Directory -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName "bin\keytool.exe" } |
        Where-Object { Test-Path $_ }
    if ($jdks) { return @($jdks)[0] }
    return $null
}

function Read-Plain([string]$prompt) {
    $secure = Read-Host $prompt -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

$project = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $project "android\app\build.gradle.kts"))) {
    throw "Run this from the project: scripts\make_upload_key.ps1 inside C:\scorchedknight"
}

$keytool = Find-Keytool
if (-not $keytool) {
    throw "Couldn't find keytool (it comes with Java). Install Android Studio or a JDK 17 (e.g. adoptium.net), then run this again."
}

$dir = Join-Path $env:USERPROFILE "ScorchedKnightKeys"
$keystore = Join-Path $dir "upload-keystore.jks"
if (Test-Path $keystore) {
    throw "There's already an upload key at $keystore. Keep using it: a new one won't match what Google Play has."
}
New-Item -ItemType Directory -Force -Path $dir | Out-Null

Write-Host ""
Write-Host "Choose a password for Scorched Knight's upload key (at least 8 characters)."
Write-Host "Save it in your password manager."
$password = Read-Plain "Password"
if ($password.Length -lt 8) { throw "The password needs at least 8 characters." }
$again = Read-Plain "Same password again"
if ($password -ne $again) { throw "The passwords didn't match. Run it again." }

$alias = "upload"
& $keytool -genkeypair -v `
    -keystore $keystore -storetype PKCS12 `
    -keyalg RSA -keysize 2048 -validity 10000 `
    -alias $alias `
    -storepass $password -keypass $password `
    -dname "CN=Hayer Software Limited, O=Hayer Software Limited, C=GB" | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $keystore)) { throw "keytool couldn't make the key." }

# android\key.properties (never committed). Backslashes are escaped for Java's properties format.
function Esc([string]$s) { return $s.Replace("\", "\\") }
$props = @(
    "storeFile=$(Esc ($keystore.Replace('\', '/')))",
    "storePassword=$(Esc $password)",
    "keyPassword=$(Esc $password)",
    "keyAlias=$alias"
) -join "`n"
[IO.File]::WriteAllText((Join-Path $project "android\key.properties"), $props + "`n")

Write-Host ""
Write-Host "Done. Your upload key is at:"
Write-Host "  $keystore"
Write-Host "Back up that folder somewhere safe (not in the project)."
Write-Host ""
Write-Host "Fingerprints for Firebase (Scorched Knight project -> Project settings -> Android app -> Add fingerprint):"
& $keytool -list -v -keystore $keystore -storepass $password -alias $alias |
    Select-String -Pattern "SHA1:", "SHA256:" | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
Write-Host ""
Write-Host "Next: build_release.bat"

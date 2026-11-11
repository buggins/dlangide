# Packages a Windows build of DlangIDE as a .zip (#513).
#
# Run from the repository root after `dub build -b release --arch=<arch> [-c <config>]`:
#   pwsh windows/package.ps1 -Arch x86_64 [-Config freetype] [-Version v0.9.0] [-OutDir dist]
#
# The archive holds one folder, dlangide-<version>-windows-<arch>, with dlangide.exe, the mago-mi debugger
# for that architecture, libfreetype-6.dll when the build uses FreeType fonts (`freetype` configuration),
# licenses and a README.
param(
    [Parameter(Mandatory = $true)][ValidateSet("x86_64", "x86")][string]$Arch,
    [string]$Config = "default",
    [string]$Version = "",
    [string]$OutDir = "dist",
    [string]$BinDir = "bin"
)
$ErrorActionPreference = "Stop"

if (-not $Version) {
    $Version = (Get-Content "views/VERSION" -Raw).Trim()
}

# files of the build in bin/, and their source folder for licenses
$libs = "libs/windows/$Arch"
if ($Arch -eq "x86_64") {
    $binFiles = @("dlangide.exe", "mago-mi.exe", "udis86.dll", "msdia140.dll")
    $debugger = "This 64-bit package debugs 64-bit programs; 32-bit programs (DMD -m32)`r`nare not supported by the 64-bit mago-mi."
    $machine = 0x8664
} else {
    $binFiles = @("dlangide.exe", "mago-mi.exe", "MagoRemote.exe", "msdia140.dll")
    $debugger = "This 32-bit package debugs 32-bit and 64-bit programs; 64-bit programs run`r`nunder the MagoRemote.exe agent."
    $machine = 0x14c
}

# FreeType: only when the build uses FreeType fonts instead of the native Win32 font engine.
# dlangui's copyFiles puts libfreetype-6.dll into bin/ in either case. The versions of the build
# (DlangIDE's and those of its dependencies) tell whether USE_FREETYPE is set (#518).
$versions = & dub describe "--config=$Config" "--arch=$Arch" --build=release --data=versions --data-list
if ($LASTEXITCODE -ne 0) { throw "dub describe failed" }
$useFreeType = @($versions | ForEach-Object { $_.Trim() }) -contains "USE_FREETYPE"
if ($useFreeType) {
    $binFiles += "libfreetype-6.dll"
}

$name = "dlangide-$Version-windows-$Arch"
$stage = Join-Path $OutDir $name
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

foreach ($f in $binFiles) {
    $src = Join-Path $BinDir $f
    if (-not (Test-Path $src)) { throw "missing build output: $src" }
    Copy-Item $src $stage
}

# the executable must be built for the requested architecture
$bytes = [System.IO.File]::ReadAllBytes((Join-Path $stage "dlangide.exe"))
$pe = [BitConverter]::ToInt32($bytes, 0x3c)
$exeMachine = [BitConverter]::ToUInt16($bytes, $pe + 4)
if ($exeMachine -ne $machine) {
    throw ("dlangide.exe is built for machine 0x{0:x}, expected 0x{1:x} ({2})" -f $exeMachine, $machine, $Arch)
}

Copy-Item "LICENSE.txt" $stage
foreach ($f in @("mago-LICENSE.txt", "mago-NOTICE.txt", "udis86-LICENSE.txt")) {
    Copy-Item (Join-Path $libs $f) $stage
}
$freeTypeLicense = ""
if ($useFreeType) {
    Copy-Item "windows/FreeType-NOTICE.txt" $stage
    $freeTypeLicense = "- FreeType font engine: FreeType License, FreeType-NOTICE.txt"
}
$readme = (Get-Content "windows/README.txt" -Raw).
    Replace("{VERSION}", $Version).Replace("{ARCH}", $Arch).
    Replace("{DEBUGGER}", $debugger).Replace("{FREETYPE_LICENSE}", $freeTypeLicense)
# Windows line endings for Notepad
$readme = ($readme -replace "`r`n", "`n") -replace "`n", "`r`n"
[System.IO.File]::WriteAllText((Join-Path $stage "README.txt"), $readme)

$zip = Join-Path $OutDir "$name.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $stage -DestinationPath $zip
Write-Output "Created $zip"
Get-ChildItem $stage | ForEach-Object { Write-Output ("  {0,-22} {1,10:N0}" -f $_.Name, $_.Length) }

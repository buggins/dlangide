# Packages a Windows build of DlangIDE as a .zip (#513).
#
# Run from the repository root after `dub build -b release --arch=<arch> [-c <config>]`:
#   pwsh windows/package.ps1 -Arch x86_64 [-Config freetype] [-Version v0.9.0] [-OutDir dist]
#
# The archive holds one folder, dlangide-<version>-windows-<arch>, with dlangide.exe, the mago-mi debugger
# for that architecture, libfreetype-6.dll when the build uses FreeType fonts (`freetype` configuration),
# licenses (GPL-3.0.txt for DCD, THIRD-PARTY.txt listing all components, #522) and a README.
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
Copy-Item "windows/GPL-3.0.txt" $stage

# THIRD-PARTY.txt: everything linked into dlangide.exe and shipped next to it, with licenses and sources (#522).
# The DUB packages and their versions come from `dub describe`, so the list matches the build.
$describe = (& dub describe "--config=$Config" "--arch=$Arch" --build=release) -join "`n"
if ($LASTEXITCODE -ne 0) { throw "dub describe failed" }
$packages = @(($describe | ConvertFrom-Json).packages | Where-Object { $_.active -ne $false })
# source repositories (most recipes have no homepage); others: code.dlang.org
$repos = @{
    "dlangide" = "https://github.com/buggins/dlangide"; "dlangui" = "https://github.com/buggins/dlangui";
    "dcd" = "https://github.com/dlang-community/DCD"; "libdparse" = "https://github.com/dlang-community/libdparse";
    "emsi_containers" = "https://github.com/dlang-community/containers"; "msgpack-d" = "https://github.com/msgpack/msgpack-d";
    "inilike" = "https://github.com/FreeSlave/inilike"; "icontheme" = "https://github.com/FreeSlave/icontheme";
    "xdgpaths" = "https://github.com/FreeSlave/xdgpaths"; "isfreedesktop" = "https://github.com/FreeSlave/isfreedesktop";
    "arsd-official" = "https://github.com/adamdruppe/arsd"
}
function Get-LicenseName($pkg) {
    $l = "$($pkg.license)"
    if ($pkg.name -eq "dcd:common") { return "GPL-3.0" }          # part of DCD, no license field of its own
    if ($pkg.name -like "arsd-official:*") { return "BSL-1.0" }   # arsd's root license
    if ($l -match "^Boost" -or $l -eq "BSL-1.0") { return "BSL-1.0" }
    if ($l) { return $l }
    return "see its repository"
}
$commit = (& git rev-parse HEAD 2>$null)
if (-not $commit) { $commit = "(unknown)" }
$nl = "`r`n"
$tp = New-Object System.Text.StringBuilder
$title = "DlangIDE $Version for Windows ($Arch): licenses of the included software"
[void]$tp.Append("$title$nl$nl")
[void]$tp.Append("dlangide.exe combines DlangIDE (Boost Software License 1.0, LICENSE.txt) with$nl")
[void]$tp.Append("DCD, the D Completion Daemon, which is licensed under the GNU General Public$nl")
[void]$tp.Append("License version 3. The program as a whole is therefore distributed under the$nl")
[void]$tp.Append("terms of the GNU GPL v3, see GPL-3.0.txt. The other components below use$nl")
[void]$tp.Append("permissive licenses that are compatible with it.$nl$nl")
[void]$tp.Append("Linked into dlangide.exe$nl------------------------$nl$nl")
$groups = $packages | Where-Object { $_.name -ne "dlangide" } | Group-Object { ($_.name -split ":")[0] }
foreach ($g in $groups) {
    $root = $g.Name
    $first = $g.Group[0]
    $url = $repos[$root]
    if (-not $url) {
        if ($root -like "bindbc-*") { $url = "https://github.com/BindBC/$root" } else { $url = "https://code.dlang.org/packages/$root" }
    }
    # the license of the package itself, or of its first part when only parts are linked
    $main = @($g.Group | Where-Object { $_.name -eq $root })
    if ($main.Count -gt 0) { $license = Get-LicenseName $main[0] } else { $license = Get-LicenseName $first }
    [void]$tp.Append("- $root $($first.version): $license$nl  $url$nl")
    $subs = @($g.Group | Where-Object { $_.name -like "*:*" })
    if ($subs.Count -gt 0) {
        # a part's license is shown only where it differs from the package's
        $parts = @($subs | ForEach-Object {
            $partName = ($_.name -split ":")[1]
            $partLicense = Get-LicenseName $_
            if ($partLicense -eq $license) { $partName } else { "$partName ($partLicense)" }
        }) -join ", "
        [void]$tp.Append("  parts used: $parts$nl")
    }
    if ($root -eq "arsd-official") {
        [void]$tp.Append("  svg.d is based on NanoSVG, Copyright (c) 2013-14 Mikko Mononen (zlib license);$nl")
        [void]$tp.Append("  jpeg.d (jpgd) and imageresize.d are in the public domain.$nl")
    }
}
[void]$tp.Append("- D runtime (druntime) and Phobos, the D standard library: BSL-1.0$nl  https://github.com/dlang/phobos$nl")
[void]$tp.Append("  Phobos includes zlib by Jean-loup Gailly and Mark Adler (zlib license).$nl")
[void]$tp.Append("- Microsoft C runtime (linked by the compiler): Visual Studio redistributable code$nl$nl")
[void]$tp.Append("Shipped next to dlangide.exe$nl----------------------------$nl$nl")
$magoFiles = "mago-mi.exe"
if ($Arch -eq "x86") { $magoFiles = "mago-mi.exe, MagoRemote.exe" }
[void]$tp.Append("- $($magoFiles): mago debugger, Apache License 2.0 (mago-LICENSE.txt, mago-NOTICE.txt)$nl")
[void]$tp.Append("  https://github.com/rainers/mago$nl")
if ($Arch -eq "x86_64") {
    [void]$tp.Append("- udis86.dll: udis86 disassembler, BSD 2-clause license (udis86-LICENSE.txt)$nl")
} else {
    [void]$tp.Append("- udis86 disassembler (linked into mago-mi.exe): BSD 2-clause license (udis86-LICENSE.txt)$nl")
}
[void]$tp.Append("  https://github.com/vmt/udis86$nl")
[void]$tp.Append("- msdia140.dll: Microsoft Debug Interface Access, Visual Studio redistributable code$nl")
if ($useFreeType) {
    [void]$tp.Append("- libfreetype-6.dll: FreeType font engine, FreeType License (FreeType-NOTICE.txt)$nl  https://freetype.org$nl")
}
[void]$tp.Append("$($nl)Corresponding source code$nl-------------------------$nl$nl")
[void]$tp.Append("DlangIDE: https://github.com/buggins/dlangide/tree/$commit$nl")
[void]$tp.Append("The DUB packages above, in exactly the listed versions, are available from$nl")
[void]$tp.Append("https://code.dlang.org and from the listed repositories. Build command:$nl")
$configOption = ""
if ($Config -ne "default") { $configOption = " -c $Config" }
[void]$tp.Append("    dub build -b release --arch=$Arch$configOption$nl")
[System.IO.File]::WriteAllText((Join-Path $stage "THIRD-PARTY.txt"), $tp.ToString())

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

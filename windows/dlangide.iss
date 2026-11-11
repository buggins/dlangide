; Inno Setup script for the DlangIDE Windows installer (#514).
;
; Packs the folder made by windows/package.ps1, so the installer holds the same files as the .zip:
;   ISCC /DAppVersion=v0.9.0 /DArch=x86_64 /DSourceDir=dist\dlangide-v0.9.0-windows-x86_64 /ODist windows\dlangide.iss
;
; Installs for the current user by default (no administrator rights, %LOCALAPPDATA%\Programs\DlangIDE);
; the first page offers installing for all users. Settings in %APPDATA%\.dlangide are kept on uninstall.

#ifndef AppVersion
  #error AppVersion is not defined: pass /DAppVersion=<version>
#endif
#ifndef Arch
  #define Arch "x86_64"
#endif
#ifndef SourceDir
  #error SourceDir is not defined: pass /DSourceDir=<package folder>
#endif

[Setup]
; the same AppId for every version and architecture: a new version upgrades the installed one
AppId={{AD4947D7-77D5-4FD5-B3B6-4BBDF9737B66}
AppName=DlangIDE
AppVersion={#AppVersion}
AppVerName=DlangIDE {#AppVersion}
AppPublisher=Vadim Lopatin
AppPublisherURL=https://github.com/buggins/dlangide
AppSupportURL=https://github.com/buggins/dlangide/issues
AppUpdatesURL=https://github.com/buggins/dlangide/releases
DefaultDirName={autopf}\DlangIDE
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
LicenseFile={#SourceDir}\LICENSE.txt
OutputBaseFilename=dlangide-{#AppVersion}-windows-{#Arch}-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\views\res\mdpi\dlangui-shortcut1.ico
UninstallDisplayIcon={app}\dlangide.ico
UninstallDisplayName=DlangIDE {#AppVersion}
ChangesAssociations=yes
; Windows 10 1809: the Output panel terminal needs ConPTY (older Windows would only lose that)
MinVersion=10.0.17763
#if Arch == "x86_64"
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[CustomMessages]
english.AssocWorkspace=Open DlangIDE workspaces (.dlangidews) with DlangIDE
russian.AssocWorkspace=Открывать рабочие пространства DlangIDE (.dlangidews) в DlangIDE
german.AssocWorkspace=DlangIDE-Workspaces (.dlangidews) mit DlangIDE öffnen
english.FolderMenu=Add "Open in DlangIDE" to the folder context menu
russian.FolderMenu=Добавить «Открыть в DlangIDE» в контекстное меню папок
german.FolderMenu=„In DlangIDE öffnen“ zum Kontextmenü von Ordnern hinzufügen
english.OpenInDlangIDE=Open in DlangIDE
russian.OpenInDlangIDE=Открыть в DlangIDE
german.OpenInDlangIDE=In DlangIDE öffnen
english.WorkspaceFile=DlangIDE workspace
russian.WorkspaceFile=Рабочее пространство DlangIDE
german.WorkspaceFile=DlangIDE-Workspace

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "assocworkspace"; Description: "{cm:AssocWorkspace}"
Name: "foldermenu"; Description: "{cm:FolderMenu}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
; dlangide.exe has no icon resource: shortcuts, the uninstaller entry and the file type use this
Source: "..\views\res\mdpi\dlangui-shortcut1.ico"; DestDir: "{app}"; DestName: "dlangide.ico"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\DlangIDE"; Filename: "{app}\dlangide.exe"; IconFilename: "{app}\dlangide.ico"
Name: "{autodesktop}\DlangIDE"; Filename: "{app}\dlangide.exe"; IconFilename: "{app}\dlangide.ico"; Tasks: desktopicon

[Registry]
; HKA: HKCU for a per-user install, HKLM for all users
Root: HKA; Subkey: "Software\Classes\.dlangidews"; ValueType: string; ValueName: ""; ValueData: "DlangIDE.Workspace"; Flags: uninsdeletevalue uninsdeletekeyifempty; Tasks: assocworkspace
Root: HKA; Subkey: "Software\Classes\DlangIDE.Workspace"; ValueType: string; ValueName: ""; ValueData: "{cm:WorkspaceFile}"; Flags: uninsdeletekey; Tasks: assocworkspace
Root: HKA; Subkey: "Software\Classes\DlangIDE.Workspace\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\dlangide.ico"; Tasks: assocworkspace
Root: HKA; Subkey: "Software\Classes\DlangIDE.Workspace\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\dlangide.exe"" ""%1"""; Tasks: assocworkspace
; DlangIDE opens a folder's workspace or DUB project (#505)
Root: HKA; Subkey: "Software\Classes\Directory\shell\DlangIDE"; ValueType: string; ValueName: ""; ValueData: "{cm:OpenInDlangIDE}"; Flags: uninsdeletekey; Tasks: foldermenu
Root: HKA; Subkey: "Software\Classes\Directory\shell\DlangIDE"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\dlangide.ico"; Tasks: foldermenu
Root: HKA; Subkey: "Software\Classes\Directory\shell\DlangIDE\command"; ValueType: string; ValueName: ""; ValueData: """{app}\dlangide.exe"" ""%1"""; Tasks: foldermenu
Root: HKA; Subkey: "Software\Classes\Directory\Background\shell\DlangIDE"; ValueType: string; ValueName: ""; ValueData: "{cm:OpenInDlangIDE}"; Flags: uninsdeletekey; Tasks: foldermenu
Root: HKA; Subkey: "Software\Classes\Directory\Background\shell\DlangIDE"; ValueType: string; ValueName: "Icon"; ValueData: "{app}\dlangide.ico"; Tasks: foldermenu
Root: HKA; Subkey: "Software\Classes\Directory\Background\shell\DlangIDE\command"; ValueType: string; ValueName: ""; ValueData: """{app}\dlangide.exe"" ""%V"""; Tasks: foldermenu

[Run]
Filename: "{app}\dlangide.exe"; Description: "{cm:LaunchProgram,DlangIDE}"; Flags: nowait postinstall skipifsilent

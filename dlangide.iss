; Inno Setup script for DlangIDE.
; Installs DlangIDE and the Mago debugger, and optionally
; downloads and installs DMD.


[Setup]
AppName=DlangIDE
AppId=DlangIDE

; The following version numbers need to be updated on each release.
AppVerName=0.8.11
AppVersion=0.8.11

AppPublisher=Vadim Lopatin
AppPublisherURL=https://github.com/buggins/dlangui
AppSupportURL=https://github.com/buggins/dlangui
AppUpdatesURL=https://github.com/buggins/dlangui
AppCopyright=Copyright (C) 2015-2018 Vadim Lopatin
LicenseFile=LICENSE.txt
SetupMutex=DLangIDESetupMutex

; Require at least Windows 7.
MinVersion=6.1
DefaultDirName={pf}\DlangIDE
DefaultGroupName=DLangIDE

Compression=lzma2/normal
ShowComponentSizes=yes
AllowNetworkDrive=no
ChangesEnvironment=yes
ChangesAssociations=yes


[Types]
Name: "dlangide"; Description: "Install DlangIDE."; Flags: iscustom


[Components]
Name: "dlangide"; Description: "DlangIDE and tools"; Types: dlangide; Flags: fixed
Name: "dmd"; Description: "DMD compiler"; Types: dlangide; Check: IsCompilerNeeded;


[Files]
Source: "bin\dlangide.exe"; DestDir: "{app}"; Components: dlangide
Source: "bin\libfreetype-6.dll"; DestDir: "{app}"; Components: dlangide
Source: "bin\mago-mi.exe"; DestDir: "{app}"; Components: dlangide
Source: "views\res\mdpi\dlangui-shortcut1.ico"; DestDir: "{app}"; Components: dlangide


[Registry]
; Associate .dlangidews files with DlangIDE.
Root: HKCR; Subkey: ".dlangidews"; ValueType: String; ValueName: ""; ValueData: "DlangIDEProjectFile"; Tasks: associate; Flags: uninsdeletevalue
Root: HKCR; Subkey: "DlangIDEProjectFile"; ValueType: String; ValueName: ""; ValueData: "DlangIDE Project File"; Tasks: associate; Flags: uninsdeletekey
Root: HKCR; Subkey: "DlangIDEProjectFile\DefaultIcon"; ValueType: String; ValueName: ""; ValueData: "{app}\dlangui-shortcut1.ico"; Tasks: associate; Flags: uninsdeletekey
Root: HKCR; Subkey: "DlangIDEProjectFile\shell\open\command"; ValueType: String; ValueName: ""; ValueData: """{app}\dlangide.exe"" ""%1"""; Tasks: associate; Flags: uninsdeletekey


[Icons]
Name: "{commondesktop}\DlangIDE"; Filename: "{app}\dlangide.exe"; IconFileName: "{app}\dlangui-shortcut1.ico"; Tasks: desktopicon


[Tasks]
Name: desktopicon; Description: "Create a &desktop icon"; Components: dlangide; Flags: checkedonce unchecked
Name: associate; Description: "Associate DlangIDE &Workspace Files"; Components: dlangide; Flags: checkedonce


[Run]
Filename: "{tmp}\dmd-installer.exe"; StatusMsg: "Installing DMD..."; Components: dmd; Flags: 32bit; BeforeInstall: DownloadDMD


[Code]

{
    See if we have a registry key for D or if the default installation directory
    exists.
}
function IsCompilerNeeded(): Boolean;
begin
    Result := not (RegKeyExists(HKCU, 'Software\DMD')
              or DirExists(ExpandConstant('{sd}\D\dmd2')))
end;

{ Windows API function to download files from the Internet. }
function URLDownloadToFile(
        pCaller: Integer;
        szUrl: String;
        szFileName: String;
        dwReserved: Integer;
        lpfnCB: Integer
    ): Integer;
#ifdef UNICODE
external 'URLDownloadToFileW@urlmon.dll';
#else
external 'URLDownloadToFileA@urlmon.dll';
#endif

{
    Convenience procedure to download files; this hides parameters we don't care
    about.

    We assume the download is successful; if this fails, a later attempt to read
    the file will display an error to the user.
}
procedure DownloadFile(url: String; dest: String);
begin
    URLDownloadToFile(0, url, ExpandConstant(dest), 0, 0);
end;

procedure DownloadDMD();
var
    dmdVersion: AnsiString;
#ifdef UNICODE
    dmdVersionU: String;
#else
    dmdVersionU: AnsiString;
#endif
begin
    DownloadFile('http://downloads.dlang.org/releases/LATEST', '{tmp}\latest.txt');
    if LoadStringFromFile(ExpandConstant('{tmp}\latest.txt'), dmdVersion) then
    begin

#ifdef UNICODE
        dmdVersionU := String(dmdVersion);
#else
        dmdVersionU := dmdVersion;
#endif
        DownloadFile(
            'http://downloads.dlang.org/releases/2.x/'
            + dmdVersionU
            + '/dmd-'
            + dmdVersionU
            + '.exe',
            '{tmp}\dmd-installer.exe')
    end
    else
        MsgBox(
            'Unable to download dmd installer.'
            + ' Please download and install from dlang.org.',
            mbInformation, MB_OK);
end;

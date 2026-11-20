; Inno Setup script for the Serlink Windows installer.
; Built by tool/package_windows.ps1:
;   ISCC.exe /DAppVersion=1.2.3 /DFileVersion=1.2.3.4 /DSourceDir=<bundle> /DOutputDir=<dir> /DOutputBaseName=<name> serlink.iss

#ifndef AppVersion
  #error AppVersion must be defined
#endif
#ifndef FileVersion
  #define FileVersion AppVersion
#endif
#ifndef SourceDir
  #error SourceDir must be defined
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif
#ifndef OutputBaseName
  #define OutputBaseName "Serlink-" + AppVersion + "-windows-x64-setup"
#endif

#define AppName "Serlink"
#define AppPublisher "BackRunner"
#define AppUrl "https://serlink.alkinum.com"
#define AppExeName "serlink.exe"

[Setup]
; Never change AppId: upgrades and uninstall entries are keyed on it.
AppId={{88460C7B-EB5D-467F-8B79-9E0B83B5FAF5}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/support/
AppUpdatesURL=https://github.com/backrunner/Serlink/releases
VersionInfoVersion={#FileVersion}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#FileVersion}
VersionInfoProductTextVersion={#AppVersion}
VersionInfoTextVersion={#AppVersion}
VersionInfoDescription={#AppName} Setup
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Per-user install by default (no UAC prompt); users can choose all users.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; ConPTY (local terminal tabs) requires Windows 10 version 1809.
MinVersion=10.0.17763
; Matches the single-instance mutex in windows/runner/main.cpp so setup and
; uninstall ask the user to close a running Serlink first.
AppMutex=com.alkinum.serlink.single-instance
CloseApplications=yes
RestartApplications=no
LicenseFile=..\..\LICENSE
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; Replace the previous bundle completely so stale assets never mix with a new
; version. User data lives in %APPDATA% and is not touched.
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

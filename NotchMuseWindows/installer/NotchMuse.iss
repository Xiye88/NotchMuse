#define MyAppName "NotchMuse"
#define MyAppVersion "0.9.0"
#define MyAppPublisher "NotchMuse"
#define MyAppExeName "NotchMuse-Windows-win-x64-portable.exe"

[Setup]
AppId={{C5A9D0F4-9D5D-4F04-BE7F-5D0AF15C8B4A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\NotchMuse
DefaultGroupName=NotchMuse
OutputDir=..\artifacts\release
OutputBaseFilename=NotchMuse-Setup
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\NotchMuse-Windows-win-x64-portable.exe

[Files]
Source: "..\artifacts\release\NotchMuse-Windows-win-x64-portable.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\NotchMuse"; Filename: "{app}\NotchMuse-Windows-win-x64-portable.exe"
Name: "{autodesktop}\NotchMuse"; Filename: "{app}\NotchMuse-Windows-win-x64-portable.exe"

[Run]
Filename: "{app}\NotchMuse-Windows-win-x64-portable.exe"; Description: "Launch NotchMuse"; Flags: nowait postinstall skipifsilent

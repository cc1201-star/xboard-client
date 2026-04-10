[Setup]
AppId={{B8A5E3F2-7C4D-4E6A-9F1B-2D3C4E5F6A7B}
AppName=Xboard
AppVersion=1.0.0
AppPublisher=Xboard
DefaultDirName={autopf}\Xboard
DefaultGroupName=Xboard
UninstallDisplayIcon={app}\xboard_client.exe
OutputDir=..\build\installer
OutputBaseFilename=Xboard-Setup
Compression=lzma2
SolidCompression=yes
SetupIconFile=runner\resources\app_icon.ico
WizardStyle=modern
PrivilegesRequired=lowest

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\Xboard"; Filename: "{app}\xboard_client.exe"
Name: "{group}\{cm:UninstallProgram,Xboard}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Xboard"; Filename: "{app}\xboard_client.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\xboard_client.exe"; Description: "{cm:LaunchProgram,Xboard}"; Flags: nowait postinstall skipifsilent

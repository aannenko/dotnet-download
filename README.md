# dotnet-download
PowerShell script that downloads latest .NET installers.

### Usage
Download all installers of both x64 and x86 architectures from all channels starting from .NET Core 2.1 and up
```
.\dotnet-download.ps1
```
**Note:** This will show errors for installers that cannot be downloaded (e.g. for `windowsdesktop-runtime-2.2.7-win-x64.exe` as there was no such thing as Windows Desktop Runtime for .NET Core 2.2), these errors can be ignored.

Download 3.1 (LTS and Current channels correspond to 3.1 at the time of writing) and 2.2 x64 SDKs and hosting bundles into C:\dotnet bypassing Azure CDN
```
.\dotnet-download.ps1 -Channels LTS, Current, 2.2 -InstallerTypes sdk, hostingbundle -Architectures x64 -OutputDirectory C:\dotnet -NoCdn
```
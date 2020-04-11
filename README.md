# dotnet-download
PowerShell script that automates downloading of the .NET installers.

### Details
Major part of the script's code is taken from the .NET Foundation's [dotnet-install.ps1](https://dotnet.microsoft.com/download/dotnet-core/scripts)

The script allows to configure:
- Channels: .NET distribution channels
    - Available values: Current, LTS, 2-part version in format A.B
    - Default value: `@("Current", "LTS", "3.1", "3.0", "2.2", "2.1")`
- InstallerTypes: types of .NET installers
    - Available values: sdk, dotnet, aspnetcore, hostingbundle, windowsdesktop
    - Default value: `@("sdk", "dotnet", "aspnetcore", "hostingbundle", "windowsdesktop")`
- Architectures: OS architectures
    - Available values: x64, x86
    - Default value: `@("x64", "x86")`
- OutputDirectory: installers are downloaded into this directory
    - Default value: .\dotnet-download
- AzureFeed: a URL of the primary source of .NET istallers - Azure CDN feed
- UncachedFeed: a URL or the secondary, non-CDN source of .NET installers
- ProxyAddress: a URL of a proxy address to be used for the downloads
- ProxyUseDefaultCredentials: a flag indicating whether default credentials should be used by the proxy
- NoCdn: a flag switching between the primary and the secondary download source

The script creates SDK and Runtime directories inside the OutputDirectory and places installers in them according to their type.

### Usage
Download latest versions of all installers, of both x64 and x86 architectures, from all channels starting from .NET Core 2.1 and up, and put in the .\dotnet-download directory:
```
.\dotnet-download.ps1
```
**Note:** In this case the script will show errors for installers that cannot be downloaded (e.g. for `windowsdesktop-runtime-2.2.7-win-x64.exe` as there was no such thing as Windows Desktop Runtime for .NET Core 2.2), these errors can be ignored.

Download 3.1 (LTS and Current channels correspond to 3.1 at the time of writing) and 2.2 x64 SDKs and hosting bundles into C:\dotnet bypassing Azure CDN:
```
.\dotnet-download.ps1 -Channels LTS, Current, 2.2 -InstallerTypes sdk, hostingbundle -Architectures x64 -OutputDirectory C:\dotnet -NoCdn
```
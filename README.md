# dotnet-download
PowerShell script that downloads latest .NET binaries.

### Details
Major part of the script's code is taken from the .NET Foundation's [dotnet-install.ps1](https://dotnet.microsoft.com/download/dotnet-core/scripts)

The script allows to configure:
- Channels: .NET channels
    - Available values: Current, LTS, 2-part version in format A.B
    - Default value: `Current, LTS, 3.1, 3.0, 2.2, 2.1`
- DotnetTypes: types of .NET binaries
    - Available values: sdk, dotnet, aspnetcore, hostingbundle, windowsdesktop
    - Default value: `sdk, dotnet, aspnetcore, hostingbundle, windowsdesktop`
- Architectures: OS architectures
    - Available values: win-x64, win-x86, win-arm, linux-x64, linux-arm, linux-arm64, alpine-x64, alpine-arm64, rhel6-x64, osx-x64
    - Default value: `win-x64, win-x86, win-arm, linux-x64, linux-arm, linux-arm64, alpine-x64, alpine-arm64, rhel6-x64, osx-x64`
- FileExtensions: types of files to download
    - Available values: exe, zip, tar.gz, pkg
    - Default value: `exe, zip, tar.gz, pkg`
- OutputDirectory: binaries are downloaded into this directory
    - Default value: .\dotnet-download
- AzureFeed: a URL of the primary source of .NET istallers - Azure CDN feed
- UncachedFeed: a URL or the secondary, non-CDN source of .NET binaries
- ProxyAddress: a URL of a proxy address to be used for the downloads
- ProxyUseDefaultCredentials: a flag indicating whether default credentials should be used by the proxy
- NoCdn: a flag switching between the primary and the secondary download source

The script creates SDK and Runtime directories inside the OutputDirectory and places binaries in them according to their type.

### Usage
**Example 1:** Download latest versions of all binaries, of all supported architectures, from all channels starting from .NET Core 2.1 and up, and put in the .\dotnet-download directory:
```
.\dotnet-download.ps1
```
**Note:** In this case the script will show errors for binaries that cannot be downloaded (e.g. for `windowsdesktop-runtime-2.2.7-win-x64.exe` as there was no such thing as Windows Desktop Runtime for .NET Core 2.2, or for `dotnet-sdk-3.1.201-linux-arm64.exe` as there's obviously no Windows installer for a Linux arm64), these errors can be ignored.

**Example 2:** Download Windows x64 installers for 3.1 (LTS and Current channels correspond to 3.1 at the time of writing) and 2.2 SDKs and hosting bundles into C:\dotnet bypassing Azure CDN:
```
.\dotnet-download.ps1 -Channels LTS, Current, 2.2 -DotnetTypes sdk, hostingbundle -Architectures win-x64 -FileExtensions exe -OutputDirectory C:\dotnet -NoCdn
```

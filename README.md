# dotnet-download
PowerShell script that downloads latest .NET binaries.

### Usage
**Example 1**

Download latest versions of all binaries, of all [supported](https://dotnet.microsoft.com/download/dotnet-core) .NET versions and architectures, and put them in the .\dotnet-download directory:
```
.\dotnet-download.ps1
```
**Note:** In this case the script will show errors for binaries that cannot be downloaded (e.g. for `dotnet-sdk-3.1.201-linux-arm64.exe` as there's obviously no Windows installer for a Linux arm64), these errors can be ignored.

**Example 2**

Download latest Windows x64 SDK and hosting bundle installers from the Current, LTS, and 2.2 channels bypassing Azure CDN, and put them in the C:\dotnet directory:
```
.\dotnet-download.ps1 -Channels LTS, Current, 2.2 -DotnetTypes sdk, hostingbundle -Architectures win-x64 -FileExtensions exe -OutputDirectory C:\dotnet -NoCdn
```

#### Parameters
For detailed information about parameters, use `Get-Help .\dotnet-download.ps1 -Detailed` (execution policy must allow scripts to run) or see the script's header.

### Remarks
Major part of the script's code is taken from the .NET Foundation's [dotnet-install.ps1](https://dotnet.microsoft.com/download/dotnet-core/scripts)

The script creates SDK and Runtime directories inside the OutputDirectory and places binaries in them according to their type.
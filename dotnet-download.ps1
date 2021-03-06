#
# Licensed under the MIT license. See LICENSE file in the project root for full license information.
#

<#
.SYNOPSIS
    Downloads latest dotnet binaries
.DESCRIPTION
    Downloads latest dotnet binaries of the specified architectures from the specified channels.
    If dotnet files already exist in the given directory their download will be skipped.
.PARAMETER Channels
    Array or Channels to download from.
    Possible values:
        - Current   - most current release
        - LTS       - most current Long Term Service release
        - 2-part version in a format A.B - represents a specific release; examples: 3.1, 5.0
    Default: Current, LTS, 3.1, 2.1
.PARAMETER DotnetTypes
    Array of dotnet binaries' types to download.
    Possible values:
        - sdk            - SDK
        - dotnet         - the Microsoft.NETCore.App shared runtime
        - aspnetcore     - the Microsoft.AspNetCore.App shared runtime
        - hostingbundle  - the Hosting Bundle, which includes the .NET Core Runtime and IIS support
        - windowsdesktop - the Microsoft.WindowsDesktop.App shared runtime
    Default: sdk, dotnet, aspnetcore, hostingbundle, windowsdesktop
.PARAMETER Architectures
    Array or dotnet binaries' architectures to download.
    Possible values: win-x64, win-x86, win-arm, win-arm64, linux-x64, linux-arm, linux-arm64, alpine-x64, alpine-arm64, rhel6-x64, osx-x64
    Default: win-x64, win-x86, win-arm, win-arm64, linux-x64, linux-arm, linux-arm64, alpine-x64, alpine-arm64, rhel6-x64, osx-x64
.PARAMETER FileExtensions
    Array of dotnet binaries' file extensions to download.
    Possible values:
        - exe       - Windows installer
        - zip       - zip archive with dotnet binaries
        - tar.gz    - tar.gz archive with dotnet binaries
        - pkg       - OSX installer
    Default: exe, zip, tar.gz, pkg
.PARAMETER OutputDirectory
    Specifies a directory to download dotnet binaries into.
    Default: .\dotnet-download
.PARAMETER AzureFeed
    This parameter typically is not changed by the user.
    It allows changing the URL for primary feed used by this script.
    Default: https://dotnetcli.azureedge.net/dotnet
.PARAMETER UncachedFeed
    This parameter typically is not changed by the user.
    It allows changing the URL for the Uncached feed used by this script.
    Default: https://dotnetcli.blob.core.windows.net/dotnet
.PARAMETER ProxyAddress
    If set, this script will use the proxy when making web requests.
.PARAMETER ProxyUseDefaultCredentials
    Use default credentials, when using proxy address.
.PARAMETER NoCdn
    Disable downloading from the Azure CDN, and use the uncached feed directly.
.PARAMETER Verbose
    Show verbose output for script's actions.
.EXAMPLE
    PS> .\dotnet-download.ps1
    Download latest versions of all binaries, of all supported .NET versions and architectures, and put them in the .\dotnet-download directory.
.EXAMPLE
    PS> .\dotnet-download.ps1 -Channels LTS, Current, 2.2 -DotnetTypes sdk, hostingbundle -Architectures win-x64 -FileExtensions exe -OutputDirectory C:\dotnet -NoCdn
    Download latest Windows x64 SDK and hosting bundle installers from the Current, LTS and 2.2 channels bypassing Azure CDN, and put them in the C:\dotnet directory.
.NOTES
    https://github.com/aannenko/dotnet-download
#>

[cmdletbinding()]
param(
    [string[]]
    [ValidatePattern("^Current|LTS|\d\.\d$")]
    $Channels = @("Current", "LTS", "3.1", "2.1"),

    [string[]]
    [ValidateSet("sdk", "dotnet", "aspnetcore", "hostingbundle", "windowsdesktop")]
    $DotnetTypes = @("sdk", "dotnet", "aspnetcore", "hostingbundle", "windowsdesktop"),

    [string[]]
    [ValidateSet("win-x64", "win-x86", "win-arm", "win-arm64", "linux-x64", "linux-arm", "linux-arm64", "alpine-x64", "alpine-arm64", "rhel6-x64", "osx-x64")]
    $Architectures = @("win-x64", "win-x86", "win-arm", "win-arm64", "linux-x64", "linux-arm", "linux-arm64", "alpine-x64", "alpine-arm64", "rhel6-x64", "osx-x64"),

    [string[]]
    [ValidateSet("exe", "zip", "tar.gz", "pkg")]
    $FileExtensions = @("exe", "zip", "tar.gz", "pkg"),

    [string]
    $OutputDirectory = ".\dotnet-download",

    [string]
    $AzureFeed = "https://dotnetcli.azureedge.net/dotnet",

    [string]
    $UncachedFeed = "https://dotnetcli.blob.core.windows.net/dotnet",

    [string]
    $ProxyAddress,

    [switch]
    $ProxyUseDefaultCredentials,

    [switch]
    $NoCdn
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

if ($Channels.Count -lt 1) {
    throw "At least one Channel should be provided."
}

if ($DotnetTypes.Count -lt 1) {
    throw "At least one DotnetType should be selected."
}

if ($Architectures.Count -lt 1) {
    throw "At least one Architecture should be selected."
}

if ($FileExtensions.Count -lt 1) {
    throw "At least one File Extension should be provided."
}

if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

if ($NoCdn) {
    $AzureFeed = $UncachedFeed
}

$Channels = [System.Collections.Generic.HashSet[string]]::new($Channels, [StringComparer]::OrdinalIgnoreCase)
$DotnetTypes = [System.Collections.Generic.HashSet[string]]::new($DotnetTypes, [StringComparer]::OrdinalIgnoreCase)
$Architectures = [System.Collections.Generic.HashSet[string]]::new($Architectures, [StringComparer]::OrdinalIgnoreCase)
$FileExtensions = [System.Collections.Generic.HashSet[string]]::new($FileExtensions, [StringComparer]::OrdinalIgnoreCase)

$DotnetChannelSanitized = @{
    "lts"     = "LTS"
    "current" = "Current"
}

$DotnetTypeToLink = @{
    "sdk"            = "$AzureFeed/Sdk"
    "dotnet"         = "$AzureFeed/Runtime"
    "aspnetcore"     = "$AzureFeed/aspnetcore/Runtime"
    "hostingbundle"  = "$AzureFeed/aspnetcore/Runtime"
    "windowsdesktop" = "$AzureFeed/Runtime"
}

$DotnetTypeToFileName = @{
    "sdk"            = "dotnet-sdk"
    "dotnet"         = "dotnet-runtime"
    "aspnetcore"     = "aspnetcore-runtime"
    "hostingbundle"  = "dotnet-hosting"
    "windowsdesktop" = "windowsdesktop-runtime"
}

$ArchitectureToFileName = @{
    "alpine-x64"   = "linux-musl-x64"
    "alpine-arm64" = "linux-musl-arm64"
    "rhel6-x64"    = "rhel.6-x64"
}

function Say($str) {
    Write-Host "[$(Get-Date -Format o)] dotnet-download: $str"
}

function Say-Verbose($str) {
    Write-Verbose "[$(Get-Date -Format o)] dotnet-download: $str"
}

function Say-Invocation($Invocation) {
    $command = $Invocation.MyCommand;
    $arguments = (($Invocation.BoundParameters.Keys | ForEach-Object { "-$_ `"$($Invocation.BoundParameters[$_])`"" }) -join " ")
    Say-Verbose "$command $arguments"
}

function Invoke-WithRetry([ScriptBlock]$ScriptBlock, [int]$MaxAttempts = 3, [int]$MilliecondsBetweenAttempts = 300) {
    $Attempts = 0

    while ($true) {
        try {
            return $ScriptBlock.Invoke()
        }
        catch {
            $Attempts++
            if ($Attempts -lt $MaxAttempts) {
                Start-Sleep -Milliseconds $MilliecondsBetweenAttempts
            }
            else {
                throw
            }
        }
    }
}

function Invoke-WebRequestWithRetry([Uri]$Uri, [string]$OutFile) {
    Say-Invocation $MyInvocation

    Invoke-WithRetry(
        {
            $RequestExpression = "Invoke-WebRequest -Uri ${Uri} -TimeoutSec 1200 -UseBasicParsing"

            if ($ProxyAddress) {
                $RequestExpression += " -Proxy ${ProxyAddress}"
                if ($ProxyUseDefaultCredentials) {
                    $RequestExpression += " -ProxyUseDefaultCredentials"
                }
            }
            else {
                try {
                    # Despite no proxy being explicitly specified, we may still be behind a default proxy
                    $DefaultProxy = [System.Net.WebRequest]::DefaultWebProxy;
                    if ($DefaultProxy -and (-not $DefaultProxy.IsBypassed($Uri))) {
                        $ProxyAddress = $DefaultProxy.GetProxy($Uri).OriginalString
                        $RequestExpression += " -Proxy ${ProxyAddress} -ProxyUseDefaultCredentials"
                    }
                }
                catch {
                    # Eat the exception and move forward as the above code is an attempt
                    #    at resolving the DefaultProxy that may not have been a problem.
                    Say-Verbose("Exception ignored: $_.Exception.Message - moving forward...")
                }
            }

            if ($OutFile) {
                $RequestExpression += " -OutFile ${OutFile}"
            }

            return Invoke-Expression $RequestExpression
        })
}

function Get-LatestVersion([string]$Channel, [string]$DotnetType) {
    Say-Invocation $MyInvocation

    $VersionFileUrl = if ($DotnetType -eq "sdk") {
        "$AzureFeed/Sdk/$Channel/latest.version"
    }
    else {
        "$AzureFeed/Runtime/$Channel/latest.version"
        # There's also this path for aspnetcore and hostingbundle:
        # "$AzureFeed/aspnetcore/Runtime/$Channel/latest.version"
    }

    try {
        $Response = Invoke-WebRequestWithRetry -Uri $VersionFileUrl
    }
    catch {
        throw "Could not resolve version information."
    }

    switch ($Response.Headers["Content-Type"]) {
        { ($_ -eq "application/octet-stream") } { $VersionText = [System.Text.Encoding]::UTF8.GetString($Response.Content); break }
        { ($_ -eq "text/plain") } { $VersionText = $Response.Content; break }
        { ($_ -eq "text/plain; charset=UTF-8") } { $VersionText = $Response.Content; break }
        default { throw "``$Response.Headers[""Content-Type""]`` is an unknown .version file content type." }
    }

    return (-split $VersionText)[-1]
}

function Get-DownloadInfo([string]$SpecificVersion, [string]$CLIArchitecture, [string]$DotnetType, [string]$FileExtension) {
    Say-Invocation $MyInvocation

    $FileNameFirstPart = $DotnetTypeToFileName[$DotnetType]
    $FileName = if ($DotnetType -eq "hostingbundle") {
        "$FileNameFirstPart-$SpecificVersion-win.exe"
    }
    else {
        $FileNameSecondPart = if ($ArchitectureToFileName[$CLIArchitecture]) {
            $ArchitectureToFileName[$CLIArchitecture]
        }
        else {
            $CLIArchitecture
        }
        
        "$FileNameFirstPart-$SpecificVersion-$FileNameSecondPart.$FileExtension"
    }

    $LinkFirstPart = $DotnetTypeToLink[$DotnetType]
    $FileUri = "$LinkFirstPart/$SpecificVersion/$FileName"

    Say-Verbose "Constructed primary named payload URL: $FileUri"

    return @{
        FileName = $FileName
        FileUri  = $FileUri
    }
}

function Get-ChannelVersion([string]$Channel) {
    Say-Invocation $MyInvocation

    if ($Channel -match "\d\.\d{1,2}") {
        return $Channel
    }

    if ($DotnetChannelSanitized.Contains($Channel)) {
        $Channel = $DotnetChannelSanitized[$Channel]
    }

    $Version = Get-LatestVersion -Channel $Channel -DotnetType $DotnetTypes[0]
    if ($Version -match "(\d\.\d{1,2})") {
        return $Matches[0]
    }

    throw "Could not retrieve Channel version"
}

function Get-SelectedChannelVersions {
    Say-Invocation $MyInvocation

    $ChannelVersions = @()
    foreach ($Ch in $Channels) {
        $Version = Get-ChannelVersion -Channel $Ch
        if (-not $ChannelVersions.Contains($Version)) {
            $ChannelVersions += $Version
        }
    }

    return $ChannelVersions
}

function Get-OutputDirectory([string]$Channel, [string]$DotnetType) {
    Say-Invocation $MyInvocation

    $ChannelDir = Join-Path -Path $OutputDirectory -ChildPath $Channel
    $OutDir = if ($DotnetType.ToLower() -eq "sdk") {
        Join-Path -Path $ChannelDir -ChildPath "SDK"
    }
    else {
        Join-Path -Path $ChannelDir -ChildPath "Runtime"
    }

    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    return $OutDir
}

function Invoke-FileDownload([string]$FileUri, [string]$OutFile) {
    Say-Invocation $MyInvocation

    if (Test-Path -Path $OutFile) {
        Say "'$OutFile' already exists - skipping..."
        return
    }

    Say("Downloading '$FileUri' to '$OutFile'")
    try {
        Invoke-WebRequestWithRetry -Uri $FileUri -OutFile $OutFile
    }
    catch {
        Say "Cannot download '$FileUri'"
        Say-Verbose "$_`n$_.ScriptStackTrace"
    }
}

$ChannelVersions = Get-SelectedChannelVersions
foreach ($Channel in $ChannelVersions) {
    foreach ($Type in $DotnetTypes) {
        try {
            $Version = Get-LatestVersion -Channel $Channel -DotnetType $Type
            foreach ($Arc in $Architectures) {
                foreach ($Ext in $FileExtensions) {
                    $DownloadInfo = Get-DownloadInfo -SpecificVersion $Version -CLIArchitecture $Arc -DotnetType $Type -FileExtension $Ext
                    $OutDir = Get-OutputDirectory -Channel $Channel -DotnetType $Type
                    $OutFile = Join-Path -Path $OutDir -ChildPath $DownloadInfo.FileName
                    Invoke-FileDownload -FileUri $DownloadInfo.FileUri -OutFile $OutFile
                }
            }
        }
        catch {
            Say "Error occurred for Channel '$Channel' and DotnetType '$Type'"
            Say-Verbose "$_`n$_.ScriptStackTrace"
        }
    }
}

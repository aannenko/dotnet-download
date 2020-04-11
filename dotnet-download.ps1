#
# Licensed under the MIT license. See LICENSE file in the project root for full license information.
#

<#
.SYNOPSIS
    Downloads latest dotnet installers
.DESCRIPTION
    Downloads latest dotnet installers of the specified architectures from the specified channels.
    If dotnet files already exist in the given directory their download will be skipped.
.PARAMETER Channels
    Default: @("Current", "LTS", "3.1", "3.0", "2.2", "2.1")
    Array or Channels to download from. Possible values:
    - Current   - most current release
    - LTS       - most current supported release
    - 2-part version in a format A.B - represents a specific release
          examples: 3.1, 2.2
.PARAMETER InstallerTypes
    Default: @("sdk", "dotnet", "aspnetcore", "hostingbundle", "windowsdesktop")
    Specifies a type of installer to download.
    Possible values:
        - sdk            - SDK
        - dotnet         - the Microsoft.NETCore.App shared runtime
        - aspnetcore     - the Microsoft.AspNetCore.App shared runtime
        - hostingbundle  - the Hosting Bundle, which includes the .NET Core Runtime and IIS support
        - windowsdesktop - the Microsoft.WindowsDesktop.App shared runtime
.PARAMETER Architectures
    Default: @("x64", "x86") - this value represents all supported Windows architectures
    Array or architectures of dotnet installers to be downloaded.
    Possible values are: x64, x86
.PARAMETER OutputDirectory
    Default: .\dotnet-download
    Specifies a directory to download dotnet installers into.
.PARAMETER Verbose
    Displays diagnostics information.
.PARAMETER AzureFeed
    Default: https://dotnetcli.azureedge.net/dotnet
    This parameter typically is not changed by the user.
    It allows changing the URL for the Azure feed used by this downloader script.
.PARAMETER UncachedFeed
    This parameter typically is not changed by the user.
    It allows changing the URL for the Uncached feed used by this downloader script.
.PARAMETER ProxyAddress
    If set, this downloader script will use the proxy when making web requests
.PARAMETER ProxyUseDefaultCredentials
    Default: false
    Use default credentials, when using proxy address.
.PARAMETER NoCdn
    Disable downloading from the Azure CDN, and use the uncached feed directly.
#>

[cmdletbinding()]
param(
    [string[]]$Channels = @("Current", "LTS", "3.1", "3.0", "2.2", "2.1"),
    [string[]]$InstallerTypes = @("sdk", "dotnet", "aspnetcore", "hostingbundle", "windowsdesktop"),
    [string[]]$Architectures = @("x64", "x86"),
    [string]$OutputDirectory = ".\dotnet-download",
    [switch]$DryRun,
    [string]$AzureFeed = "https://dotnetcli.azureedge.net/dotnet",
    [string]$UncachedFeed = "https://dotnetcli.blob.core.windows.net/dotnet",
    [string]$ProxyAddress,
    [switch]$ProxyUseDefaultCredentials,
    [switch]$NoCdn
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Say($str) {
    Write-Host "dotnet-download: $str"
}

function Say-Verbose($str) {
    Write-Verbose "dotnet-download: $str"
}

function Say-Invocation($Invocation) {
    $command = $Invocation.MyCommand;
    $args = (($Invocation.BoundParameters.Keys | ForEach-Object { "-$_ `"$($Invocation.BoundParameters[$_])`"" }) -join " ")
    Say-Verbose "$command $args"
}

function Invoke-WithRetry([ScriptBlock]$ScriptBlock, [int]$MaxAttempts = 3, [int]$SecondsBetweenAttempts = 1) {
    $Attempts = 0

    while ($true) {
        try {
            return $ScriptBlock.Invoke()
        }
        catch {
            $Attempts++
            if ($Attempts -lt $MaxAttempts) {
                Start-Sleep $SecondsBetweenAttempts
            }
            else {
                throw
            }
        }
    }
}

function Invoke-WebRequestWithRetry([Uri] $Uri, [string] $OutFile) {
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
                    $ProxyAddress = $null
                    Say-Verbose("Exception ignored: $_.Exception.Message - moving forward...")
                }
            }

            if ($OutFile) {
                $RequestExpression += " -OutFile ${OutFile}"
            }

            return Invoke-Expression $RequestExpression
        })
}

function Get-LatestVersion([string]$Feed, [string]$Channel, [string]$InstallerType) {
    Say-Invocation $MyInvocation

    $VersionFileUrl = $null
    if ($InstallerType -eq "sdk") {
        $VersionFileUrl = "$UncachedFeed/Sdk/$Channel/latest.version"
    }
    elseif ($InstallerType -eq "dotnet" -or $InstallerType -eq "aspnetcore" -or $InstallerType -eq "hostingbundle" -or $InstallerType -eq "windowsdesktop") {
        $VersionFileUrl = "$UncachedFeed/Runtime/$Channel/latest.version"
        # There's also this path for aspnetcore and hostingbundle: "$UncachedFeed/aspnetcore/Runtime/$Channel/latest.version"
    }
    else {
        throw "Invalid value for `$InstallerType"
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

function Get-DownloadInfo([string]$Feed, [string]$SpecificVersion, [string]$CLIArchitecture, [string]$InstallerType) {
    Say-Invocation $MyInvocation

    if ($InstallerType -eq "sdk") {
        $FileName = "dotnet-sdk-$SpecificVersion-win-$CLIArchitecture.exe"
        $PayloadURL = "$Feed/Sdk/$SpecificVersion/$FileName"
    }
    elseif ($InstallerType -eq "dotnet") {
        $FileName = "dotnet-runtime-$SpecificVersion-win-$CLIArchitecture.exe"
        $PayloadURL = "$Feed/Runtime/$SpecificVersion/$FileName"
    }
    elseif ($InstallerType -eq "aspnetcore") {
        $FileName = "aspnetcore-runtime-$SpecificVersion-win-$CLIArchitecture.exe"
        $PayloadURL = "$Feed/aspnetcore/Runtime/$SpecificVersion/$FileName"
    }
    elseif ($InstallerType -eq "hostingbundle") {
        $FileName = "dotnet-hosting-$SpecificVersion-win.exe"
        $PayloadURL = "$Feed/aspnetcore/Runtime/$SpecificVersion/$FileName"
    }
    elseif ($InstallerType -eq "windowsdesktop") {
        $FileName = "windowsdesktop-runtime-$SpecificVersion-win-$CLIArchitecture.exe"
        $PayloadURL = "$Feed/Runtime/$SpecificVersion/$FileName"
    }
    else {
        throw "Invalid value for `$InstallerType"
    }

    Say-Verbose "Constructed primary named payload URL: $PayloadURL"

    return @{
        FileName = $FileName
        FileUrl  = $PayloadURL
    }
}

function Get-ChannelVersion([string]$Feed, [string]$Channel) {
    Say-Invocation $MyInvocation

    if ($Channel -match "\d\.\d{1,2}") {
        return $Channel
    }

    $Version = Get-LatestVersion -Feed $Feed -Channel $Channel -InstallerType $InstallerTypes[0]
    if ($Version -match "(\d\.\d{1,2})") {
        return $Matches[0]
    }

    throw "Could not retrieve Channel version"
}

function Get-SelectedChannelVersions([string]$Feed) {
    Say-Invocation $MyInvocation

    $ChannelVersions = @()
    foreach ($Ch in $Channels) {
        $Version = Get-ChannelVersion -Feed $Feed -Channel $Ch
        if (-not $ChannelVersions.Contains($Version)) {
            $ChannelVersions += $Version
        }
    }

    return $ChannelVersions
}

function Get-OutputDirectory([string]$Channel, [string]$InstallerType) {
    Say-Invocation $MyInvocation

    $ChannelDir = Join-Path -Path $OutputDirectory -ChildPath $Channel
    if ($InstallerType.ToLower() -eq "sdk") {
        $OutDir = Join-Path -Path $ChannelDir -ChildPath "SDK"
    }
    else {
        $OutDir = Join-Path -Path $ChannelDir -ChildPath "Runtime"
    }

    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    return $OutDir
}

if ($Channels.Count -lt 1) {
    throw "At least one Channel should be selected."
}

if ($InstallerTypes.Count -lt 1) {
    throw "At least one InstallerType should be selected."
}

if ($Architectures.Count -lt 1) {
    throw "At least one Architecture should be selected."
}

if ($NoCdn) {
    $AzureFeed = $UncachedFeed
}

$ChannelVersions = Get-SelectedChannelVersions -Feed $AzureFeed
$DownloadLinks = @()

foreach ($Channel in $ChannelVersions) {
    foreach ($Installer in $InstallerTypes) {
        try {
            $Version = Get-LatestVersion -Feed $AzureFeed -Channel $Channel -InstallerType $Installer

            foreach ($Arc in $Architectures) {
                $DownloadInfo = Get-DownloadInfo -Feed $AzureFeed -SpecificVersion $Version -CLIArchitecture $Arc -InstallerType $Installer
                $FileUrl = $DownloadInfo.FileUrl
                if (-not $DownloadLinks.Contains($FileUrl)) {
                    $DownloadLinks += $FileUrl

                    $OutDir = Get-OutputDirectory -Channel $Channel -InstallerType $Installer
                    $OutFile = Join-Path -Path $OutDir -ChildPath $DownloadInfo.FileName
                    if (Test-Path -Path $OutFile) {
                        Say "'$OutFile' already exists - skipping..."
                        continue
                    }

                    Say("Downloading '$FileUrl' to '$OutFile'")
                    try {
                        Invoke-WebRequestWithRetry -Uri $FileUrl -OutFile $OutFile
                    }
                    catch {
                        Say "Error occurred during the operation of downloading '$FileUrl' to '$OutFile': $_"
                        Say-Verbose "$_.ScriptStackTrace"
                    }
                }
            }
        }
        catch {
            Say "Error occurred for Channel '$Channel' and InstallerType '$Installer': $_"
            Say-Verbose "$_.ScriptStackTrace"
        }
    }
}

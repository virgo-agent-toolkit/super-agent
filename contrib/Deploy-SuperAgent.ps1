#requires -Version 3
#Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

Write-Output '-------------------------------------------------------------------------------'
Write-Output 'Deploy and Start Fife (Super-Agent)'
Write-Output '-------------------------------------------------------------------------------'
Write-Output '-------------------------------------------------------------------------------'


$workspace = 'c:\super-agent'
New-Item -ItemType Directory -Path $workspace
Push-Location -Path $workspace


function Invoke-FileDowload
{
    [CmdletBinding()]
    Param
    (
        [String]$Url,
        [String]$localpath,
        [String]$Filename
    )
    if(!(Test-Path -Path $localpath))
    {
        New-Item $localpath -type directory > $null
    }

    $webclient = New-Object -TypeName System.Net.WebClient

    try
    {
        $webclient.DownloadFile($Url, $localpath + '\' + $Filename)
        Write-Output -InputObject "[$(Get-Date)] Downloaded Successfully $Filename in  $localpath"
    }
    catch [system.Exception]
    {
        Write-Error -Message "[$(Get-Date)] Download Failed for $Filename in  $localpath"
        Write-Error -Message "[$(Get-Date)] $_"
        $global:Buildstatus = +1
    }
}

function Install-MSI 
{
    param
    (
        [Object]
        $MsiPath,

        [Object]
        $MsiFile
    )

    $BuildArgs = @{
        FilePath     = 'msiexec'
        ArgumentList = '/quiet /passive /i ' + $MsiPath + '\' + $MsiFile
        Wait         = $true
    }
    Try 
    {
        Write-Output "[$(Get-Date)] Installing $MsiFile"
        Start-Process @BuildArgs  *>> $Logfile
    }
    Catch 
    {
        throw "[$(Get-Date)] Error installing the MSI: $_"
    }
}

function Download-File 
{
    param (
        [string]$Url,
        [string]$file
    )
    Write-Host "[$(Get-Date)] Downloading $Url to $file"
    $downloader = New-Object System.Net.WebClient
    $downloader.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    $downloader.DownloadFile($Url, $file)
}

Write-Output '-------------------------------------------------------------------------------'
Write-Output 'Install Google Chrome'
Write-Output '-------------------------------------------------------------------------------'
$ChromeMsi= 'https://dl.google.com/tag/s/appguid={00000000-0000-0000-0000-000000000000}&iid={00000000-0000-0000-0000-000000000000}&lang=en&browser=4&usagestats=0&appname=Google Chrome&needsadmin=true/dl/chrome/install/googlechromestandaloneenterprise64.msi'

Write-Output "[$(Get-Date)] Download Google Chrome"
Invoke-WebRequest -Uri $ChromeMsi -OutFile 'googlechromestandaloneenterprise64.msi'

Write-Output "[$(Get-Date)] Install Chrome"
Install-MSI -MsiPath $workspace -MsiFile 'googlechromestandaloneenterprise64.msi'

Write-Output '-------------------------------------------------------------------------------'
Write-Output "[$(Get-Date)] Install Git for Windows"
Write-Output '-------------------------------------------------------------------------------'

Write-Output "[$(Get-Date)] Download git"
$Gitfile = 'https://github.com/git-for-windows/git/releases/download/v2.8.3.windows.1/Git-2.8.3-64-bit.exe'
Invoke-WebRequest -Uri $Gitfile -OutFile 'Git-2.8.3-64-bit.exe'

Write-Output "[$(Get-Date)] Install git"
& '.\Git-2.8.3-64-bit.exe' /silent /install


Write-Output "[$(Get-Date)] Install Luvi and Lit"

$LUVI_VERSION = '2.7.2'
$LIT_VERSION = '3.3.3'

if (Test-Path env:LUVI_ARCH) 
{
    $LUVI_ARCH = $env:LUVI_ARCH
}
else 
{
    if ([System.Environment]::Is64BitProcess) 
    {
        $LUVI_ARCH = 'Windows-amd64'
    }
    else 
    {
        $LUVI_ARCH = 'Windows-ia32'
    }
}
$LUVI_URL = "https://github.com/luvit/luvi/releases/download/v$LUVI_VERSION/luvi-regular-$LUVI_ARCH.exe"
$LIT_URL = "https://lit.luvit.io/packages/luvit/lit/v$LIT_VERSION.zip"


Write-Output '-------------------------------------------------------------------------------'
Write-Output "[$(Get-Date)]  Download Files (Luvi.exe and lit.zip)"
Write-Output '-------------------------------------------------------------------------------'
Invoke-FileDowload -Url $LUVI_URL -localpath $workspace -Filename 'luvi.exe'
Invoke-FileDowload -Url $LIT_URL -localpath $workspace -Filename 'lit.zip'

Write-Output '-------------------------------------------------------------------------------'
Write-Output "[$(Get-Date)] Create lit.exe using lit"
Write-Output '-------------------------------------------------------------------------------'
Start-Process '.\luvi.exe' -ArgumentList 'lit.zip -- make lit.zip' -Wait -NoNewWindow

Write-Output "[$(Get-Date)] Remove lit.zip"
Remove-Item 'lit.zip'

Write-Output '-------------------------------------------------------------------------------'
Write-Output "[$(Get-Date)] Luvit and fife"
Write-Output '-------------------------------------------------------------------------------'
Write-Output '-------------------------------------------------------------------------------'
Write-Output "[$(Get-Date)] Build fife"
Write-Output '-------------------------------------------------------------------------------'
.\lit.exe make lit://virgo-agent-toolkit/fife fife.exe

Write-Output '-------------------------------------------------------------------------------'
Write-Output "[$(Get-Date)] Configure Fife"
Write-Output '-------------------------------------------------------------------------------'
$FifeConf = @"
mode = "standalone"
ip = "127.0.0.1"
port = 7000
webroot = "./super-agent"
"@

New-Item -Path $("$workspace\Fife.conf") -ItemType File -Value $FifeConf

Write-Output '-------------------------------------------------------------------------------'
Write-Output "[$(Get-Date)] Download the Client"
Write-Output '-------------------------------------------------------------------------------'
& 'C:\Program Files\Git\cmd\git.exe' clone --recursive https://github.com/virgo-agent-toolkit/super-agent.git

Write-Output '-------------------------------------------------------------------------------'
Write-Output "[$(Get-Date)] Start Fife"
Write-Output '-------------------------------------------------------------------------------'
.\fife.exe


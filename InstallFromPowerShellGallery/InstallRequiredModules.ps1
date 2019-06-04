param (
    # Parameter help description
    [string]
    $PacToken,

    [string[]]
    $ModuleName, # = "HalIT_AzRestApi",

    [string]
    $GalleryName = "HAL_PSGallery",

    [string]
    $Organisation = "heathrowautomation"
)

$ErrorActionPreference = 'Stop'

function Invoke-NuGet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]
        $ExePath,

        [Parameter(Mandatory)]
        [ValidateSet('sources')]
        [string]
        $Command,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $CliArgs
    )
    $errOut = New-TemporaryFile
    $stdOut = New-TemporaryFile

    $nugetArgs = @($command)
    $nugetArgs += $CliArgs

    Start-Process   `
        -FilePath $ExePath `
        -ArgumentList $nugetArgs `
        -RedirectStandardError $errOut `
        -RedirectStandardOutput $stdOut `
        -WindowStyle Hidden `
        -Wait

    $errLines = Get-Content $errOut
    $stdLines = Get-Content $stdOut
    Remove-Item $errOut,$stdOut -Force

    if ($null -ne $errLines) {
        Write-Error $errLines
    }
    $stdLines | ForEach-Object {Write-Host "[nuget]$($_)"}
    return $true
}

function Get-NuGetPath {
    [CmdletBinding()]
    param ()

    $agentPath = (Get-ChildItem env: | Where-Object {$_.Name -eq 'AGENT_HOMEDIRECTORY'} | Select-Object -ExpandProperty 'Value')
    if ([string]::IsNullOrEmpty($agentPath)) {
        Write-Error "Running locally, AGENT_HOMEDIRECTORY not found"
    }
    return (Get-ChildItem $agentPath -Recurse -Filter 'nuget.exe' | Select-Object -First 1).FullName
}

function Main {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $PacToken,

        [Parameter(Mandatory=$true)]
        [string[]]
        $ModuleName, # = "HalIT_AzRestApi",

        [Parameter(Mandatory=$false)]
        [string]
        $GalleryName = "HAL_PSGallery",

        [Parameter(Mandatory=$false)]
        [string]
        $Organisation = "heathrowautomation"
    )
    begin {
        Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} STARTED' -f (Get-Date),"Main")
    }
    process {
        $nugetExePath = (Get-NuGetPath)
        if ($null -eq $nugetExePath) {
            Write-Error "Unable to locate nuget.exe"
        }
        Write-Host "Add repository source"

        $cliArgs = @(
            'add'
            '-Name'
            "$GalleryName"
            '-Username'
            'vsts'
            '-Password'
            "$PacToken"
            '-StorePasswordInClearText'
            '-Source'
            ("https://pkgs.dev.azure.com/{0}/_packaging/{1}/nuget/v3/index.json" -f $Organisation,$GalleryName)
        )
        
        Invoke-NuGet -ExePath -Command 'sources' -CliArgs $cliArgs            
    }
    end {
        Write-Verbose ('[{0:yyyy-MM-dd HH:mm:ss}] {1} ENDED' -f (Get-Date),"Main")
    }
}

if ($null -eq (Get-PSCallStack | Where-Object {$_.Command.ToLower().Contains('tests.ps1')})) {
    $params = @{
        "PacToken"      = $PacToken
        "ModuleName"    = $ModuleName
        "GalleryName"   = $GalleryName
        "Organisation"  = $Organisation
    }
    (Main @params)
}

<# Write-Host "Create credential from PAT"
$cred = New-Object System.Management.Automation.PSCredential ("username", (ConvertTo-SecureString $PacToken -AsPlainText -Force))

Write-Host "Check if $GalleryName is registered"
$gSettings = Get-PSRepository | Where-Object {$_.Name -eq $GalleryName}
if ($null -eq $gSettings) {
    try {
        Write-Host "Register $GalleryName"
        Register-PSRepository -Name $GalleryName -SourceLocation "https://pkgs.dev.azure.com/$($Organisation)/_packaging/$($GalleryName)/nuget/v2" -PublishLocation "https://pkgs.dev.azure.com/<org_name>/_packaging/<feed_name>/nuget/v2" -InstallationPolicy Trusted
        $gSettings = Get-PSRepository | Where-Object {$_.Name -eq $GalleryName}
    } catch {
        throw
    }
}

Write-Host "Check if $ModuleName can be found in $GalleryName"
$repoModule = (Find-Module -Repository $GalleryName -Credential $cred -Name $ModuleName)

if ($null -ne $repoModule) {
    $localModule = (Get-Module -ListAvailable $ModuleName)
    if ($null -eq $localModule) {
        Write-Host "Install $ModuleName v$($repoModule.Version) from $GalleryName"
        Install-Module $ModuleName -Repository $GalleryName -Credential $cred
    } elseif ($localModule.Version -ne $repoModule.Version) {
        Write-Host "Update $ModuleName v$($repoModule.Version) from $GalleryName"
        Update-Module $ModuleName -Repository $GalleryName -Credential $cred
    }
} else {
    Write-Error "$ModuleName not found in $GalleryName"
}
Get-Module -ListAvailable | ForEach-Object {Write-Host $_.Name} #>
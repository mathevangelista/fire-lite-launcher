# Diagnostico-FireStick.ps1
# Coleta somente leitura para Fire TV Stick via ADB e REA (opcional).
# Requisitos: Windows PowerShell 5.1+ e Android Platform-Tools.

[CmdletBinding()]
param(
    [string]$Serial
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$adbCandidates = @(
    (Join-Path $HOME 'platform-tools\adb.exe'),
    (Join-Path $PSScriptRoot 'adb.exe')
)

$adbExe = $null
foreach ($candidate in $adbCandidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $adbExe = (Resolve-Path -LiteralPath $candidate).Path
        break
    }
}

if (-not $adbExe) {
    $adbCommand = Get-Command 'adb.exe' -ErrorAction SilentlyContinue
    if ($adbCommand) {
        $adbExe = $adbCommand.Source
    }
}

if (-not $adbExe) {
    throw 'adb.exe nao encontrado. Instale o Platform-Tools em $HOME\platform-tools ou adicione adb.exe ao PATH.'
}

$deviceOutput = @(& $adbExe devices)
if ($LASTEXITCODE -ne 0) {
    throw 'Falha ao executar adb devices.'
}

$connectedDevices = @(
    foreach ($line in $deviceOutput) {
        if ($line -match '^\s*(\S+)\s+device(?:\s|$)') {
            $Matches[1]
        }
    }
)

if (-not $Serial) {
    if ($connectedDevices.Count -ne 1) {
        throw 'Conecte e autorize apenas um dispositivo, ou informe -Serial "IP:5555". Confira com adb devices.'
    }
    $Serial = $connectedDevices[0]
}
elseif ($Serial -notin $connectedDevices) {
    throw "Dispositivo '$Serial' nao esta conectado/autorizado. Execute adb connect IP:5555 e confira adb devices."
}

$documents = [Environment]::GetFolderPath('MyDocuments')
if ([string]::IsNullOrWhiteSpace($documents)) {
    $documents = $HOME
}

$baseDir = Join-Path $documents 'FireStick-Diagnosticos'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$outputDir = Join-Path $baseDir $stamp
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

function Save-CommandOutput {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $target = Join-Path $outputDir ($FileName + '.txt')
    $previousErrorAction = $ErrorActionPreference
    try {
        # Algumas versoes do PowerShell tratam stderr de programas nativos
        # como erro terminante quando ErrorActionPreference = Stop.
        $ErrorActionPreference = 'Continue'
        & $Executable @Arguments 2>&1 | Out-File -FilePath $target -Encoding UTF8
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }

    if ($exitCode -ne 0) {
        Write-Warning "Comando falhou (codigo $exitCode): $FileName. Consulte $target"
    }
}

function Save-AdbShell {
    param(
        [string]$FileName,
        [string[]]$ShellArguments
    )

    $arguments = @('-s', $Serial, 'shell') + $ShellArguments
    Save-CommandOutput -FileName $FileName -Executable $adbExe -Arguments $arguments
}

function Save-Snapshot {
    param([string]$Label)

    Write-Host "Coletando $Label ..."
    Save-AdbShell -FileName "$Label-memoria" -ShellArguments @('dumpsys', 'meminfo')
    Save-AdbShell -FileName "$Label-cpu" -ShellArguments @('top', '-b', '-n', '1')
    Save-AdbShell -FileName "$Label-launcher-memoria" -ShellArguments @('dumpsys', 'meminfo', 'com.amazon.tv.launcher')
    Save-AdbShell -FileName "$Label-launcher-gfxinfo" -ShellArguments @('dumpsys', 'gfxinfo', 'com.amazon.tv.launcher', 'framestats')
    Save-AdbShell -FileName "$Label-foco" -ShellArguments @('dumpsys', 'window', 'windows')
}

Write-Host "Fire Stick: $Serial"
Write-Host "Pasta dos resultados: $outputDir"

@(
    "Serial: $Serial"
    "Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "ADB: $adbExe"
    'Alteracoes permanentes no aparelho: nenhuma'
) | Out-File -FilePath (Join-Path $outputDir 'LEIA-ME.txt') -Encoding UTF8

Save-AdbShell -FileName 'dispositivo-versao' -ShellArguments @('getprop', 'ro.build.version.release')
Save-AdbShell -FileName 'dispositivo-modelo' -ShellArguments @('getprop', 'ro.product.model')
Save-AdbShell -FileName 'armazenamento' -ShellArguments @('df', '-h', '/data')
Save-AdbShell -FileName 'pacotes-desativados' -ShellArguments @('pm', 'list', 'packages', '-d')

foreach ($setting in @('window_animation_scale', 'transition_animation_scale', 'animator_duration_scale')) {
    Save-AdbShell -FileName "animacao-$setting" -ShellArguments @('settings', 'get', 'global', $setting)
}

$rea = Get-Command 'rea.cmd' -ErrorAction SilentlyContinue
if ($rea) {
    Write-Host 'REA detectado. Coletando inventario e metadados dos pacotes...'
    $env:REA_ADB_PATH = $adbExe
    Save-CommandOutput -FileName 'rea-dispositivo' -Executable $rea.Source -Arguments @('inspect-adb-device', $Serial)
    Save-CommandOutput -FileName 'rea-processos' -Executable $rea.Source -Arguments @('list-adb-processes', $Serial)

    foreach ($package in @(
        'com.amazon.tv.launcher',
        'com.amazon.bueller.photos',
        'com.amazon.ssmsys',
        'com.amazon.venezia'
    )) {
        Save-CommandOutput -FileName "rea-pacote-$package" -Executable $rea.Source -Arguments @('inspect-adb-package', $Serial, $package)
    }
}
else {
    Write-Warning 'REA nao encontrado no PATH. A coleta por ADB continuara normalmente.'
    'REA nao encontrado. Instale com: npm.cmd install --global rea-agents' |
        Out-File -FilePath (Join-Path $outputDir 'rea-indisponivel.txt') -Encoding UTF8
}

Read-Host 'Deixe o Fire Stick na TELA INICIAL e pressione ENTER para a primeira coleta'
Save-Snapshot -Label '01-tela-inicial'

Read-Host 'Ao pressionar ENTER, navegue pelos menus e aplicativos enquanto o script mede a CPU'
for ($sample = 1; $sample -le 6; $sample++) {
    Save-AdbShell -FileName ("02-durante-navegacao-cpu-{0:D2}" -f $sample) -ShellArguments @('top', '-b', '-n', '1')
    Start-Sleep -Seconds 5
}
Read-Host 'Volte a TELA INICIAL e pressione ENTER para a coleta final'
Save-Snapshot -Label '03-apos-navegacao'

$zipFile = "$outputDir.zip"
try {
    Compress-Archive -Path (Join-Path $outputDir '*') -DestinationPath $zipFile -CompressionLevel Optimal
    Write-Host "Arquivo para compartilhar: $zipFile"
}
catch {
    Write-Warning "Nao foi possivel gerar ZIP: $($_.Exception.Message)"
    Write-Host "Arquivos disponiveis em: $outputDir"
}

Write-Host 'Diagnostico concluido. Nenhum pacote foi encerrado, desativado ou desinstalado.'

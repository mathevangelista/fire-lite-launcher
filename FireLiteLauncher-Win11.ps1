#requires -Version 5.1
<#
.SYNOPSIS
  Diagnostica, compila, instala, abre ou remove o Fire Lite Launcher no Fire TV.
.DESCRIPTION
  Requer Windows 11, Android SDK Platform 35, Platform-Tools e JDK 17-21.
  Localiza JDKs instalados por WinGet, Android Studio, Microsoft e outros.
  Aceita -JdkPath caso o JDK esteja em uma pasta personalizada.
  Baixa o Gradle 8.7 oficial e verifica o checksum SHA-256.
  Grava a saida COMPLETA da compilacao em logs\gradle-build.log.
  Nunca remove ou desativa componentes originais do Fire OS.
.EXAMPLE
  .\FireLiteLauncher-Win11.ps1 -Acao Diagnosticar
.EXAMPLE
  .\FireLiteLauncher-Win11.ps1 -Acao Compilar
.EXAMPLE
  .\FireLiteLauncher-Win11.ps1 -Acao Instalar -Serial 'IP_DO_FIRE_STICK:5555'
.EXAMPLE
  .\FireLiteLauncher-Win11.ps1 -Acao Instalar -Recompilar
.EXAMPLE
  .\FireLiteLauncher-Win11.ps1 -Acao Compilar -JdkPath 'C:\Program Files\Microsoft\jdk-17.0.x-hotspot'
.EXAMPLE
  .\FireLiteLauncher-Win11.ps1 -Acao Remover
#>
[CmdletBinding()]
param(
    [ValidateSet('Diagnosticar', 'Compilar', 'Instalar', 'Abrir', 'Remover')]
    [string]$Acao = 'Compilar',
    [string]$Serial = '',
    [switch]$Recompilar,
    [string]$JdkPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$PackageName = 'br.com.matheus.firelitelauncher'
$MainComponent = "$PackageName/.MainActivity"
$ApkPath = Join-Path $ProjectRoot 'app\build\outputs\apk\debug\app-debug.apk'
$GradleVersion = '8.7'
$LogDirectory = Join-Path $ProjectRoot 'logs'
$BuildLog = Join-Path $LogDirectory 'gradle-build.log'

function Resolve-AndroidSdk {
    $candidates = @()
    if ($env:ANDROID_HOME) { $candidates += $env:ANDROID_HOME }
    if ($env:ANDROID_SDK_ROOT) { $candidates += $env:ANDROID_SDK_ROOT }
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Android\Sdk') }

    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath (Join-Path $path 'platforms\android-35\android.jar') -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $path).Path
        }
    }
    throw 'Android SDK Platform 35 nao encontrado. Instale Android 15 (API 35) no Android Studio > SDK Manager.'
}

function Resolve-JavaHome {
    # JAVA_HOME e apenas uma das fontes. JDKs instalados pelo WinGet,
    # Android Studio e distribuidoras Java sao procurados automaticamente.
    $candidates = New-Object 'System.Collections.Generic.List[string]'

    function Add-JdkCandidate([string]$path) {
        if (-not [string]::IsNullOrWhiteSpace($path)) {
            $candidates.Add([Environment]::ExpandEnvironmentVariables($path.Trim('"').TrimEnd('\')))
        }
    }

    if ($JdkPath) { Add-JdkCandidate $JdkPath }
    if (-not $JdkPath) {
        Add-JdkCandidate $env:JAVA_HOME
        Add-JdkCandidate $env:JDK_HOME
        Add-JdkCandidate $env:STUDIO_JDK

        $programDirs = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA) |
            Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } |
            Select-Object -Unique

        foreach ($pf in $programDirs) {
            Add-JdkCandidate (Join-Path $pf 'Android\Android Studio\jbr')
            Add-JdkCandidate (Join-Path $pf 'Android\Android Studio\jre')
            Add-JdkCandidate (Join-Path $pf 'Programs\Android Studio\jbr')
            Add-JdkCandidate (Join-Path $pf 'Programs\Android Studio\jre')
            Add-JdkCandidate (Join-Path $pf 'Android Studio\jbr')

            # Wildcards apenas nas pastas de instalacao, sem varrer o disco.
            $patterns = @(
                'Microsoft\jdk-17*', 'Microsoft\jdk-21*',
                'Eclipse Adoptium\jdk-17*', 'Eclipse Adoptium\jdk-21*',
                'Java\jdk-17*', 'Java\jdk-21*',
                'Amazon Corretto\jdk17*', 'Amazon Corretto\jdk21*',
                'Zulu\zulu-17*', 'Zulu\zulu-21*',
                'BellSoft\LibericaJDK-17*', 'BellSoft\LibericaJDK-21*',
                'Programs\Eclipse Adoptium\jdk-17*',
                'Programs\Eclipse Adoptium\jdk-21*'
            )
            foreach ($pattern in $patterns) {
                @(Get-Item -Path (Join-Path $pf $pattern) -ErrorAction SilentlyContinue) | ForEach-Object {
                    if ($_.PSIsContainer) { Add-JdkCandidate $_.FullName }
                }
            }
        }

        # Um JDK no PATH pode existir fora das pastas padrao.
        foreach ($pathItem in ($env:PATH -split ';')) {
            if (-not $pathItem) { continue }
            $directory = $pathItem.Trim('"').TrimEnd('\')
            if ($directory -match '(?i)\\bin$' -and
                (Test-Path -LiteralPath (Join-Path $directory 'javac.exe') -PathType Leaf)) {
                Add-JdkCandidate (Split-Path -Parent $directory)
            }
        }
    }

    $checked = New-Object 'System.Collections.Generic.List[string]'
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $javaExe = Join-Path $candidate 'bin\java.exe'
        $javacExe = Join-Path $candidate 'bin\javac.exe'
        if (-not (Test-Path -LiteralPath $javaExe -PathType Leaf) -or
            -not (Test-Path -LiteralPath $javacExe -PathType Leaf)) { continue }

        try {
            $infoLines = @(& $javaExe '--version' 2>&1)
            $exitCode = $LASTEXITCODE
            if ($exitCode -ne 0) { continue }
            $javaInfo = ($infoLines | Out-String).Trim()
            $match = [regex]::Match($javaInfo, '(?m)^(?:openjdk|java)\s+(\d+)(?:\.|\s|$)')
            if (-not $match.Success) { continue }
            $major = [int]$match.Groups[1].Value
            $checked.Add("$candidate [Java $major]")
            if ($major -ge 17 -and $major -le 21) {
                $resolved = (Resolve-Path -LiteralPath $candidate).Path
                $env:JAVA_HOME = $resolved
                # Evita conflito se houver um java.exe mais antigo no PATH.
                $env:PATH = (Join-Path $resolved 'bin') + ';' + $env:PATH
                return [pscustomobject]@{
                    Home = $resolved
                    Major = $major
                    Version = ($javaInfo -split "`n")[0].Trim()
                }
            }
        }
        catch {
            Write-Warning "Nao foi possivel consultar Java em '$candidate': $($_.Exception.Message)"
        }
    }

    if ($JdkPath) {
        throw "JDK invalido em '$JdkPath'. Informe a PASTA do JDK 17/21 (contendo bin\java.exe e bin\javac.exe)."
    }

    $found = if ($checked.Count -gt 0) { $checked -join '; ' } else { 'Nenhum JDK completo foi encontrado nas pastas verificadas.' }
    throw @"
JDK 17 ou 21 nao encontrado. $found
Instale pelo PowerShell: winget install --id Microsoft.OpenJDK.17 --exact
Feche e reabra o PowerShell; execute -Acao Diagnosticar novamente.
Opcional: -JdkPath 'C:\Program Files\Microsoft\jdk-17.0.x-hotspot'
"@
}
function Get-GradleExecutable {
    if (-not $env:LOCALAPPDATA) {
        throw 'LOCALAPPDATA nao definido. Execute o script em uma sessao de usuario do Windows.'
    }
    $baseDir = Join-Path $env:LOCALAPPDATA 'FireLiteLauncher\tools'
    $distributionDir = Join-Path $baseDir "gradle-$GradleVersion"
    $exe = Join-Path $distributionDir 'bin\gradle.bat'
    if (Test-Path -LiteralPath $exe -PathType Leaf) { return $exe }

    New-Item -ItemType Directory -Force -Path $baseDir | Out-Null
    $zip = Join-Path $baseDir "gradle-$GradleVersion-bin.zip"
    $hashFile = "$zip.sha256"
    $baseUrl = "https://services.gradle.org/distributions/gradle-$GradleVersion-bin.zip"
    Write-Host "Baixando Gradle $GradleVersion oficial..."
    Invoke-WebRequest -Uri $baseUrl -OutFile $zip -UseBasicParsing
    Invoke-WebRequest -Uri "$baseUrl.sha256" -OutFile $hashFile -UseBasicParsing

    $expected = ((Get-Content -LiteralPath $hashFile -Raw).Trim() -split '\s+')[0].ToUpperInvariant()
    $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($expected -notmatch '^[0-9A-F]{64}$' -or $expected -ne $actual) {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        throw 'O checksum SHA-256 do Gradle nao confere. Download rejeitado.'
    }

    Write-Host 'Extraindo distribuicao Gradle verificada...'
    Expand-Archive -LiteralPath $zip -DestinationPath $baseDir -Force
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw 'gradle.bat nao encontrado apos a extracao.'
    }
    return $exe
}

function Get-AdbExecutable {
    $candidates = @()
    if ($env:ANDROID_HOME) { $candidates += (Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe') }
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe') }
    $candidates += (Join-Path $HOME 'platform-tools\adb.exe')
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    $command = Get-Command 'adb.exe' -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw 'adb.exe nao encontrado. Instale Android Platform-Tools ou copie para $HOME\platform-tools.'
}

function Get-TargetSerial([string]$adb) {
    $devices = @(& $adb devices)
    if ($LASTEXITCODE -ne 0) { throw 'adb devices falhou.' }
    $available = @($devices | Where-Object { $_ -match '^([^\s]+)\s+device\s*$' } |
        ForEach-Object { ([regex]::Match($_, '^([^\s]+)')).Groups[1].Value })
    if ($Serial) {
        if ($available -notcontains $Serial) {
            throw "Dispositivo '$Serial' nao autorizado/conectado. Verifique adb devices e adb connect IP:5555."
        }
        return $Serial
    }
    if ($available.Count -ne 1) {
        throw "Esperado exatamente 1 dispositivo ADB autorizado; encontrados: $($available.Count). Use -Serial."
    }
    return $available[0]
}

function Invoke-ADB([string]$adb, [string]$device, [string[]]$arguments) {
    & $adb '-s' $device @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "ADB retornou $LASTEXITCODE ao executar: $($arguments -join ' ')"
    }
}

function Write-Environment {
    $sdk = Resolve-AndroidSdk
    $jdk = Resolve-JavaHome
    $env:ANDROID_HOME = $sdk
    Write-Host "Projeto      : $ProjectRoot"
    Write-Host "Android SDK  : $sdk"
    Write-Host "JDK          : $($jdk.Home)"
    Write-Host "Java         : $($jdk.Version)"
    $adb = $null
    try { $adb = Get-AdbExecutable } catch { Write-Warning $_.Exception.Message }
    if ($adb) { Write-Host "ADB          : $adb" }
}

function Build-FireLiteApk {
    Write-Environment
    $gradle = Get-GradleExecutable
    New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null
    Write-Host "Gradle       : $gradle"
    Write-Host "Log          : $BuildLog"
    Write-Host 'Compilando com --stacktrace e --console=plain...'

    $exitCode = -1
    Push-Location $ProjectRoot
    try {
        # Registrar stdout e stderr na MESMA saida, no console e em arquivo.
        # PowerShell 5.1 pode transformar stderr nativo em NativeCommandError:
        # EAP=Continue evita uma excecao artificial nesse redirecionamento.
        $previousEap = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & $gradle ':app:assembleDebug' '--no-daemon' '--stacktrace' '--console=plain' 2>&1 |
                Tee-Object -FilePath $BuildLog
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousEap
        }
    }
    finally {
        Pop-Location
    }

    if ($exitCode -ne 0) {
        Write-Host ''
        Write-Host '=== RESUMO DO ERRO GRADLE (final do log) ===' -ForegroundColor Yellow
        if (Test-Path -LiteralPath $BuildLog -PathType Leaf) {
            Get-Content -LiteralPath $BuildLog -Tail 70 | ForEach-Object { Write-Host $_ }
        }
        Write-Host "Log completo: $BuildLog" -ForegroundColor Yellow
        throw "Compilacao falhou (codigo $exitCode). Consulte a primeira ocorrencia de '* What went wrong:' no log."
    }

    if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
        throw "Gradle terminou sem gerar o APK: $ApkPath"
    }
    Write-Host "APK criado: $ApkPath" -ForegroundColor Green
}

switch ($Acao) {
    'Diagnosticar' {
        Write-Environment
        Write-Host "Gradle       : sera validado/baixado durante -Acao Compilar"
        Write-Host 'JDK e Android SDK encontrados. Execute -Acao Compilar para validar o projeto.' -ForegroundColor Green
    }
    'Compilar' {
        Build-FireLiteApk
    }
    'Instalar' {
        if ($Recompilar -or -not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
            Build-FireLiteApk
        }
        $adb = Get-AdbExecutable
        $device = Get-TargetSerial $adb
        Write-Host "Instalando em $device (launcher Amazon permanece intacto)..."
        Invoke-ADB $adb $device @('install', '-r', $ApkPath)
        Write-Host 'Instalacao concluida.' -ForegroundColor Green
        Invoke-ADB $adb $device @('shell', 'am', 'start', '-n', $MainComponent)
    }
    'Abrir' {
        $adb = Get-AdbExecutable
        $device = Get-TargetSerial $adb
        Invoke-ADB $adb $device @('shell', 'am', 'start', '-n', $MainComponent)
    }
    'Remover' {
        $adb = Get-AdbExecutable
        $device = Get-TargetSerial $adb
        Write-Host "Remover SOMENTE $PackageName em $device?"
        $confirmation = Read-Host 'Digite REMOVER para confirmar'
        if ($confirmation -cne 'REMOVER') { Write-Host 'Cancelado.'; break }
        Invoke-ADB $adb $device @('uninstall', $PackageName)
        Write-Host 'Launcher alternativo removido; Fire OS original preservado.' -ForegroundColor Green
    }
}

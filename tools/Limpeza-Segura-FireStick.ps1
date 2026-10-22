# Limpeza-Segura-FireStick.ps1
# PowerShell 5.1+ / Windows 11 / Fire OS 7
# Base: captura de uso de 21/10/2026. Nenhuma alteracao sem acao explicita.
# A desativacao preserva os dados do aplicativo e pode ser revertida com -Acao Reativar.

[CmdletBinding()]
param(
    [ValidateSet('Relatorio', 'Desativar', 'Reativar')]
    [string]$Acao = 'Relatorio',

    [string[]]$Apps = @(),

    [string]$Serial = '',

    [string]$AdbPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Lista conservadora. Aplicativos do sistema, Netflix e apps com uso recente
# nao estao autorizados para alteracao neste script.
$Candidatos = @(
    [pscustomobject]@{ Nome = 'YouTube';   Alias = 'Youtube';   Pacote = 'com.amazon.firetv.youtube'; UltimoUso = '2026-09-19'; Classificacao = 'Ultimo uso ha mais de 7 dias' },
    [pscustomobject]@{ Nome = 'Globoplay'; Alias = 'Globoplay'; Pacote = 'com.globo.globotv';       UltimoUso = '2026-10-11'; Classificacao = 'Ultimo uso ha mais de 7 dias' },
    [pscustomobject]@{ Nome = 'Disney+';   Alias = 'Disney';    Pacote = 'com.disney.disneyplus';    UltimoUso = '2026-08-26'; Classificacao = 'Ultimo uso ha mais de 7 dias' },
    [pscustomobject]@{ Nome = 'Viki';      Alias = 'Viki';      Pacote = 'com.viki.kindle';          UltimoUso = '';           Classificacao = 'Sem historico suficiente' },
    [pscustomobject]@{ Nome = 'Downloader';Alias = 'Downloader';Pacote = 'com.esaba.downloader';     UltimoUso = '';           Classificacao = 'Sem historico suficiente' }
)

function Encontrar-Adb {
    if (-not [string]::IsNullOrWhiteSpace($AdbPath)) {
        if (-not (Test-Path -LiteralPath $AdbPath -PathType Leaf)) {
            throw "ADB nao encontrado no caminho informado: $AdbPath"
        }
        return (Resolve-Path -LiteralPath $AdbPath).Path
    }

    foreach ($caminho in @(
        (Join-Path $PSScriptRoot 'adb.exe'),
        (Join-Path $HOME 'platform-tools\adb.exe')
    )) {
        if (Test-Path -LiteralPath $caminho -PathType Leaf) {
            return (Resolve-Path -LiteralPath $caminho).Path
        }
    }

    $comando = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($null -ne $comando) { return $comando.Source }
    throw 'adb.exe nao encontrado. Informe -AdbPath ou instale o Android Platform-Tools.'
}

$AdbExe = Encontrar-Adb

function Executar-Adb {
    param([Parameter(Mandatory = $true)][string[]]$Argumentos)

    $resultado = & $script:AdbExe @Argumentos 2>&1
    $codigoSaida = $LASTEXITCODE
    $texto = ($resultado | Out-String).Trim()

    if ($codigoSaida -ne 0 -or $texto -match '(?im)^\s*(SecurityException|java\.lang\..*Exception|Exception occurred|Error:|Failure\b)') {
        throw "Falha no ADB (codigo $codigoSaida). Comando: $($Argumentos -join ' ')`n$texto"
    }
    return $texto
}

$dispositivos = @( & $AdbExe devices )
if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel consultar os dispositivos ADB.' }
$autorizados = @(
    foreach ($linha in $dispositivos) {
        if ($linha -match '^\s*(\S+)\s+device\s*$') { $Matches[1] }
    }
)

if ([string]::IsNullOrWhiteSpace($Serial)) {
    if ($autorizados.Count -eq 0) { throw 'Nenhum dispositivo ADB autorizado. Conecte o Fire Stick e aceite a solicitacao na TV.' }
    if ($autorizados.Count -gt 1) { throw 'Ha mais de um dispositivo conectado. Informe -Serial "IP:5555".' }
    $Serial = $autorizados[0]
} elseif ($Serial -notin $autorizados) {
    throw "O dispositivo '$Serial' nao esta autorizado/conectado. Verifique: adb devices"
}

function Executar-FireStick {
    param([Parameter(Mandatory = $true)][string[]]$Comando)
    return (Executar-Adb -Argumentos (@('-s', $script:Serial) + $Comando))
}

function Listar-Pacotes {
    param([string[]]$Opcoes)
    $saida = Executar-FireStick -Comando (@('shell', 'pm', 'list', 'packages') + $Opcoes + @('--user', '0'))
    return @($saida -split '\r?\n' | Where-Object { $_ -match '^package:' } | ForEach-Object { $_.Substring(8).Trim() })
}

$instaladosUsuario = @(Listar-Pacotes -Opcoes @('-3'))
$desativados = @(Listar-Pacotes -Opcoes @('-d'))

$documentos = [Environment]::GetFolderPath('MyDocuments')
if ([string]::IsNullOrWhiteSpace($documentos)) { $documentos = $HOME }
$pasta = Join-Path $documentos 'FireStick-Limpeza'
New-Item -ItemType Directory -Path $pasta -Force | Out-Null
$agora = Get-Date -Format 'yyyyMMdd-HHmmss'

$relatorio = @(
    foreach ($item in $Candidatos) {
        $presente = $item.Pacote -in $instaladosUsuario
        $desativado = $item.Pacote -in $desativados
        [pscustomobject]@{
            App          = $item.Nome
            Alias        = $item.Alias
            Pacote       = $item.Pacote
            UltimoUso    = $item.UltimoUso
            Classificacao = $item.Classificacao
            Instalado    = $presente
            Estado       = if (-not $presente) { 'Ausente da lista -3' } elseif ($desativado) { 'Desativado' } else { 'Ativo' }
        }
    }
)

$arquivoRelatorio = Join-Path $pasta "candidatos-$agora.csv"
$relatorio | Export-Csv -LiteralPath $arquivoRelatorio -Encoding UTF8 -NoTypeInformation -Delimiter ';'

Write-Host "`nFire Stick: $Serial"
Write-Host 'Historico analisado: 21/10/2026 (datas NAO atualizadas automaticamente)'
$relatorio | Format-Table App, UltimoUso, Classificacao, Estado -AutoSize
Write-Host "Relatorio CSV: $arquivoRelatorio"

if ($Acao -eq 'Relatorio') {
    Write-Host "`nNenhuma alteracao realizada. Use -Acao Desativar -Apps Youtube,Globoplay para testar apos revisao."
    return
}

if ($Apps.Count -eq 0) {
    throw "A acao '$Acao' exige -Apps com nomes da lista autorizada. Nenhum pacote foi alterado."
}

$escolhidos = New-Object System.Collections.Generic.List[object]
foreach ($nome in $Apps) {
    $correspondentes = @($Candidatos | Where-Object {
        $_.Alias -ieq $nome -or $_.Nome -ieq $nome -or $_.Pacote -ieq $nome
    })
    if ($correspondentes.Count -ne 1) {
        throw "App '$nome' nao autorizado. Permitidos: $($Candidatos.Alias -join ', ')."
    }
    $item = $correspondentes[0]
    if (@($escolhidos | ForEach-Object { $_.Pacote }) -contains $item.Pacote) { continue }
    if ($item.Pacote -notin $instaladosUsuario) {
        throw "O pacote $($item.Pacote) nao aparece na lista de apps de usuario (-3)."
    }
    $escolhidos.Add($item)
}

# Snapshot para facilitar auditoria. Nao remove nem altera dados.
$inventarioAntes = Join-Path $pasta "pacotes-antes-$agora.txt"
Executar-FireStick -Comando @('shell', 'pm', 'list', 'packages', '--user', '0') |
    Set-Content -LiteralPath $inventarioAntes -Encoding UTF8

$log = New-Object System.Collections.Generic.List[object]
foreach ($item in $escolhidos) {
    $jaDesativado = $item.Pacote -in $desativados
    $acaoNecessaria = if ($Acao -eq 'Desativar') { -not $jaDesativado } else { $jaDesativado }

    if (-not $acaoNecessaria) {
        Write-Host "$($item.Nome): ja esta no estado solicitado."
        continue
    }

    Write-Host "`nAplicativo: $($item.Nome) [$($item.Pacote)]"
    Write-Host "Ultimo uso: $($item.UltimoUso) | $($item.Classificacao)"
    $resposta = Read-Host "Digite SIM para $Acao este aplicativo (qualquer outra resposta cancela)"
    if ($resposta -cne 'SIM') {
        Write-Host 'Ignorado.'
        continue
    }

    try {
        if ($Acao -eq 'Desativar') {
            $retorno = Executar-FireStick -Comando @('shell', 'pm', 'disable-user', '--user', '0', $item.Pacote)
        } else {
            $retorno = Executar-FireStick -Comando @('shell', 'pm', 'enable', '--user', '0', $item.Pacote)
        }

        $estadoAtual = @(Listar-Pacotes -Opcoes @('-d'))
        $desativadoAgora = $item.Pacote -in $estadoAtual
        $confirmado = if ($Acao -eq 'Desativar') { $desativadoAgora } else { -not $desativadoAgora }
        if (-not $confirmado) {
            throw "O gerenciador de pacotes nao confirmou o novo estado. Resposta: $retorno"
        }
        $log.Add([pscustomobject]@{ Data = (Get-Date); Aplicativo = $item.Nome; Pacote = $item.Pacote; Acao = $Acao; Resultado = 'OK' })
        Write-Host "Concluido: $($item.Nome) - $Acao."
        $desativados = $estadoAtual
    }
    catch {
        $log.Add([pscustomobject]@{ Data = (Get-Date); Aplicativo = $item.Nome; Pacote = $item.Pacote; Acao = $Acao; Resultado = "FALHA: $($_.Exception.Message)" })
        Write-Warning $_.Exception.Message
    }
}

if ($log.Count -gt 0) {
    $arquivoLog = Join-Path $pasta "operacoes-$agora.csv"
    $log | Export-Csv -LiteralPath $arquivoLog -Encoding UTF8 -NoTypeInformation -Delimiter ';'
    Write-Host "`nLog de operacoes: $arquivoLog"
}
Write-Host 'Finalizado. Nenhum app foi desinstalado e nenhum dado foi apagado.'

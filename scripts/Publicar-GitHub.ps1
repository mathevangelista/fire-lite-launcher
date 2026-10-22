#requires -Version 5.1
<#
.SYNOPSIS
  Cria e publica um repositorio privado no GitHub a partir deste projeto.
.DESCRIPTION
  Requer Git e GitHub CLI (gh) autenticado. Para seguranca, exige revisao
  interativa dos arquivos staged antes de criar qualquer commit/publicacao.
  Nao sobrescreve repositorios, nao faz push --force e nao envia dumps
  intencionalmente ignorados no .gitignore.
.EXAMPLE
  .\scripts\Publicar-GitHub.ps1 -NomeRepositorio 'fire-lite-launcher'
.EXAMPLE
  .\scripts\Publicar-GitHub.ps1 -NomeRepositorio 'fire-lite-launcher' -Visibilidade public
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9_.-]+$')]
    [string]$NomeRepositorio = 'fire-lite-launcher',

    [ValidateSet('private', 'public')]
    [string]$Visibilidade = 'private'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$raiz = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

function Exigir-Comando {
    param([Parameter(Mandatory = $true)][string]$Nome)
    if (-not (Get-Command $Nome -ErrorAction SilentlyContinue)) {
        throw "Comando '$Nome' nao encontrado. Instale Git e GitHub CLI com winget e reinicie o PowerShell."
    }
}

function Conferir-Saida {
    param([Parameter(Mandatory = $true)][string]$Descricao)
    if ($LASTEXITCODE -ne 0) {
        throw "$Descricao falhou (codigo $LASTEXITCODE). Nenhum push adicional sera realizado."
    }
}

Exigir-Comando -Nome 'git.exe'
Exigir-Comando -Nome 'gh.exe'

Write-Host "Diretorio do projeto: $raiz"
Write-Host "Repositorio solicitado: $NomeRepositorio"
Write-Host "Visibilidade inicial: $Visibilidade"

# Nao executa gh auth login automaticamente nem coleta tokens.
& gh.exe auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'GitHub CLI nao autenticado. Execute gh auth login e depois rode novamente este script.'
}

Push-Location -LiteralPath $raiz
try {
    $gitDir = Join-Path $raiz '.git'
    if (-not (Test-Path -LiteralPath $gitDir)) {
        # Evita iniciar um repo dentro de outro, sem provocar erro nativo
        # de 'git rev-parse' no PowerShell 5.1 (EAP=Stop).
        $pastaPai = (Get-Item -LiteralPath $raiz).Parent
        while ($null -ne $pastaPai) {
            if (Test-Path -LiteralPath (Join-Path $pastaPai.FullName '.git')) {
                throw "A pasta esta dentro de outro repositorio Git ($($pastaPai.FullName)). Extraia o projeto para uma pasta independente."
            }
            $pastaPai = $pastaPai.Parent
        }
        & git.exe init -b main
        Conferir-Saida 'git init'
    }

    $repoTop = (& git.exe rev-parse '--show-toplevel' | Out-String).Trim()
    Conferir-Saida 'Verificacao da raiz Git'
    if ([IO.Path]::GetFullPath($repoTop).TrimEnd('\', '/') -ine [IO.Path]::GetFullPath($raiz).TrimEnd('\', '/')) {
        throw "Repositorio inesperado: $repoTop. Nao farei commit em outra pasta."
    }

    $branch = (& git.exe branch '--show-current' | Out-String).Trim()
    Conferir-Saida 'Deteccao da branch'
    if ($branch -ne 'main') {
        throw "Branch atual '$branch' diferente de 'main'. Ajuste manualmente antes da publicacao."
    }

    $usuario = (& git.exe config user.name | Out-String).Trim()
    $usuarioCodigo = $LASTEXITCODE
    $email = (& git.exe config user.email | Out-String).Trim()
    $emailCodigo = $LASTEXITCODE
    if ($usuarioCodigo -ne 0 -or $emailCodigo -ne 0 -or -not $usuario -or -not $email) {
        throw "Configure o autor do commit: git config --global user.name 'Seu Nome' ; git config --global user.email 'email@exemplo.com'"
    }

    # Stage completo, mas pausa para revisao humana antes do commit e push.
    & git.exe add -A
    Conferir-Saida 'git add'
    $alteracoes = @(& git.exe status '--short')
    Conferir-Saida 'git status'

    Write-Host ''
    Write-Host 'Arquivos para commit (REVISE dados pessoais, dumps, tokens e APKs):' -ForegroundColor Yellow
    if ($alteracoes.Count -gt 0) {
        $alteracoes | ForEach-Object { Write-Host $_ }
    }
    else {
        Write-Host 'Nenhuma alteracao local a commitar.'
    }
    Write-Host ''
    $confirmacao = Read-Host "Digite PUBLICAR para confirmar commit/push no repositorio '$NomeRepositorio'"
    if ($confirmacao -cne 'PUBLICAR') {
        Write-Host 'Cancelado. Nenhum commit ou push foi feito.'
        return
    }

    if ($alteracoes.Count -gt 0) {
        & git.exe commit -m 'feat: initial Fire Lite Launcher for Fire OS 7'
        Conferir-Saida 'git commit'
    }

    $nomesRemotos = @(& git.exe remote)
    Conferir-Saida 'git remote'
    if ($nomesRemotos -contains 'origin') {
        $url = (& git.exe remote get-url origin | Out-String).Trim()
        Conferir-Saida 'Verificacao de origin'
        if ($url -notmatch ('[/\:]' + [regex]::Escape($NomeRepositorio) + '(\.git)?$')) {
            throw "origin aponta para '$url', diferente do nome esperado. Confirme o remoto manualmente."
        }
        Write-Host "Enviando para origin: $url"
        & git.exe push '-u' origin main
        Conferir-Saida 'git push'
    }
    else {
        Write-Host "Criando repositorio '$NomeRepositorio' no GitHub com visibilidade $Visibilidade..."
        $flag = if ($Visibilidade -eq 'private') { '--private' } else { '--public' }
        & gh.exe repo create $NomeRepositorio $flag '--source' '.' '--remote' 'origin' '--push'
        Conferir-Saida 'gh repo create'
    }

    Write-Host ''
    & gh.exe repo view '--json' 'url' '--jq' '.url'
    Conferir-Saida 'Consulta da URL do repositorio'
    Write-Host 'Publicacao realizada com sucesso.' -ForegroundColor Green
}
finally {
    Pop-Location
}

# Compilação e instalação no Fire TV Stick Lite

## Pré-requisitos

- Windows 11 / PowerShell 5.1 ou superior.
- Git opcional para build local (necessário apenas para publicação).
- JDK 17 ou 21 (por exemplo, Microsoft OpenJDK 17 ou Java do Android Studio).
- Android Studio SDK: Platform **35**, Build-Tools e Platform-Tools (ADB).
- Fire TV Stick Lite com depuração ADB habilitada e computador na mesma rede.

Instalar o JDK 17 por WinGet, caso necessário:

```powershell
winget install --id Microsoft.OpenJDK.17 --exact
```

Reabra o PowerShell após a instalação.

## Conectar via ADB

```powershell
$adb = "$HOME\platform-tools\adb.exe"
& $adb connect 'IP_DO_FIRE_STICK:5555'
& $adb devices
```

Substitua o endereço de exemplo e autorize a conexão na televisão. **Não coloque o IP real em commits nem issues públicas**.

## Compilar

Na raiz do repositório:

```powershell
.\FireLiteLauncher-Win11.ps1 -Acao Diagnosticar
.\FireLiteLauncher-Win11.ps1 -Acao Compilar
```

O script encontra JDKs conhecidos no Windows, valida o SDK API 35, obtém Gradle 8.7 com checksum SHA-256 e gera:

`app\build\outputs\apk\debug\app-debug.apk`

A saída completa de falhas de compilação fica em `logs\gradle-build.log` (ignorado pelo Git).

## Instalar e executar

```powershell
.\FireLiteLauncher-Win11.ps1 -Acao Instalar
.\FireLiteLauncher-Win11.ps1 -Acao Abrir
```

Se houver mais de um dispositivo conectado, acrescente `-Serial 'IP_DO_FIRE_STICK:5555'`.

Para atualizar o APK após mudanças no código:

```powershell
.\FireLiteLauncher-Win11.ps1 -Acao Instalar -Recompilar
```

## Remover o aplicativo

```powershell
.\FireLiteLauncher-Win11.ps1 -Acao Remover
```

A remoção é restrita ao pacote `br.com.matheus.firelitelauncher` e exige confirmação explícita. O launcher original da Amazon é preservado.

## GitHub Actions

O workflow `android-build.yml` compila o mesmo projeto com API 35, Gradle 8.7 e Java 17. Em Actions, faça download do artefato `fire-lite-launcher-debug` para obter o APK da compilação automatizada.

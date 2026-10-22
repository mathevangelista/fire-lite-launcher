# Fire Lite Launcher

Launcher alternativo minimalista para **Amazon Fire TV Stick Lite**, desenvolvido em **Java/Android** para o **Fire OS 7 (Android 9)**. O projeto nasceu de testes reais de desempenho e da criação de um mockup escuro para substituir visualmente a Home da Amazon, sem remover componentes do sistema.

> **Status:** o APK debug foi compilado e instalado pelo usuário no Fire TV Stick Lite. Foram confirmados **6/6 testes funcionais**: exibição da interface, navegação pelas setas, abertura da Netflix, abertura da Claro TV, grade de aplicativos e botão Voltar. O redirecionamento do botão Home depende do aplicativo externo Home on Fire e deve ser testado separadamente.

![Mockup conceitual da interface](docs/mockup-referencia.png)

## Funcionalidades

- Netflix e Claro TV com destaque visual.
- Cards secundários para YouTube, Prime Video e lista de aplicativos disponíveis.
- Navegação com controle remoto (setas, OK e Voltar).
- Relógio usando o horário do dispositivo.
- Interface escura com componentes nativos; a imagem do mockup **não é carregada como plano de fundo**.
- Sem solicitação de permissão de Internet, publicidade, telemetria ou serviço próprio em segundo plano.
- Instalação reversível: **não desativa nem substitui o pacote `com.amazon.tv.launcher`**.

O aplicativo tem o identificador `br.com.matheus.firelitelauncher`.

## Estrutura

```text
fire-lite-launcher/
├── app/                             # Aplicativo Android Java
│   ├── build.gradle
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/br/com/matheus/firelitelauncher/MainActivity.java
│       └── res/
├── docs/
│   ├── mockup-referencia.png         # Referência visual conceitual
│   ├── INSTALACAO.md                # JDK, SDK, compilação e instalação
│   ├── BOTAO-HOME.md                # Integração opcional com Home on Fire
│   ├── DIAGNOSTICO.md               # Capturas ADB e avaliação de desempenho
│   └── SEGURANCA.md                 # Regras para evitar dados sensíveis no Git
├── tools/
│   ├── Diagnostico-FireStick.ps1     # Diagnóstico por ADB e REA opcional
│   └── Limpeza-Segura-FireStick.ps1  # Lista conservadora e ações reversíveis
├── scripts/
│   └── Publicar-GitHub.ps1          # Inicialização e publicação no GitHub
├── .github/workflows/
│   └── android-build.yml            # Compilação automática do APK debug
├── FireLiteLauncher-Win11.ps1       # Diagnosticar/compilar/instalar/abrir/remover
├── settings.gradle
└── build.gradle
```

## Executar no Windows 11

Pré-requisitos: **JDK 17 ou 21**, **Android SDK Platform 35**, Android Build-Tools e ADB. O script localiza o JDK, baixa o Gradle **8.7** e verifica seu SHA-256.

```powershell
# Na raiz do repositório
.\FireLiteLauncher-Win11.ps1 -Acao Diagnosticar
.\FireLiteLauncher-Win11.ps1 -Acao Compilar
.\FireLiteLauncher-Win11.ps1 -Acao Instalar
.\FireLiteLauncher-Win11.ps1 -Acao Abrir
```

Para remover somente nosso app:

```powershell
.\FireLiteLauncher-Win11.ps1 -Acao Remover
```

Detalhes e alternativas em [Instalação](docs/INSTALACAO.md).

## Botão Home

A Amazon mantém o controle da Home original do Fire OS. Para redirecionar o botão Home, há integração **opcional e independente** com [Home on Fire](https://github.com/toolicious/home-on-fire), que não está incluído neste repositório.

Veja [Botão Home](docs/BOTAO-HOME.md) para configuração e recuperação. **Não desative o launcher Amazon**.

## Ferramentas de diagnóstico

O diretório [`tools/`](tools/) contém dois scripts criados durante a investigação:

- `Diagnostico-FireStick.ps1`: coleta CPU, RAM, renderização do launcher e informações do Fire OS; integra opcionalmente com o REA.
- `Limpeza-Segura-FireStick.ps1`: permite revisar e, após confirmação, desativar ou reativar uma lista restrita de apps de usuário. **As datas de último uso incluídas são um retrato de 21/10/2026, não um monitoramento automático**.

Consulte [Diagnóstico](docs/DIAGNOSTICO.md) antes de compartilhar coletas.

## GitHub

O repositório está preparado para publicação **privada por padrão**:

```powershell
winget install --id Git.Git --exact
winget install --id GitHub.cli --exact
# Abra um novo PowerShell após instalar

gh auth login
.\scripts\Publicar-GitHub.ps1 -NomeRepositorio 'fire-lite-launcher'
```

Ou use Git/gh manualmente conforme [Publicação](docs/PUBLICACAO.md). O GitHub Actions executa o build debug em pushes para `main` e pull requests; o APK gerado é um **artefato do workflow**, e não fica commitado.

## Compatibilidade e limites

- Foco de teste: Fire OS 7 (Android 9), `minSdk 28`, `targetSdk 28`, `compileSdk 35`.
- Android Gradle Plugin `8.6.1`, Gradle `8.7` e Java `17` para compilação.
- O APK debug usa assinatura de desenvolvimento; builds de release exigem assinatura própria.
- O redirecionamento Home, quando habilitado por app externo, pode apresentar atraso no Fire OS 7.
- O mockup é um conceito visual, não uma captura oficial do Fire OS.

## Licenciamento e marcas

**Licença não definida** neste momento: o proprietário do repositório deve escolher e adicionar um arquivo `LICENSE` antes de disponibilizar o código como software open source. Netflix, Claro e demais nomes/logotipos pertencem aos seus titulares. O projeto não é afiliado à Amazon ou aos provedores de streaming.

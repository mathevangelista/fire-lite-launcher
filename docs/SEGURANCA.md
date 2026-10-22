# Segurança e privacidade do repositório

Este repositório contém o código-fonte e ferramentas, **não** um backup do dispositivo.

## Antes de publicar

- Prefira um repositório **privado** até revisar código, licença e direitos de redistribuição.
- Não publique `local.properties`, `.env`, arquivos `.jks`/`.keystore`, APKs assinados, chaves, tokens, endereços IP, identificadores do Fire Stick ou dumps de uso.
- Execute `git status --short` e `git diff --cached --name-only` antes do commit.
- `.gitignore` impede vários arquivos típicos de serem adicionados por engano, mas não protege arquivos já rastreados pelo Git.
- Se uma credencial for commitada, revogue-a no serviço de origem; apagar o commit local não garante que ela não tenha sido copiada.

## Modificações no Fire OS

- Preservar o launcher original e seus serviços.
- Usar desativação reversível apenas para aplicativos autorizados em uma allowlist.
- Não usar `pm uninstall --user 0` em pacotes Amazon sem análise e caminho de recuperação.
- `WRITE_SECURE_SETTINGS` é uma permissão privilegiada concedida a software externo somente mediante decisão consciente do usuário.

## Dependências

O aplicativo Android não usa serviços web próprios. A compilação depende de Android SDK e Gradle/Android Gradle Plugin. O projeto Home on Fire é externo e **não é redistribuído aqui**.

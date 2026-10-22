# Publicar no GitHub

## Método recomendado: PowerShell

Instale Git e GitHub CLI (Windows 11):

```powershell
winget install --id Git.Git --exact
winget install --id GitHub.cli --exact
```

Abra **outro PowerShell** e autentique sua conta:

```powershell
gh auth login
```

Extraia o ZIP do repositório numa pasta separada da instalação Android que já está funcionando, navegue para sua raiz e execute:

```powershell
.\scripts\Publicar-GitHub.ps1 -NomeRepositorio 'fire-lite-launcher'
```

O script, por padrão, cria o repositório como **privado**, faz `git init`, o commit inicial e o push. Pode ser executado novamente para enviar alterações posteriores. Ele não sobrescreve um repositório remoto e exige que seu Git tenha `user.name` e `user.email` configurados.

Exemplo para abrir o código publicamente apenas quando estiver pronto:

```powershell
.\scripts\Publicar-GitHub.ps1 -NomeRepositorio 'fire-lite-launcher' -Visibilidade public
```

A visibilidade é usada **somente na criação**. Se o repositório já existir, mude sua visibilidade diretamente no GitHub.

## Alternativa manual

```powershell
git init -b main
git add .
git status --short
git commit -m "feat: initial Fire Lite Launcher for Fire OS 7"
gh repo create fire-lite-launcher --private --source . --remote origin --push
```

Nos envios seguintes:

```powershell
git add .
git commit -m "chore: update launcher"
git push
```

## Notas

- **Não** rode `git init` na pasta `Downloads` ou numa pasta que contenha dumps de utilização. Use a pasta extraída com os arquivos do repositório.
- Não inclua os binários do Home on Fire, pois pertencem a outro projeto.
- O workflow de compilação publica o APK debug como artefato temporário, sem colocá-lo no histórico Git.
- Para fazer publicação com a conta conectada ao ChatGPT, é necessário autorizar o GitHub separadamente; preparar o pacote local não cria o repositório remoto.

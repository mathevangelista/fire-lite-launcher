# Diagnóstico e otimização de desempenho

As ferramentas aqui são complementares ao launcher. Foram utilizadas para identificar pressão de RAM e atrasos na interface original do Fire OS.

## Diagnóstico ADB e REA (somente leitura)

```powershell
.\tools\Diagnostico-FireStick.ps1
```

- Coleta memória, CPU, frame stats do launcher, armazenamento e informações básicas do dispositivo.
- Se o REA estiver instalado, executa alguns comandos de inspeção sem modificar pacotes.
- Os resultados são gravados fora do repositório, na pasta `Documentos\FireStick-Diagnosticos`.

Opcional: instalar REA para investigação adicional:

```powershell
npm.cmd install --global rea-agents
```

## Limpeza reversível de aplicativos

```powershell
.\tools\Limpeza-Segura-FireStick.ps1 -Acao Relatorio
.\tools\Limpeza-Segura-FireStick.ps1 -Acao Desativar -Apps Globoplay,Disney
.\tools\Limpeza-Segura-FireStick.ps1 -Acao Reativar -Apps Globoplay,Disney
```

O script usa uma **allowlist estática** feita com base no histórico coletado em 21/10/2026. Ela **não calcula automaticamente** a inatividade dos últimos sete dias e exige confirmação por aplicativo. Não desativa serviços essenciais nem limpa dados.

## Comparar fluidez do launcher original

```powershell
$adb = "$HOME\platform-tools\adb.exe"
& $adb shell input keyevent 3
& $adb shell dumpsys gfxinfo com.amazon.tv.launcher reset
# Navegue por aproximadamente um minuto na mesma tela inicial.
& $adb shell dumpsys gfxinfo com.amazon.tv.launcher > launcher_gfxinfo.txt
& $adb shell dumpsys meminfo com.amazon.tv.launcher > launcher_memoria.txt
```

`gfxinfo` quantifica frames lentos; `meminfo` descreve a utilização de memória naquele instante. A melhoria real exige testes A/B com condições comparáveis, pois os caches e aplicativos em primeiro plano variam.

## Dados que nunca devem ser commitados

Dumps `dumpsys`, inventários completos de apps, histórico de uso, logs, números de série, IPs locais e arquivos de assinatura. Compartilhe apenas amostras revisadas, caso necessário. O `.gitignore` cobre os nomes mais comuns, mas **revise sempre o `git status` antes de publicar**.

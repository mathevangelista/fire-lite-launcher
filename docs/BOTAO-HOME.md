# Configuração opcional do botão Home

**Não é necessário para instalar ou testar o Fire Lite Launcher.** A Home da Amazon deve continuar instalada. Este repositório **não inclui** código ou APK do projeto de terceiros.

A opção comunitária [Home on Fire](https://github.com/toolicious/home-on-fire) redireciona o botão Home do controle para outro aplicativo em Fire OS 7/8, sem root. Consulte sempre as instruções e limitações no repositório oficial antes de atualizar.

## Instalação do Home on Fire

Em PowerShell, com o ADB configurado:

```powershell
$adb = "$HOME\platform-tools\adb.exe"
$apk = "$HOME\Downloads\home-on-fire.apk"

Invoke-WebRequest -Uri 'https://github.com/toolicious/home-on-fire/releases/latest/download/home-on-fire.apk' -OutFile $apk -ErrorAction Stop
& $adb install -r $apk
```

Em seguida, abra o Home on Fire na TV e habilite o serviço de acessibilidade. Se o Fire OS bloquear o acionamento da permissão pelo aplicativo, o projeto upstream documenta:

```powershell
& $adb shell pm grant io.github.toolicious.homeonfire android.permission.WRITE_SECURE_SETTINGS
```

**Segurança:** `WRITE_SECURE_SETTINGS` dá acesso privilegiado a configurações do Android. Conceda somente se confiar no aplicativo e na versão instalada.

Selecione `Fire Lite Launcher` como aplicativo de destino e ative a opção de redirecionamento Home no Home on Fire. Teste pressionando Home após abrir Netflix e Claro TV. Confirme também como retornar à Home original antes de ativar inicialização automática.

## Recuperação

Na documentação do Home on Fire, pressionar Home longamente permite alternar entre seu launcher e a Home original; manter o botão Menu pressionado abre as configurações do redirecionador. O comportamento pode variar conforme versão do Fire OS e do aplicativo.

Para remover o redirecionador, se ele estiver impedindo o acesso à Home:

```powershell
& $adb uninstall io.github.toolicious.homeonfire
```

Esse comando **não desinstala** o Fire Lite Launcher.

## Limitações

- A navegação do Fire Lite Launcher foi validada no dispositivo do projeto (6/6 testes).
- O comportamento do botão Home é responsabilidade de uma integração separada; não há garantia de compatibilidade em todas as atualizações da Amazon.
- O Fire OS 7 pode impor uma espera perceptível no redirecionamento.
- Não desabilite `com.amazon.tv.launcher` ou `com.amazon.firehomestarter` para tentar eliminar a espera.

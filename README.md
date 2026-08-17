# Discord Proton Refresh

Automacao para Windows que:

1. abre o aplicativo oficial do Proton VPN;
2. aciona a conexao rapida;
3. aguarda a confirmacao da troca do IP publico;
4. ativa o Discord e envia `Ctrl+R`;
5. desconecta a VPN;
6. fecha completamente o Proton VPN, inclusive da bandeja.

## Requisitos

- Windows 10 ou 11;
- aplicativo oficial do Proton VPN instalado e com login feito;
- Discord desktop aberto;
- PowerShell 5.1 ou superior;
- idioma do Proton VPN em portugues ou ingles.

O script reconhece tanto `ProtonVPN.Launcher.exe` (versoes atuais) quanto `ProtonVPN.exe` (instalacoes anteriores).

> O aplicativo oficial do Proton VPN para Windows nao possui uma CLI publica de conexao. O script usa a API de acessibilidade do Windows para acionar os botoes pelo nome, sem coordenadas fixas de mouse.

## Executar pelo CMD

Baixe o repositorio, abra o CMD na pasta e execute:

```cmd
executar
```

Ou execute o PowerShell diretamente:

```cmd
powershell -NoProfile -ExecutionPolicy Bypass -File discord-proton-refresh.ps1
```

Opcoes:

```cmd
executar -TimeoutSeconds 90 -RefreshDelaySeconds 8
```

## Importante

- Deixe o Discord aberto antes de executar.
- Deixe o Proton VPN autenticado e desconectado.
- O script usa `https://api.ipify.org` apenas para confirmar a troca do IP.
- Se a Proton alterar os nomes/controles da interface, os seletores em `Invoke-ProtonButton` poderao precisar de ajuste.
- O encerramento forcado finaliza apenas o processo da interface `ProtonVPN`; o script primeiro solicita o fechamento normal.

## Solucao de problemas

Se aparecer "botao nao encontrado", confira se o aplicativo esta em portugues ou ingles e se a tela principal esta aberta. Para aumentar o tempo de espera:

```cmd
executar -TimeoutSeconds 120
```

## Licenca

MIT

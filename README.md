# Discord Proton Refresh

Automacao para Windows que:

1. abre o aplicativo oficial do Proton VPN;
2. aguarda o perfil do Proton conectar automaticamente;
3. confirma a troca do IP publico;
4. ativa o Discord e envia `Ctrl+R`;
5. aguarda o Discord voltar a responder;
6. finaliza os processos da interface do Proton VPN, desligando a VPN.

## Requisitos

- Windows 10 ou 11;
- aplicativo oficial do Proton VPN instalado e com login feito;
- Discord desktop aberto;
- PowerShell 5.1 ou superior;
- idioma do Proton VPN em portugues ou ingles.
- aceitar a solicitacao de administrador do Windows ao executar.

O script reconhece tanto `ProtonVPN.Launcher.exe` (versoes atuais) quanto `ProtonVPN.exe` (instalacoes anteriores).

> O Proton VPN deve estar configurado para conectar automaticamente quando for aberto. O script nao clica em botoes da interface.

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
executar -TimeoutSeconds 90 -RefreshDelaySeconds 15
```

## Importante

- Deixe o Discord aberto antes de executar.
- Deixe o Proton VPN autenticado, fechado e configurado para conexao automatica.
- O script usa `https://api.ipify.org` apenas para confirmar a troca do IP.
- Antes de finalizar a interface, o script aciona `Desconectar` e confirma que o IP da VPN saiu. Isso evita deixar filtros de rede ativos e perder a internet.
- O script espera no minimo 15 segundos apos `Ctrl+R` e exige que o Discord permaneça responsivo por tres verificacoes seguidas.
- Depois da desconexao confirmada, todos os servicos e processos cujo nome comeca com `Proton` sao encerrados.

## Solucao de problemas

Se a conexao ou o recarregamento demorarem mais, aumente o tempo de espera:

```cmd
executar -TimeoutSeconds 120
```

## Licenca

MIT

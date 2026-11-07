# Otimizar Windows

Manutenção e limpeza para **Windows 10 e 11** em um **único arquivo**. Você dá duplo clique, confirma o pedido de administrador, escolhe o que quer rodar numa janela gráfica e acompanha o script trabalhando em tempo real.

![Licença MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-blue)
![Windows 10 e 11](https://img.shields.io/badge/Windows-10%20%7C%2011-informational)
![Sem instalação](https://img.shields.io/badge/instala%C3%A7%C3%A3o-nenhuma-success)

> **Antes de usar:** o script faz alterações reais no sistema (limpa arquivos, roda verificações, pode mexer em rede e energia). Leia o código, salve seu trabalho e use por sua conta e risco. Tudo o que ele altera está listado mais abaixo.

## Como usar

1. Baixe o arquivo **`otimizar.bat`**. Nesta página, abra o arquivo e use o botão *Download raw file*.
2. Dê duplo clique nele e confirme o pedido de administrador do Windows.
3. No menu que abre, escolha **1** para abrir a interface gráfica (ou **0** para sair).
4. Marque as etapas, escolha as opções extras (todas começam desmarcadas) e clique em **Executar**.
5. Acompanhe a saída ao vivo. No fim, leia o **resumo da execução**. Reinicie o PC se o resumo pedir.

Se o Windows mostrar "O Windows protegeu o seu PC", clique em *Mais informações* e depois em *Executar assim mesmo*. Isso acontece com qualquer script baixado da internet, e é por isso que o código é aberto e legível: abra o arquivo no Bloco de Notas e confira.

## O que ele faz

São 10 etapas. Você roda todas ou só as que quiser.

| # | Etapa | O que acontece |
|---|---|---|
| 1 | **Limpeza de temporários** | Esvazia `%temp%`, `C:\Windows\Temp`, itens recentes, cache de download do Windows Update, miniaturas, cache de ícones e relatórios de erro do Windows. Limpar o Prefetch é opcional. |
| 2 | **Verificação de disco e sistema** | `chkdsk /scan` e `sfc /scannow`. O agendamento de `chkdsk /f /r` é opcional e exige reiniciar. |
| 3 | **Diagnóstico da imagem do Windows** | `DISM /CheckHealth` e `/ScanHealth`. São rápidos e só diagnosticam. |
| 4 | **Limpeza de componentes antigos** | Analisa e limpa o WinSxS com `/StartComponentCleanup`. O `/ResetBase` é opcional. |
| 5 | **Otimização de disco** | Detecta se o `C:` está em SSD ou HDD e aplica TRIM ou desfragmentação. |
| 6 | **Logs de eventos** | Limpa o Visualizador de Eventos. Opcional, pois apaga histórico útil para diagnóstico. |
| 7 | **Limpeza adicional** | Limpeza de Disco do Windows com uma lista segura de categorias, e ativa o Storage Sense. |
| 8 | **Rede** | Limpa o cache DNS e renova o IP. O reset de Winsock, proxy WinHTTP e TCP/IP é opcional e exige reiniciar. |
| 9 | **Atualização de programas** | `winget upgrade --all`. |
| 10 | **Ajustes de energia** | Desativa a hibernação e ativa o plano de Desempenho Máximo. Opcional. Avisa se o PC parecer um notebook. |

## O resumo no final

O script não diz "sucesso" por padrão. Ao terminar, ele mostra:

- **cada etapa que rodou**, como `[ OK ]` ou `[AVISO]`, com o motivo do aviso;
- o **resultado do SFC**, lido do `CBS.log` (limpo, reparou ou não conseguiu reparar), o que funciona em Windows de qualquer idioma;
- o **espaço livre no `C:` antes e depois**. O texto diz "aumentou" ou "diminuiu" de propósito: o script mede a diferença, mas não afirma que foi ele que liberou o espaço, já que atualizações e reparos também ocupam disco;
- um aviso quando há **reinicialização pendente** no Windows, porque SFC e DISM podem falhar nesse estado;
- o que exige **reiniciar** o computador.

## O que ele altera

Transparência total sobre o que fica diferente depois de rodar:

- **Arquivos:** apaga o conteúdo das pastas de temporários e caches listadas na etapa 1. O Limpeza de Disco usa só categorias seguras e **não toca em Downloads, na Lixeira nem em itens de rollback do Windows**.
- **Registro:**
  - desativa o *QuickEdit* do console do usuário atual (`HKCU\Console`), para um clique acidental não pausar o script. Isso vale para as próximas janelas de terminal, e você pode reativar nas propriedades do console;
  - marca as categorias do Limpeza de Disco (`StateFlags0100`);
  - liga o Storage Sense (`HKCU`).
- **Serviços:** para o Windows Update durante a limpeza do cache e **só o religa se ele já estava rodando**.
- **Energia e rede:** só se você marcar as opções correspondentes.
- **Storage Sense:** depois de ativado, o próprio Windows passa a limpar temporários automaticamente e, pelo padrão dele, itens da Lixeira com mais de 30 dias.

## O que ele NÃO faz

- Não desativa Windows Defender, SmartScreen, UAC, integridade de memória ou mitigações da CPU.
- Não baixa nem executa código de terceiros. O único acesso à internet é o `winget`, que baixa atualizações dos seus programas, e só na etapa 9.
- Não envia nenhum dado para fora, não tem telemetria e não cria tarefas agendadas.
- Não remove aplicativos do Windows e não altera o arquivo `hosts`.
- Não faz ajustes "mágicos" de registro nem promete aumento de FPS ou de desempenho. O que ele mede é espaço em disco.
- O reparo profundo `DISM /RestoreHealth` **não roda sozinho**, por ser demorado e instável em alguns PCs. Se o diagnóstico apontar corrupção, rode manualmente: `DISM /Online /Cleanup-Image /RestoreHealth`.

## Como funciona por dentro

É um único `.bat`. O menu e as 10 etapas são código de batch comum. A janela gráfica é um trecho de PowerShell guardado no **final do mesmo arquivo**, entre as marcas `#GUI-BEGIN` e `#GUI-END`. Ao escolher a opção 1, o script grava uma cópia temporária desse trecho, abre a janela e apaga a cópia quando você fecha. A janela não tem código de limpeza próprio: ela roda o próprio `otimizar.bat` em modo sem perguntas e mostra a saída. Existe também um auxiliar de PowerShell, também embutido, que só **lê** informações (espaço livre, reinicialização pendente, tipo de PC, resultado do SFC) e não altera nada.

Cada execução grava um log ao lado do arquivo, o `otimizar_log.txt`, com a hora de início de cada etapa. Se algo travar, ele mostra onde parou.

## Requisitos

- Windows 10 ou 11
- PowerShell 5.1, que já vem no Windows
- `winget`, para a etapa 9 (já vem nas versões recentes). Sem ele, só essa etapa é pulada.
- Permissão de administrador

## Status do projeto

A janela gráfica e o arquivo único são recentes e foram testados em PCs reais do autor. Se algo não funcionar no seu, **abra uma *issue*** e inclua:

- a versão do seu Windows;
- uma foto ou captura da tela com o erro (se a janela não abrir, o menu do CMD mostra uma mensagem pedindo isso);
- o arquivo `otimizar_log.txt`, se existir.

## Licença

[MIT](LICENSE). Use, modifique e distribua à vontade, mantendo o aviso de copyright.

---

Feito por [Seabratex](https://github.com/Seabratex).

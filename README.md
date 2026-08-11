# Otimizar Windows

Script `.bat` para otimização de PCs com Windows 10/11, com auto-elevação de administrador e execução em 8 etapas.

## ⚠️ Aviso

Este script faz alterações reais no sistema: apaga arquivos temporários, reinicia o serviço do Windows Update, roda verificação de disco (`chkdsk`), reparo de imagem (`DISM`), limpeza de componentes antigos do Windows, otimização de disco (`TRIM`/desfragmentação) e pode agendar reinicialização. **Leia o código antes de rodar** e use por sua conta e risco.

## O que o script faz

1. **Limpeza de arquivos temporários**
   - `%temp%`, `C:\Windows\Temp`, `Prefetch` (com `takeown`/`icacls` para evitar erros de permissão), `Recent`
   - Cache do Windows Update (`SoftwareDistribution\Download`, com parada segura do serviço `wuauserv`)
   - Cache de miniaturas (thumbnails) e ícones
   - Relatórios de erro do Windows (WER)

2. **Verificação de disco e arquivos de sistema**
   - `chkdsk /scan` automático
   - `chkdsk /f /r` opcional (pergunta antes, exige reinício)
   - `sfc /scannow`

3. **Restauração da imagem do Windows**
   - `DISM /checkhealth`, `/scanhealth`, `/restorehealth`

4. **Limpeza de componentes antigos (WinSxS)**
   - `DISM /AnalyzeComponentStore` — analisa quanto espaço pode ser recuperado
   - `DISM /StartComponentCleanup` — remove componentes antigos já substituídos, mantendo a opção de desinstalar a atualização mais recente
   - `DISM /StartComponentCleanup /ResetBase` — **opcional** (pergunta antes): libera mais espaço, mas remove a opção de rollback de atualizações já aplicadas

5. **Otimização de disco automática**
   - Detecta se o disco é SSD ou HDD e aplica `TRIM` ou desfragmentação, conforme o caso

6. **Limpeza de logs de eventos do Windows**

7. **Atualização de programas via Winget**
   - `winget upgrade --all`, com fallback para localizar o executável quando não está no PATH da sessão elevada

8. **Ajustes de energia**
   - Desativa hibernação
   - Ativa o plano de energia "Desempenho Máximo"

## Como usar

1. Baixe o `otimizar.bat`
2. Dê duplo clique — o script pede permissão de administrador automaticamente
3. Siga as instruções no terminal (algumas etapas pedem confirmação, como o `chkdsk /f /r`)
4. Reinicie o computador ao final para aplicar todas as mudanças

## Requisitos

- Windows 10 ou 11
- Winget instalado (já vem por padrão em versões recentes do Windows)
- Conexão com a internet (para a etapa de atualização de programas)

## Licença

MIT — sinta-se livre para usar, modificar e distribuir, citando a fonte.

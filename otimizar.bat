@echo off
:: ============================================
::   SCRIPT DE OTIMIZACAO - Artur
:: ============================================

:: --- Auto-elevacao (pede admin automaticamente) ---
cd /d "%~dp0"
>nul 2>&1 "%SystemRoot%\system32\cacls.exe" "%SystemRoot%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Solicitando permissao de administrador...
    powershell -Command "Start-Process -FilePath '%ComSpec%' -ArgumentList '/k \"\"%~f0\"\"' -Verb RunAs"
    if errorlevel 1 (
        echo Nao foi possivel elevar automaticamente.
        echo Clique com o botao direito no arquivo e escolha "Executar como administrador".
        pause
    )
    exit /b
)

:: --- Desativa o "QuickEdit Mode" do console (evita que um clique na janela pause o script) ---
reg add "HKCU\Console" /v QuickEdit /t REG_DWORD /d 0 /f >nul 2>&1

:: --- Log automatico (o cabecalho e regravado a cada execucao, em :iniciar) ---
set "LOGFILE=%~dpn0_log.txt"
set "SEABRA_BAT=%~f0"

title Otimizacao do PC - Artur
if not defined GUI_MODE color 1F

:: Modo interface grafica (GUI_MODE=1): pula o menu e nao faz perguntas,
:: pois as respostas e as etapas escolhidas chegam por variaveis de ambiente.
if defined GUI_MODE goto iniciar

:menu
cls
call :banner
echo   ================================================
echo     [1]  Abrir interface grafica
echo     [0]  Sair
echo   ================================================
echo.
set "op="
set /p op="  Escolha uma opcao: "
if "%op%"=="1" goto op_gui
if "%op%"=="0" exit
goto menu

:op_gui
echo.
echo   Abrindo a interface grafica...
set "SEABRA_BAT=%~f0"
set "GUIPS=%temp%\seabra_gui_%random%.ps1"
set "EXTRACT_TAG=GUI"
set "EXTRACT_OUT=%GUIPS%"
call :extrair
if not exist "%GUIPS%" goto op_gui_erro
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%GUIPS%"
set "GUIRC=%errorlevel%"
del "%GUIPS%" >nul 2>&1
if not "%GUIRC%"=="0" goto op_gui_erro
exit

:op_gui_erro
echo.
echo   [ERRO] A interface grafica nao abriu. Tire uma foto desta tela e envie ao autor.
echo.
del "%GUIPS%" >nul 2>&1
pause
goto menu

:iniciar
if not defined GUI_MODE for %%V in (limparpref rodarchk resetbase limparlogs resetrede alterarenergia) do set "%%V="
echo ============================================ > "%LOGFILE%"
echo Otimizacao iniciada em %date% %time% - etapas: %STEPS% >> "%LOGFILE%"
echo ============================================ >> "%LOGFILE%"
echo.
echo ================================================
echo         INICIANDO OTIMIZACAO DO SISTEMA
echo ================================================
echo.
call :preparar

:: ============================================
:: 1. LIMPEZA DE ARQUIVOS TEMPORARIOS
:: ============================================
call :run_step 1
if not defined RUN_STEP goto fim_etapa1
echo.
echo [%date% %time%] Iniciando etapa 1/10 - Limpeza de temporarios >> "%LOGFILE%"
echo [1/10] Limpando arquivos temporarios...
echo ------------------------------------------------

echo - Limpando %%temp%%...
del /q /f /s "%temp%\*.*" >nul 2>&1
for /d %%x in ("%temp%\*") do rd /s /q "%%x" >nul 2>&1

echo - Limpando C:\Windows\Temp...
del /q /f /s "C:\Windows\Temp\*.*" >nul 2>&1
for /d %%x in ("C:\Windows\Temp\*") do rd /s /q "%%x" >nul 2>&1

if not defined limparpref set /p limparpref="Deseja limpar a pasta Prefetch? Geralmente nao e necessario, o Windows recria e os apps podem abrir um pouco mais lentos na primeira vez. (S/N): "
if /i "%limparpref%"=="S" (
    echo - Limpando Prefetch...
    takeown /f "C:\Windows\Prefetch" /r /d y >nul 2>&1
    icacls "C:\Windows\Prefetch" /grant *S-1-5-32-544:F /t >nul 2>&1
    del /q /f /s "C:\Windows\Prefetch\*.*" >nul 2>&1
) else (
    echo Pulando Prefetch.
)

echo - Limpando Recentes...
del /q /f /s "%APPDATA%\Microsoft\Windows\Recent\*.*" >nul 2>&1
for /d %%x in ("%APPDATA%\Microsoft\Windows\Recent\*") do rd /s /q "%%x" >nul 2>&1

echo - Limpando cache do Windows Update (parando servico com seguranca)...
set "WU_WAS="
sc query wuauserv | find "RUNNING" >nul 2>&1
if not errorlevel 1 set "WU_WAS=1"
net stop wuauserv >nul 2>&1
del /q /f /s "C:\Windows\SoftwareDistribution\Download\*.*" >nul 2>&1
for /d %%x in ("C:\Windows\SoftwareDistribution\Download\*") do rd /s /q "%%x" >nul 2>&1
if defined WU_WAS net start wuauserv >nul 2>&1

echo - Limpando cache de miniaturas (thumbnails)...
del /q /f /a "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1

echo - Limpando cache de icones...
powershell -NoProfile -Command "ie4uinit.exe -ClearIconCache" >nul 2>&1

echo - Limpando relatorios de erro do Windows (WER)...
del /q /f /s "%ProgramData%\Microsoft\Windows\WER\ReportQueue\*.*" >nul 2>&1
del /q /f /s "%ProgramData%\Microsoft\Windows\WER\ReportArchive\*.*" >nul 2>&1

echo Limpeza concluida (arquivos em uso sao ignorados automaticamente).
echo.

:fim_etapa1

:: ============================================
:: 2. VERIFICACAO DE DISCO E ARQUIVOS DE SISTEMA
:: ============================================
call :run_step 2
if not defined RUN_STEP goto fim_etapa2
echo [%date% %time%] Iniciando etapa 2/10 - Verificacao de disco >> "%LOGFILE%"
echo [2/10] Verificando disco e integridade do sistema...
echo ------------------------------------------------

echo - Agendando verificacao de disco (chkdsk)...
chkdsk C: /scan
if errorlevel 3 call :marcar 2 "chkdsk reportou problemas ou nao conseguiu verificar o disco - codigo 3"

echo.
if not defined rodarchk set /p rodarchk="Deseja agendar verificacao completa de disco (chkdsk /f /r)? Isso exige reiniciar o PC. (S/N): "
if /i "%rodarchk%"=="S" (
    echo Agendando chkdsk /f /r para a proxima reinicializacao...
    (echo S& echo Y)| chkdsk C: /f /r
    set "NEED_REBOOT=1"
) else (
    echo Pulando chkdsk /f /r.
)
echo.

echo - Verificando arquivos de sistema (sfc)...
set "SFC_START="
set "R_STAMP="
call :helper Stamp
set "SFC_START=%R_STAMP%"
sfc /scannow
call :veredito_sfc

echo.

:fim_etapa2

:: ============================================
:: 3. RESTAURACAO DA IMAGEM DO WINDOWS (DISM)
:: ============================================
call :run_step 3
if not defined RUN_STEP goto fim_etapa3
echo [%date% %time%] Iniciando etapa 3/10 - DISM CheckHealth/ScanHealth >> "%LOGFILE%"
echo [3/10] Verificando integridade da imagem do Windows...
echo ------------------------------------------------

dism /online /cleanup-image /checkhealth
if errorlevel 1 call :marcar 3 "DISM CheckHealth retornou erro - veja o texto acima"
dism /online /cleanup-image /scanhealth
if errorlevel 1 call :marcar 3 "DISM ScanHealth retornou erro - veja o texto acima"

echo.
echo Diagnostico concluido. O RestoreHealth (reparo profundo) foi removido do fluxo
echo automatico por ser demorado e instavel em alguns PCs - so e necessario se o
echo scanhealth acima apontar corrupcao. Se precisar reparar, rode manualmente:
echo   DISM /Online /Cleanup-Image /RestoreHealth

echo.

:fim_etapa3

:: ============================================
:: 4. LIMPEZA DE COMPONENTES ANTIGOS (WinSxS)
:: ============================================
call :run_step 4
if not defined RUN_STEP goto fim_etapa4
echo [%date% %time%] Iniciando etapa 4/10 - Limpeza WinSxS >> "%LOGFILE%"
echo [4/10] Analisando e limpando componentes antigos do Windows (WinSxS)...
echo ------------------------------------------------

echo - Analisando o repositorio de componentes...
dism /online /cleanup-image /AnalyzeComponentStore

echo.
echo - Removendo componentes antigos ja substituidos (mantem opcao de rollback dos updates mais recentes)...
dism /online /cleanup-image /StartComponentCleanup
if errorlevel 1 call :marcar 4 "A limpeza de componentes retornou erro - veja o texto acima"

echo.
if not defined resetbase set /p resetbase="Deseja tambem remover TODAS as versoes antigas de updates (/ResetBase)? Isso libera mais espaco, mas voce perde a opcao de desinstalar atualizacoes ja aplicadas. (S/N): "
if /i "%resetbase%"=="S" (
    echo Executando limpeza completa com ResetBase...
    dism /online /cleanup-image /StartComponentCleanup /ResetBase
    if errorlevel 1 call :marcar 4 "O ResetBase retornou erro - veja o texto acima"
) else (
    echo Pulando /ResetBase - mantendo opcao de rollback de updates recentes.
)
echo.

:fim_etapa4

:: ============================================
:: 5. OTIMIZACAO DE DISCO (SSD/HDD AUTOMATICO)
:: ============================================
call :run_step 5
if not defined RUN_STEP goto fim_etapa5
echo [%date% %time%] Iniciando etapa 5/10 - Otimizacao de disco >> "%LOGFILE%"
echo [5/10] Otimizando disco (detectando tipo automaticamente)...
echo ------------------------------------------------

powershell -NoProfile -Command "$n = (Get-Partition -DriveLetter C -ErrorAction SilentlyContinue).DiskNumber; $type = (Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DeviceId -eq $n }).MediaType; if ($type -eq 'SSD') { Write-Host 'Drive C: esta em um SSD - executando TRIM...' -ForegroundColor Green; Optimize-Volume -DriveLetter C -ReTrim -Verbose } elseif ($type -eq 'HDD') { Write-Host 'Drive C: esta em um HDD - executando desfragmentacao...' -ForegroundColor Green; Optimize-Volume -DriveLetter C -Defrag -Verbose } else { Write-Host 'Tipo de disco nao identificado - executando otimizacao padrao do Windows...' -ForegroundColor Yellow; Optimize-Volume -DriveLetter C -Verbose }"
if errorlevel 1 call :marcar 5 "A otimizacao do disco retornou erro - veja o texto acima"

echo.

:fim_etapa5

:: ============================================
:: 6. LIMPEZA DE LOGS DE EVENTOS
:: ============================================
call :run_step 6
if not defined RUN_STEP goto fim_etapa6
echo [%date% %time%] Iniciando etapa 6/10 - Limpeza de logs de eventos >> "%LOGFILE%"
echo [6/10] Logs de eventos do Windows...
echo ------------------------------------------------

if not defined limparlogs set /p limparlogs="Deseja limpar todos os logs do Visualizador de Eventos? Isso apaga historico util para diagnostico de erros. (S/N): "
if /i "%limparlogs%"=="S" (
    echo Limpando logs de eventos...
    powershell -NoProfile -Command "Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | ForEach-Object { wevtutil.exe clear-log $_.LogName 2>$null }"
    echo Logs de eventos limpos.
) else (
    echo Pulando limpeza de logs de eventos.
)

echo.

:fim_etapa6

:: ============================================
:: 7. LIMPEZA ADICIONAL (CLEANMGR + STORAGE SENSE)
:: ============================================
call :run_step 7
if not defined RUN_STEP goto fim_etapa7
echo [%date% %time%] Iniciando etapa 7/10 - Limpeza adicional >> "%LOGFILE%"
echo [7/10] Limpeza adicional do sistema...
echo ------------------------------------------------

echo - Configurando categorias seguras do Limpeza de Disco (cleanmgr)...
echo   Downloads, Lixeira e itens de rollback do Windows NAO sao tocados.
for %%N in ("Temporary Files" "Thumbnail Cache" "Temporary Setup Files" "Old ChkDsk Files" "Windows Error Reporting Files" "Internet Cache Files" "Active Setup Temp Folders" "Downloaded Program Files" "D3D Shader Cache" "Delivery Optimization Files" "Content Indexer Cleaner" "Setup Log Files" "Windows Upgrade Log Files") do (
    reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\%%~N" >nul 2>&1 && reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\%%~N" /v StateFlags0100 /t REG_DWORD /d 2 /f >nul 2>&1
)

echo - Executando Limpeza de Disco completa (isso pode levar alguns minutos)...
cleanmgr /sagerun:100

echo.
echo - Ativando Storage Sense (limpeza automatica recorrente do Windows)...
powershell -NoProfile -Command "New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' -Force | Out-Null; Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' -Name '01' -Value 1 -Type DWord -ErrorAction SilentlyContinue"
echo Storage Sense ativado - o Windows vai limpar arquivos temporarios automaticamente a partir de agora.

echo.

:fim_etapa7

:: ============================================
:: 8. REDE (DNS, WINSOCK E TCP/IP)
:: ============================================
call :run_step 8
if not defined RUN_STEP goto fim_etapa8
echo [%date% %time%] Iniciando etapa 8/10 - Rede >> "%LOGFILE%"
echo [8/10] Otimizando e resetando configuracoes de rede...
echo ------------------------------------------------

echo - Limpando cache DNS...
ipconfig /flushdns >nul 2>&1

echo - Liberando e renovando IP...
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1

echo.
if not defined resetrede set /p resetrede="Deseja resetar Winsock e TCP/IP tambem? Util se a internet estiver lenta/instavel. Requer REINICIAR o PC depois. (S/N): "
if /i "%resetrede%"=="S" (
    echo Resetando Winsock...
    netsh winsock reset >nul 2>&1
    echo Resetando proxy do WinHTTP para Direto...
    netsh winhttp reset proxy >nul 2>&1
    echo Resetando TCP/IP...
    netsh int ip reset >nul 2>&1
    echo Reset de rede concluido - REINICIE o computador para aplicar.
    set "NEED_REBOOT=1"
) else (
    echo Pulando reset de Winsock/TCP-IP.
)

echo.

:fim_etapa8

:: ============================================
:: 9. ATUALIZACAO DE PROGRAMAS (WINGET)
:: ============================================
call :run_step 9
if not defined RUN_STEP goto fim_etapa9
echo [%date% %time%] Iniciando etapa 9/10 - Winget >> "%LOGFILE%"
echo [9/10] Atualizando todos os programas via winget...
echo ------------------------------------------------

set "winget_exe=winget"
where winget >nul 2>&1
if not errorlevel 1 goto winget_executar

echo [AVISO] Winget nao foi encontrado no PATH desta sessao elevada.
echo Tentando localizar o executavel diretamente...
set "wingetpath="
for /f "delims=" %%W in ('powershell -NoProfile -Command "(Get-AppxPackage -Name Microsoft.DesktopAppInstaller).InstallLocation"') do set "wingetpath=%%W"
if not defined wingetpath (
    echo [ERRO] Nao foi possivel localizar o winget. Pulando atualizacao.
    call :marcar 9 "winget nao foi encontrado - nenhum programa foi atualizado"
    goto pular_winget
)
set "winget_exe=%wingetpath%\winget.exe"

:winget_executar
echo Executando: %winget_exe% upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements
"%winget_exe%" upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements --disable-interactivity
if errorlevel 1 call :marcar 9 "winget terminou com codigo %errorlevel% - confira o texto acima"

:pular_winget
echo.

:fim_etapa9

:: ============================================
:: 10. AJUSTES DE ENERGIA
:: ============================================
call :run_step 10
if not defined RUN_STEP goto fim_etapa10
echo [%date% %time%] Iniciando etapa 10/10 - Energia >> "%LOGFILE%"
echo [10/10] Ajustando configuracoes de energia...
echo ------------------------------------------------

if not defined alterarenergia set /p alterarenergia="Deseja desativar a hibernacao e ativar o plano de Desempenho Maximo? Nao recomendado para notebooks usando bateria. (S/N): "
if /i not "%alterarenergia%"=="S" goto energia_pular
if /i "%R_LAPTOP%"=="YES" echo [AVISO] Este PC parece ser um notebook - o plano de Desempenho Maximo aumenta o consumo de bateria.

echo - Desativando hibernacao...
powercfg.exe /hibernate off

echo - Criando e ativando o plano de Desempenho Maximo...
set "NEW_SCHEME="
for /f "tokens=2 delims=:" %%G in ('powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2^>nul') do for /f %%H in ("%%G") do set "NEW_SCHEME=%%H"

if defined NEW_SCHEME (
    powercfg -setactive %NEW_SCHEME% >nul 2>&1
    if errorlevel 1 (
        echo [AVISO] O plano foi criado, mas nao foi possivel ativa-lo.
    ) else (
        echo Plano Desempenho Maximo ativado.
    )
) else (
    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
    if errorlevel 1 (
        echo [AVISO] Nao foi possivel ativar nenhum plano de alto desempenho.
    ) else (
        echo Desempenho Maximo indisponivel neste PC - esquema Alto Desempenho ativado.
    )
)
goto energia_fim

:energia_pular
echo Mantendo os planos de energia atuais.

:energia_fim
:fim_etapa10

call :medir_fim
echo [%date% %time%] Script concluido do inicio ao fim >> "%LOGFILE%"

echo.
call :resumo
if defined HELPER del "%HELPER%" >nul 2>&1
if defined GUI_MODE exit /b 0
pause
goto menu

:: ============================================
:: SUBROTINAS
:: ============================================

:run_step
:: Define RUN_STEP=1 se a etapa %~1 deve rodar. Fica vazio se deve ser pulada.
:: Tambem anota em RAN_n as etapas que rodaram, para o resumo final.
set "RUN_STEP=1"
if not defined STEPS goto run_step_fim
if /i "%STEPS%"=="ALL" goto run_step_fim
set "RUN_STEP="
echo ,%STEPS%, | findstr /c:",%~1," >nul
if not errorlevel 1 set "RUN_STEP=1"
:run_step_fim
if defined RUN_STEP set "RAN_%~1=1"
exit /b 0

:preparar
:: Zera o estado do resumo, define os titulos e tenta preparar o auxiliar em PowerShell.
for /l %%I in (1,1,10) do set "RAN_%%I=" & set "RES_%%I=" & set "NOTE_%%I="
set "ANY_ATENCAO="
set "NEED_REBOOT="
set "FREE_BEFORE="
set "FREE_AFTER="
set "R_FREE="
set "R_PENDING="
set "R_LAPTOP="
set "R_STAMP="
set "R_SFC="
set "TITLE_1=Limpeza de temporarios"
set "TITLE_2=Verificacao de disco e sistema"
set "TITLE_3=Diagnostico da imagem do Windows"
set "TITLE_4=Limpeza de componentes antigos"
set "TITLE_5=Otimizacao de disco"
set "TITLE_6=Logs de eventos do Windows"
set "TITLE_7=Limpeza adicional"
set "TITLE_8=Rede"
set "TITLE_9=Atualizacao de programas"
set "TITLE_10=Ajustes de energia"
set "HELPER="
del /q "%temp%\seabra_helper_*.ps1" >nul 2>&1
set "HELPER_TMP=%temp%\seabra_helper_%random%.ps1"
set "EXTRACT_TAG=HELPER"
set "EXTRACT_OUT=%HELPER_TMP%"
call :extrair
if exist "%HELPER_TMP%" set "HELPER=%HELPER_TMP%"
if not defined HELPER exit /b 0
call :helper Start
set "FREE_BEFORE=%R_FREE%"
if defined R_PENDING if /i not "%R_PENDING%"=="NONE" call :aviso_reboot_pendente
exit /b 0

:helper
:: Chama o auxiliar em PowerShell. Cada linha de saida vem como CHAVE=valor e vira R_CHAVE.
:: Uso: call :helper Start   ou   call :helper Sfc -Since "2026-01-01 10:00:00"
if not defined HELPER exit /b 1
for /f "tokens=1,* delims==" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%HELPER%" -Action %* 2^>nul') do set "R_%%A=%%B"
exit /b 0

:aviso_reboot_pendente
echo [AVISO] Ha uma reinicializacao pendente no Windows: %R_PENDING%
echo         SFC, DISM e a limpeza de componentes podem falhar ou ficar incompletos.
echo         Se possivel, reinicie o PC e rode novamente.
set "NEED_REBOOT=1"
echo [%date% %time%] AVISO reinicializacao pendente: %R_PENDING% >> "%LOGFILE%"
exit /b 0

:veredito_sfc
:: Le o resultado do SFC pelo CBS.log, que nao muda com o idioma do Windows.
if not defined SFC_START exit /b 0
set "R_SFC="
call :helper Sfc -Since "%SFC_START%"
if defined R_SFC echo [%date% %time%] SFC veredito: %R_SFC% >> "%LOGFILE%"
if /i "%R_SFC%"=="Clean" echo [OK] SFC: nenhuma violacao de integridade encontrada.
if /i "%R_SFC%"=="Repaired" call :sfc_reparou
if /i "%R_SFC%"=="Unrepaired" call :marcar 2 "SFC encontrou arquivos corrompidos que NAO conseguiu reparar - rode DISM /RestoreHealth e depois sfc /scannow de novo"
if /i "%R_SFC%"=="Unknown" echo [INFO] Nao foi possivel confirmar o resultado do SFC pelo CBS.log - confira o texto acima.
exit /b 0

:sfc_reparou
echo [OK] SFC: arquivos corrompidos foram encontrados e reparados.
set "NEED_REBOOT=1"
exit /b 0

:marcar
:: Uso: call :marcar NUMERO_DA_ETAPA "texto sem aspas, parenteses ou simbolos especiais"
set "RES_%~1=ATENCAO"
set "NOTE_%~1=%~2"
set "ANY_ATENCAO=1"
echo [AVISO] %~2
echo [%date% %time%] AVISO etapa %~1 - %~2 >> "%LOGFILE%"
exit /b 0

:medir_fim
set "FREE_AFTER="
if not defined HELPER exit /b 0
set "R_FREE="
call :helper End
set "FREE_AFTER=%R_FREE%"
exit /b 0

:resumo
echo ================================================
echo   RESUMO DA EXECUCAO
echo ================================================
for /l %%I in (1,1,10) do call :res_linha %%I
call :res_espaco
echo ------------------------------------------------
if defined ANY_ATENCAO goto resumo_avisos
echo   CONCLUIDO SEM ERROS DETECTADOS
goto resumo_reboot
:resumo_avisos
echo   CONCLUIDO COM AVISOS - veja as linhas AVISO acima
:resumo_reboot
if defined NEED_REBOOT echo   Reinicie o computador para concluir as alteracoes.
echo   Log salvo em: %LOGFILE%
echo ================================================
echo.
exit /b 0

:res_linha
if not defined RAN_%1 exit /b 0
set "ST="
set "TT="
set "NN="
call set "ST=%%RES_%1%%"
call set "TT=%%TITLE_%1%%"
call set "NN=%%NOTE_%1%%"
if not defined ST set "ST=OK"
if "%ST%"=="OK" echo   [ OK ]  %1. %TT%
if not "%ST%"=="OK" echo   [AVISO] %1. %TT%
if defined NN echo           - %NN%
exit /b 0

:res_espaco
if not defined FREE_BEFORE exit /b 0
if not defined FREE_AFTER exit /b 0
set /a "DELTA=FREE_AFTER-FREE_BEFORE"
call :fmt_mb %FREE_BEFORE%
set "F1=%FMT%"
call :fmt_mb %FREE_AFTER%
set "F2=%FMT%"
if %DELTA% GTR 0 goto res_esp_mais
if %DELTA% LSS 0 goto res_esp_menos
echo   Espaco livre em %SystemDrive% sem variacao: %F1%
exit /b 0
:res_esp_mais
call :fmt_mb %DELTA%
echo   Espaco livre em %SystemDrive% aumentou %FMT% - antes %F1%, agora %F2%
exit /b 0
:res_esp_menos
set /a "DELTA=-DELTA"
call :fmt_mb %DELTA%
echo   Espaco livre em %SystemDrive% diminuiu %FMT% - antes %F1%, agora %F2%
echo   Isso pode vir de atualizacoes de programas ou de arquivos temporarios dos reparos.
exit /b 0

:fmt_mb
:: Converte um valor em MB para texto: MB abaixo de 1024, senao GB com uma casa decimal.
set /a "V=%~1"
if %V% GEQ 1024 goto fmt_gb
set "FMT=%V% MB"
exit /b 0
:fmt_gb
set /a "T=V*10/1024, I=T/10, D=T%%10"
set "FMT=%I%,%D% GB"
exit /b 0

:extrair
:: Copia o trecho entre as marcas BEGIN e END da etiqueta EXTRACT_TAG, no fim deste arquivo,
:: para o arquivo EXTRACT_OUT, em UTF-8 com BOM. As marcas sao montadas aos pedacos para nao
:: se acharem a si mesmas.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:SEABRA_BAT,[Text.Encoding]::UTF8); $a=$t.IndexOf('#'+$env:EXTRACT_TAG+'-BEGIN'); $b=$t.IndexOf('#'+$env:EXTRACT_TAG+'-END'); if($a -lt 0 -or $b -lt $a){exit 1}; $a=$t.IndexOf([char]10,$a)+1; [IO.File]::WriteAllText($env:EXTRACT_OUT,$t.Substring($a,$b-$a),(New-Object Text.UTF8Encoding $true))"
exit /b 0

:banner
echo.
echo                  _               
echo   ___  ___  __ _^| ^|__  _ __ __ _ 
echo  / __^|/ _ \/ _` ^| '_ \^| '__/ _` ^|
echo  \__ \  __/ (_^| ^| ^|_) ^| ^| ^| (_^| ^|
echo  ^|___/\___/\__,_^|_.__/^|_^|  \__,_^|
echo.
echo                github.com/Seabratex
echo.
exit /b

:: ============================================================
:: CODIGO POWERSHELL EMBUTIDO (janela grafica e auxiliar) - NAO e executado pelo cmd.
:: Nada abaixo e lido pelo cmd: o arquivo termina em "exit /b" acima.
:: O texto abaixo esta em UTF-8, por isso os acentos aparecem certos na janela.
:: ============================================================
#GUI-BEGIN
<#
    Otimizar Windows - Interface Gráfica (embutida no otimizar.bat)
    github.com/Seabratex

    Este trecho vive dentro do otimizar.bat. Ao escolher a opção 1 do menu, o .bat grava uma
    cópia temporária daqui, abre a janela e apaga a cópia ao fechar. A janela executa o próprio
    otimizar.bat em modo gráfico, mostrando a saída ao vivo.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------- administrador
# O otimizar.bat já pede e confirma a permissão de administrador antes de abrir esta janela.
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show("Esta interface precisa de permissão de administrador.`n`nAbra o otimizar.bat novamente e confirme o pedido do Windows.", 'Otimizar Windows', 'OK', 'Warning') | Out-Null
    exit 1
}

# ---------------------------------------------------------------- nitidez em telas HiDPI
try {
    Add-Type -Namespace Seabra -Name Dpi -MemberDefinition '[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
    [void][Seabra.Dpi]::SetProcessDPIAware()
} catch { }
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------------------------------------------------------------- caminhos
# O otimizar.bat informa o próprio caminho. Este código roda de uma cópia temporária.
$BatPath = $env:SEABRA_BAT
if (-not $BatPath -or -not (Test-Path -LiteralPath $BatPath)) {
    [System.Windows.Forms.MessageBox]::Show("Não encontrei o otimizar.bat.`n`nAbra a interface pelo menu do otimizar.bat.", 'Otimizar Windows', 'OK', 'Error') | Out-Null
    exit 1
}
$ScriptDir = Split-Path -Parent $BatPath
$LogPath   = Join-Path $ScriptDir ([System.IO.Path]::GetFileNameWithoutExtension($BatPath) + '_log.txt')

# A saída do cmd usa a página de código OEM (ex.: 850), não UTF-8.
try {
    $oemCp = [int](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage' -Name OEMCP).OEMCP
    $OemEncoding = [System.Text.Encoding]::GetEncoding($oemCp)
} catch {
    $OemEncoding = [System.Text.Encoding]::GetEncoding(850)
}

# ---------------------------------------------------------------- tema azul-marinho e prata
function Get-Color([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
$Navy      = Get-Color '#0A1A33'
$NavyLight = Get-Color '#12294D'
$NavyDeep  = Get-Color '#06101F'
$Silver     = Get-Color '#D3DCEA'
$SilverDim  = Get-Color '#7F8CA3'
$TextLight = Get-Color '#EDEFF3'
$TextMuted = Get-Color '#9AA8BF'
$Green     = Get-Color '#6FD99A'
$Amber     = Get-Color '#F2C14E'
$Red       = Get-Color '#FF7B7B'

$FontUi   = New-Object System.Drawing.Font('Segoe UI', 9.5)
$FontBold = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
$FontHead = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$FontMono = New-Object System.Drawing.Font('Consolas', 9)
$FontMonoB = New-Object System.Drawing.Font('Consolas', 9, [System.Drawing.FontStyle]::Bold)

# ---------------------------------------------------------------- dados
$Steps = @(
    [pscustomobject]@{ N = 1;  Title = 'Limpeza de temporários';             Tip = 'Temp, Recent, cache do Windows Update, miniaturas, ícones e relatórios de erro.' }
    [pscustomobject]@{ N = 2;  Title = 'Verificação de disco e sistema';     Tip = 'chkdsk /scan e sfc /scannow.' }
    [pscustomobject]@{ N = 3;  Title = 'Diagnóstico da imagem do Windows';   Tip = 'DISM CheckHealth e ScanHealth (só diagnóstico).' }
    [pscustomobject]@{ N = 4;  Title = 'Limpeza de componentes antigos';     Tip = 'Limpeza do WinSxS via DISM.' }
    [pscustomobject]@{ N = 5;  Title = 'Otimização de disco';                Tip = 'TRIM em SSD ou desfragmentação em HDD.' }
    [pscustomobject]@{ N = 6;  Title = 'Logs de eventos do Windows';         Tip = 'Limpa o Visualizador de Eventos (se a opção ao lado estiver marcada).' }
    [pscustomobject]@{ N = 7;  Title = 'Limpeza adicional';                  Tip = 'Limpeza de Disco do Windows (categorias seguras) e Storage Sense.' }
    [pscustomobject]@{ N = 8;  Title = 'Rede';                               Tip = 'Limpa DNS e renova o IP. Resets opcionais na lista de opções.' }
    [pscustomobject]@{ N = 9;  Title = 'Atualização de programas';           Tip = 'winget upgrade --all.' }
    [pscustomobject]@{ N = 10; Title = 'Ajustes de energia';                 Tip = 'Só age se a opção de energia estiver marcada.' }
)
$Options = @(
    [pscustomobject]@{ Var = 'limparpref';     Step = 1;  Text = 'Limpar a pasta Prefetch (geralmente desnecessário)';                      Tip = 'O Windows recria a pasta. Apps podem abrir um pouco mais lentos na primeira vez.' }
    [pscustomobject]@{ Var = 'rodarchk';       Step = 2;  Text = 'Agendar verificação completa do disco (chkdsk /f /r). Exige reiniciar';   Tip = 'A verificação roda na próxima inicialização e pode demorar bastante.' }
    [pscustomobject]@{ Var = 'resetbase';      Step = 4;  Text = 'Remover TODAS as versões antigas de updates (/ResetBase). Sem volta';      Tip = 'Libera mais espaço, mas você perde a opção de desinstalar atualizações já aplicadas.' }
    [pscustomobject]@{ Var = 'limparlogs';     Step = 6;  Text = 'Limpar os logs do Visualizador de Eventos. Apaga histórico de diagnóstico'; Tip = 'Os logs ajudam a descobrir a causa de erros e travamentos.' }
    [pscustomobject]@{ Var = 'resetrede';      Step = 8;  Text = 'Resetar Winsock, proxy e TCP/IP. Exige reiniciar';                        Tip = 'Útil quando a internet está instável ou lenta.' }
    [pscustomobject]@{ Var = 'alterarenergia'; Step = 10; Text = 'Desativar hibernação e ativar Desempenho Máximo. Evite em notebook na bateria'; Tip = 'Mantém o PC sempre em alto desempenho, com mais consumo de energia.' }
)

$Art = @'
                 _
  ___  ___  __ _| |__  _ __ __ _
 / __|/ _ \/ _` | '_ \| '__/ _` |
 \__ \  __/ (_| | |_) | | | (_| |
 |___/\___|\__,_|_.__/|_|  \__,_|
'@

# ---------------------------------------------------------------- estado
$script:proc       = $null
$script:outTask    = $null
$script:cancelled  = $false
$script:running    = $false
$script:selected   = @()
$script:stepLabel  = ''
$script:lastBlank  = $false
$script:hadWarnings = $false

# ---------------------------------------------------------------- janela
$form = New-Object System.Windows.Forms.Form
$form.Text            = 'Otimizar Windows - Seabra'
$form.StartPosition   = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox     = $false
$form.BackColor       = $Navy
$form.ForeColor       = $TextLight
$form.Font            = $FontUi
$form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
$form.AutoScaleMode   = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.ClientSize      = New-Object System.Drawing.Size(1000, 750)

$tip = New-Object System.Windows.Forms.ToolTip
$tip.AutoPopDelay = 12000
$tip.InitialDelay = 400

function New-Label([string]$text, [int]$x, [int]$y, [int]$w, [int]$h, $font, $color) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Font = $font; $l.ForeColor = $color; $l.BackColor = [System.Drawing.Color]::Transparent
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, $h)
    return $l
}

function New-Button([string]$text, [int]$x, [int]$y, [int]$w, [int]$h, [bool]$primary) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = New-Object System.Drawing.Point($x, $y)
    $b.Size = New-Object System.Drawing.Size($w, $h)
    $b.FlatStyle = 'Flat'
    $b.Cursor = 'Hand'
    $b.Font = $FontBold
    $b.FlatAppearance.BorderSize = 1
    if ($primary) {
        $b.BackColor = $Silver; $b.ForeColor = $NavyDeep
        $b.FlatAppearance.BorderColor = $Silver
    } else {
        $b.BackColor = $NavyLight; $b.ForeColor = $TextLight
        $b.FlatAppearance.BorderColor = $SilverDim
    }
    return $b
}

# ---- cabeçalho
$header = New-Object System.Windows.Forms.Panel
$header.Location  = New-Object System.Drawing.Point(0, 0)
$header.Size      = New-Object System.Drawing.Size(1000, 112)
$header.BackColor = $NavyDeep
$form.Controls.Add($header)

$lblArt = New-Object System.Windows.Forms.Label
$lblArt.Text      = $Art.TrimEnd()
$lblArt.Font      = New-Object System.Drawing.Font('Consolas', 10)
$lblArt.ForeColor = $Silver
$lblArt.AutoSize  = $true
$lblArt.Location  = New-Object System.Drawing.Point(24, 16)
$header.Controls.Add($lblArt)

$lblTitle = New-Label 'Otimizar Windows' 372 14 560 44 (New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)) $Silver
$header.Controls.Add($lblTitle)
$lblSub = New-Label 'Manutenção e otimização para Windows 10 e 11' 375 62 560 22 $FontUi $TextMuted
$header.Controls.Add($lblSub)

$lnk = New-Object System.Windows.Forms.LinkLabel
$lnk.Text = 'github.com/Seabratex'
$lnk.Font = $FontUi
$lnk.LinkColor = $Silver
$lnk.ActiveLinkColor = $TextLight
$lnk.VisitedLinkColor = $Silver
$lnk.BackColor = [System.Drawing.Color]::Transparent
$lnk.LinkBehavior = 'HoverUnderline'
$lnk.Location = New-Object System.Drawing.Point(375, 84)
$lnk.Size = New-Object System.Drawing.Size(300, 22)
$lnk.Add_LinkClicked({ Start-Process 'https://github.com/Seabratex' })
$header.Controls.Add($lnk)

# ---- etapas
$form.Controls.Add((New-Label 'ETAPAS' 24 126 300 22 $FontHead $Silver))
$pnlSteps = New-Object System.Windows.Forms.Panel
$pnlSteps.Location  = New-Object System.Drawing.Point(24, 152)
$pnlSteps.Size      = New-Object System.Drawing.Size(460, 312)
$pnlSteps.BackColor = $NavyLight
$form.Controls.Add($pnlSteps)

$stepChecks = @()
$stepByN    = @{}
$i = 0
foreach ($s in $Steps) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text      = ('{0}.   {1}' -f $s.N, $s.Title)
    $cb.Tag       = $s.N
    $cb.Checked   = $true
    $cb.AutoSize  = $false
    $cb.Location  = New-Object System.Drawing.Point(16, (10 + $i * 30))
    $cb.Size      = New-Object System.Drawing.Size(430, 26)
    $cb.ForeColor = $TextLight
    $cb.BackColor = [System.Drawing.Color]::Transparent
    $cb.Cursor    = 'Hand'
    $tip.SetToolTip($cb, $s.Tip)
    $cb.Add_CheckedChanged({ Sync-Options })
    $pnlSteps.Controls.Add($cb)
    $stepChecks += $cb
    $stepByN[$s.N] = $cb
    $i++
}

# ---- opções
$form.Controls.Add((New-Label 'OPÇÕES  (as perguntas que o script faria)' 516 126 460 22 $FontHead $Silver))
$pnlOpts = New-Object System.Windows.Forms.Panel
$pnlOpts.Location  = New-Object System.Drawing.Point(516, 152)
$pnlOpts.Size      = New-Object System.Drawing.Size(460, 312)
$pnlOpts.BackColor = $NavyLight
$form.Controls.Add($pnlOpts)

$optChecks = @()
$optStep   = @{}
$i = 0
foreach ($o in $Options) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text      = $o.Text
    $cb.Tag       = $o.Var
    $cb.Checked   = $false
    $cb.AutoSize  = $false
    $cb.Location  = New-Object System.Drawing.Point(16, (12 + $i * 49))
    $cb.Size      = New-Object System.Drawing.Size(430, 44)
    $cb.ForeColor = $TextLight
    $cb.BackColor = [System.Drawing.Color]::Transparent
    $cb.Cursor    = 'Hand'
    $tip.SetToolTip($cb, $o.Tip)
    $pnlOpts.Controls.Add($cb)
    $optChecks += $cb
    $optStep[$o.Var] = $o.Step
    $i++
}

# ---- saída
$form.Controls.Add((New-Label 'SAÍDA' 24 474 300 22 $FontHead $Silver))
$rtb = New-Object System.Windows.Forms.RichTextBox
$rtb.Location    = New-Object System.Drawing.Point(24, 498)
$rtb.Size        = New-Object System.Drawing.Size(952, 152)
$rtb.BackColor   = $NavyDeep
$rtb.ForeColor   = $TextLight
$rtb.Font        = $FontMono
$rtb.BorderStyle = 'None'
$rtb.ReadOnly    = $true
$rtb.DetectUrls  = $false
$rtb.WordWrap    = $true
$rtb.ScrollBars  = 'Vertical'
$form.Controls.Add($rtb)

# ---- barra de progresso (painel dourado sobre painel escuro, para respeitar o tema)
$barBg = New-Object System.Windows.Forms.Panel
$barBg.Location  = New-Object System.Drawing.Point(24, 662)
$barBg.Size      = New-Object System.Drawing.Size(952, 12)
$barBg.BackColor = $NavyLight
$form.Controls.Add($barBg)
$barFill = New-Object System.Windows.Forms.Panel
$barFill.Location  = New-Object System.Drawing.Point(0, 0)
$barFill.Size      = New-Object System.Drawing.Size(0, 12)
$barFill.BackColor = $Silver
$barBg.Controls.Add($barFill)

$lblStatus = New-Label 'Pronto. Escolha as etapas e clique em Executar.' 24 708 460 24 $FontUi $TextMuted
$form.Controls.Add($lblStatus)

# ---- botões
$btnRun    = New-Button 'Executar'        496 700 150 36 $true
$btnCancel = New-Button 'Cancelar'        656 700 100 36 $false
$btnLog    = New-Button 'Abrir log'       766 700 110 36 $false
$btnExit   = New-Button 'Sair'            886 700 90  36 $false
$btnCancel.Enabled = $false
foreach ($b in @($btnRun, $btnCancel, $btnLog, $btnExit)) { $form.Controls.Add($b) }

# ---------------------------------------------------------------- funções
function Set-Bar([int]$pct) {
    if ($pct -lt 0) { $pct = 0 }
    if ($pct -gt 100) { $pct = 100 }
    $barFill.Width = [int]($barBg.Width * $pct / 100)
}

function Add-Log([string]$text, $color = $null, [bool]$bold = $false) {
    if ($null -eq $color) { $color = $TextLight }
    $rtb.SelectionStart  = $rtb.TextLength
    $rtb.SelectionLength = 0
    $rtb.SelectionColor  = $color
    if ($bold) { $rtb.SelectionFont = $FontMonoB } else { $rtb.SelectionFont = $FontMono }
    $rtb.AppendText($text + [Environment]::NewLine)
    $rtb.SelectionStart = $rtb.TextLength
    $rtb.ScrollToCaret()
}

function Sync-Options {
    foreach ($oc in $optChecks) {
        $stepOn = $stepByN[[int]$optStep[$oc.Tag]].Checked
        $oc.Enabled = ((-not $script:running) -and $stepOn)
    }
}

function Set-Running([bool]$on) {
    $script:running = $on
    foreach ($c in $stepChecks) { $c.Enabled = -not $on }
    $btnRun.Enabled    = -not $on
    $btnCancel.Enabled = $on
    Sync-Options
}

# linhas de progresso do DISM/sfc/chkdsk chegam com retorno de carro: mostramos só na barra de status
$ProgressBarLine = '^\s*\[[= ]*(\d+(?:[.,]\d+)?)%[= ]*\]'
$ProgressTextLine = '(?i)(\d+(?:[.,]\d+)?\s*%\s*(conclu|complet))|(percent complete)|(por cento conclu)'

function Handle-Line([string]$line) {
    if ($null -eq $line) { return }
    $t = $line.TrimEnd()

    if ($t -match $ProgressBarLine) {
        $lblStatus.Text = ('{0}  -  {1}%' -f $script:stepLabel, $Matches[1])
        return
    }
    if ($t -match $ProgressTextLine) { return }

    if ($t.Trim() -eq '') {
        if ($script:lastBlank) { return }
        $script:lastBlank = $true
        Add-Log ''
        return
    }
    $script:lastBlank = $false

    if ($t -match '^\s*\[(\d{1,2})/10\]\s*(.*)$') {
        $n = [int]$Matches[1]
        $pos = [array]::IndexOf($script:selected, $n)
        if ($pos -ge 0) {
            Set-Bar ([int](100 * $pos / $script:selected.Count))
            $script:stepLabel = ('Etapa {0} ({1} de {2})  -  {3}' -f $n, ($pos + 1), $script:selected.Count, $Matches[2].TrimEnd('.'))
            $lblStatus.Text = $script:stepLabel
        }
        Add-Log $t $Silver $true
    }
    elseif ($t -match '^\s*\[ERRO\]')  { Add-Log $t $Red }
    elseif ($t -match '^\s*\[AVISO\]') { Add-Log $t $Amber }
    elseif ($t -match '^\s*\[\s*OK\s*\]') { Add-Log $t $Green }
    elseif ($t -match '^\s*\[INFO\]') { Add-Log $t $TextMuted }
    elseif ($t -match 'CONCLUIDO COM AVISOS')   { $script:hadWarnings = $true; Add-Log $t $Amber $true }
    elseif ($t -match 'CONCLUIDO SEM ERROS')    { Add-Log $t $Green $true }
    elseif ($t -match '^\s*RESUMO DA EXECUCAO') { Add-Log $t $Silver $true }
    elseif ($t -match '^\s*-\s')       { Add-Log $t $TextMuted }
    else                               { Add-Log $t }
}

function Finish-Run {
    $timer.Stop()
    $wasCancelled = $script:cancelled
    $script:proc    = $null
    $script:outTask = $null
    Set-Running $false
    if ($wasCancelled) {
        Set-Bar 0
        Add-Log '- Execução cancelada -' $Amber $true
        $lblStatus.Text = 'Cancelado.'
    } else {
        Set-Bar 100
        if ($script:hadWarnings) {
            Add-Log 'Concluído com avisos. Confira o resumo acima.' $Amber $true
            $lblStatus.Text = 'Concluído com avisos. Confira o resumo na Saída.'
        } else {
            Add-Log 'Concluído sem erros detectados.' $Green $true
            $lblStatus.Text = 'Concluído sem erros detectados.'
        }
    }
}

function Stop-Run {
    if ($null -eq $script:proc) { return }
    $script:cancelled = $true
    try {
        Start-Process -FilePath 'taskkill.exe' -ArgumentList @('/PID', $script:proc.Id, '/T', '/F') -WindowStyle Hidden -Wait
    } catch { }
}

function Pump-Output {
    if ($null -eq $script:proc) { return }
    try {
        $count = 0
        while (($null -ne $script:outTask) -and $script:outTask.IsCompleted -and ($count -lt 300)) {
            $line = $null
            try { $line = $script:outTask.Result } catch { $line = $null }
            if ($null -eq $line) { $script:outTask = $null; break }
            Handle-Line $line
            $script:outTask = $script:proc.StandardOutput.ReadLineAsync()
            $count++
        }
        if ((($null -eq $script:outTask) -and $script:proc.HasExited) -or ($script:cancelled -and $script:proc.HasExited)) {
            Finish-Run
        }
    } catch {
        Add-Log ('[ERRO] Falha ao ler a saída: ' + $_.Exception.Message) $Red
        Finish-Run
    }
}

function Start-Run {
    $sel = @()
    foreach ($c in $stepChecks) { if ($c.Checked) { $sel += [int]$c.Tag } }
    if ($sel.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Selecione ao menos uma etapa.', 'Otimizar Windows', 'OK', 'Information') | Out-Null
        return
    }

    $answers = @{}
    foreach ($oc in $optChecks) { $answers[[string]$oc.Tag] = $(if ($oc.Checked -and $oc.Enabled) { 'S' } else { 'N' }) }

    $msg = "Executar {0} etapa(s)?`n`nO script faz alterações reais no sistema. Salve seu trabalho antes de continuar." -f $sel.Count
    if ($answers['rodarchk'] -eq 'S' -or $answers['resetrede'] -eq 'S') {
        $msg += "`n`nAlgumas opções escolhidas exigem reiniciar o computador depois."
    }
    $r = [System.Windows.Forms.MessageBox]::Show($msg, 'Confirmar', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }

    $script:selected  = $sel | Sort-Object
    $script:cancelled = $false
    $script:lastBlank = $false
    $script:hadWarnings = $false
    $script:stepLabel = 'Iniciando...'

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $env:ComSpec
    $psi.Arguments              = '/d /c ""' + $BatPath + '" 2>&1"'
    $psi.WorkingDirectory       = $ScriptDir
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardInput  = $true
    $psi.StandardOutputEncoding = $OemEncoding
    $psi.EnvironmentVariables['GUI_MODE'] = '1'
    $psi.EnvironmentVariables['STEPS']    = ($script:selected -join ',')
    foreach ($k in $answers.Keys) { $psi.EnvironmentVariables[$k] = $answers[$k] }

    $rtb.Clear()
    Set-Bar 0
    Add-Log ('Etapas: ' + ($script:selected -join ', ')) $TextMuted
    Set-Running $true
    $lblStatus.Text = $script:stepLabel

    try {
        $script:proc = [System.Diagnostics.Process]::Start($psi)
        $script:proc.StandardInput.Close()
        $script:outTask = $script:proc.StandardOutput.ReadLineAsync()
        $timer.Start()
    } catch {
        Add-Log ('[ERRO] Não foi possível iniciar o script: ' + $_.Exception.Message) $Red
        $script:proc = $null
        Set-Running $false
        $lblStatus.Text = 'Erro ao iniciar.'
    }
}

# ---------------------------------------------------------------- eventos
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 120
$timer.Add_Tick({ Pump-Output })

$btnRun.Add_Click({ Start-Run })
$btnCancel.Add_Click({
    $r = [System.Windows.Forms.MessageBox]::Show("Cancelar a otimização em andamento?`n`nO processo atual será interrompido. Serviços como o Windows Update podem ficar parados até reiniciar o PC.", 'Cancelar', 'YesNo', 'Warning')
    if ($r -eq 'Yes') { Stop-Run }
})
$btnLog.Add_Click({
    if (Test-Path -LiteralPath $LogPath) {
        Start-Process -FilePath 'notepad.exe' -ArgumentList ('"{0}"' -f $LogPath)
    } else {
        [System.Windows.Forms.MessageBox]::Show('Nenhum log encontrado ainda. Rode a otimização primeiro.', 'Otimizar Windows', 'OK', 'Information') | Out-Null
    }
})
$btnExit.Add_Click({ $form.Close() })

$form.Add_FormClosing({
    if ($script:running) {
        $r = [System.Windows.Forms.MessageBox]::Show("Há uma otimização em andamento.`n`nCancelar e sair?", 'Sair', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { $_.Cancel = $true; return }
        Stop-Run
    }
})

Sync-Options
Add-Log 'Pronto. Escolha as etapas e as opções e clique em Executar.' $TextMuted
[void]$form.ShowDialog()
#GUI-END
#HELPER-BEGIN
<#
    Auxiliar do otimizar.bat (somente leitura: nao altera nada no sistema).
    Saida no formato CHAVE=valor, uma por linha, lida pelo .bat.

      Start  -> FREE (MB livres em C:), PENDING (motivos ou NONE), LAPTOP (YES/NO/UNKNOWN), STAMP
      End    -> FREE
      Stamp  -> STAMP (data e hora no formato yyyy-MM-dd HH:mm:ss, igual ao do CBS.log)
      Sfc    -> SFC (Clean, Repaired, Unrepaired ou Unknown), lendo o CBS.log desde -Since
#>
param(
    [Parameter(Mandatory = $true)][ValidateSet('Start', 'End', 'Stamp', 'Sfc')][string]$Action,
    [string]$Since,
    [string]$CbsLog
)

$ErrorActionPreference = 'SilentlyContinue'
$inv = [System.Globalization.CultureInfo]::InvariantCulture

# Tira caracteres que atrapalhariam o cmd quando o valor volta para o .bat.
function Clean([string]$s) {
    if ($null -eq $s) { return '' }
    return (($s -replace '[\r\n()&|<>^%"=]', ' ') -replace '\s+', ' ').Trim()
}

function Get-FreeMB {
    try {
        $letter = ([string]$env:SystemDrive).TrimEnd(':')
        if (-not $letter) { $letter = 'C' }
        $free = (Get-PSDrive -Name $letter -ErrorAction Stop).Free
        return [int64][math]::Floor($free / 1MB)
    } catch { return $null }
}

function Get-PendingReboot {
    $reasons = @()
    try {
        if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $reasons += 'Component Based Servicing' }
        if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $reasons += 'Windows Update' }
        $sm = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
        if ($sm -and $sm.PendingFileRenameOperations) { $reasons += 'arquivos aguardando troca no proximo boot' }
    } catch { }
    if ($reasons.Count -eq 0) { return 'NONE' }
    return (Clean ($reasons -join ', '))
}

function Get-IsLaptop {
    try {
        $enc = Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction Stop
        $laptop  = 8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32
        $desktop = 3, 4, 5, 6, 7, 13, 15, 16, 17, 23, 24, 35, 36
        foreach ($t in @($enc.ChassisTypes)) {
            if ($laptop -contains [int]$t) { return 'YES' }
        }
        foreach ($t in @($enc.ChassisTypes)) {
            if ($desktop -contains [int]$t) { return 'NO' }
        }
        if (Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue) { return 'YES' }
        return 'NO'
    } catch { return 'UNKNOWN' }
}

function Get-SfcVerdict([string]$SinceText, [string]$LogPath) {
    # As marcas [SR] do CBS.log ficam sempre em ingles, mesmo em Windows em portugues.
    if (-not $LogPath) { $LogPath = Join-Path ([string]$env:SystemRoot) 'Logs\CBS\CBS.log' }
    $since = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($SinceText, 'yyyy-MM-dd HH:mm:ss', $inv, 'None', [ref]$since)) { return 'Unknown' }
    if (-not (Test-Path -LiteralPath $LogPath)) { return 'Unknown' }
    try {
        $lines = Get-Content -LiteralPath $LogPath -Tail 60000 -ErrorAction Stop | Where-Object { $_ -match '\[SR\]' }
    } catch { return 'Unknown' }
    $seen = $false; $repaired = $false; $unrepaired = $false
    foreach ($line in $lines) {
        if ($line.Length -lt 19) { continue }
        $ts = [datetime]::MinValue
        if (-not [datetime]::TryParseExact($line.Substring(0, 19), 'yyyy-MM-dd HH:mm:ss', $inv, 'None', [ref]$ts)) { continue }
        if ($ts -lt $since) { continue }
        $seen = $true
        if ($line -match 'Cannot repair member file') { $unrepaired = $true }
        elseif ($line -match 'Repairing corrupted file') { $repaired = $true }
    }
    if (-not $seen)    { return 'Unknown' }
    if ($unrepaired)   { return 'Unrepaired' }
    if ($repaired)     { return 'Repaired' }
    return 'Clean'
}

switch ($Action) {
    'Start' {
        $mb = Get-FreeMB
        if ($null -ne $mb) { "FREE=$mb" }
        "PENDING=$(Get-PendingReboot)"
        "LAPTOP=$(Get-IsLaptop)"
        "STAMP=$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss', $inv))"
    }
    'End' {
        $mb = Get-FreeMB
        if ($null -ne $mb) { "FREE=$mb" }
    }
    'Stamp' {
        "STAMP=$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss', $inv))"
    }
    'Sfc' {
        "SFC=$(Get-SfcVerdict $Since $CbsLog)"
    }
}
#HELPER-END

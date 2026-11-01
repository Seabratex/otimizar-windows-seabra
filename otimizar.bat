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

title Otimizacao do PC - Artur
if not defined GUI_MODE color 1E

:: Modo interface grafica (GUI_MODE=1): pula o menu e nao faz perguntas,
:: pois as respostas e as etapas escolhidas chegam por variaveis de ambiente.
if defined GUI_MODE goto iniciar

:menu
cls
call :banner
echo   ================================================
echo     [1]  Otimizacao completa - todas as etapas
echo     [2]  Escolher etapas
echo     [3]  Abrir interface grafica
echo     [4]  Abrir o log da ultima execucao
echo     [0]  Sair
echo   ================================================
echo.
set "op="
set /p op="  Escolha uma opcao: "
if "%op%"=="1" goto op_completa
if "%op%"=="2" goto op_escolher
if "%op%"=="3" goto op_gui
if "%op%"=="4" goto op_log
if "%op%"=="0" exit
goto menu

:op_completa
set "STEPS=ALL"
goto iniciar

:op_escolher
cls
call :banner
echo   Etapas disponiveis:
echo.
echo     1   Limpeza de temporarios
echo     2   Verificacao de disco e sistema - chkdsk e sfc
echo     3   Diagnostico da imagem do Windows - DISM
echo     4   Limpeza de componentes antigos - WinSxS
echo     5   Otimizacao de disco - TRIM ou desfragmentacao
echo     6   Logs de eventos do Windows
echo     7   Limpeza adicional - cleanmgr e Storage Sense
echo     8   Rede - DNS, IP e resets opcionais
echo     9   Atualizacao de programas - winget
echo    10   Ajustes de energia
echo.
set "STEPS="
set /p STEPS="  Digite os numeros separados por virgula, ex 1,5,7  ou V para voltar: "
if /i "%STEPS%"=="V" goto menu
if not defined STEPS goto op_escolher
set "STEPS=%STEPS: =,%"
goto iniciar

:op_gui
if exist "%~dp0OtimizarGUI.ps1" goto op_gui_abrir
echo.
echo   [ERRO] OtimizarGUI.ps1 nao foi encontrado na mesma pasta do otimizar.bat.
pause
goto menu

:op_gui_abrir
echo.
echo   Abrindo a interface grafica...
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0OtimizarGUI.ps1"
goto menu

:op_log
if not exist "%LOGFILE%" goto op_log_vazio
start "" notepad "%LOGFILE%"
goto menu

:op_log_vazio
echo.
echo   Nenhum log encontrado ainda. Rode a otimizacao primeiro.
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
net stop wuauserv >nul 2>&1
del /q /f /s "C:\Windows\SoftwareDistribution\Download\*.*" >nul 2>&1
for /d %%x in ("C:\Windows\SoftwareDistribution\Download\*") do rd /s /q "%%x" >nul 2>&1
net start wuauserv >nul 2>&1

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

echo.
if not defined rodarchk set /p rodarchk="Deseja agendar verificacao completa de disco (chkdsk /f /r)? Isso exige reiniciar o PC. (S/N): "
if /i "%rodarchk%"=="S" (
    echo Agendando chkdsk /f /r para a proxima reinicializacao...
    (echo S& echo Y)| chkdsk C: /f /r
) else (
    echo Pulando chkdsk /f /r.
)
echo.

echo - Verificando arquivos de sistema (sfc)...
sfc /scannow

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
dism /online /cleanup-image /scanhealth

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

echo.
if not defined resetbase set /p resetbase="Deseja tambem remover TODAS as versoes antigas de updates (/ResetBase)? Isso libera mais espaco, mas voce perde a opcao de desinstalar atualizacoes ja aplicadas. (S/N): "
if /i "%resetbase%"=="S" (
    echo Executando limpeza completa com ResetBase...
    dism /online /cleanup-image /StartComponentCleanup /ResetBase
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
    goto pular_winget
)
set "winget_exe=%wingetpath%\winget.exe"

:winget_executar
echo Executando: %winget_exe% upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements
"%winget_exe%" upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements --disable-interactivity

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

echo [%date% %time%] Script concluido do inicio ao fim >> "%LOGFILE%"

echo.
echo ================================================
echo   OTIMIZACAO CONCLUIDA COM SUCESSO!
echo   Recomenda-se reiniciar o computador.
echo   Log salvo em: %LOGFILE%
echo ================================================
echo.
if defined GUI_MODE exit /b 0
pause
goto menu

:: ============================================
:: SUBROTINAS
:: ============================================

:run_step
:: Define RUN_STEP=1 se a etapa %~1 deve rodar. Fica vazio se deve ser pulada.
set "RUN_STEP=1"
if not defined STEPS exit /b 0
if /i "%STEPS%"=="ALL" exit /b 0
set "RUN_STEP="
echo ,%STEPS%, | findstr /c:",%~1," >nul
if not errorlevel 1 set "RUN_STEP=1"
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

@echo off
:: ============================================
::   SCRIPT DE OTIMIZACAO - Artur
:: ============================================

:: --- Auto-elevacao (pede admin automaticamente) ---
cd /d "%~dp0"
>nul 2>&1 "%SystemRoot%\system32\cacls.exe" "%SystemRoot%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Solicitando permissao de administrador...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    if errorlevel 1 (
        echo Nao foi possivel elevar automaticamente.
        echo Clique com o botao direito no arquivo e escolha "Executar como administrador".
        pause
    )
    exit /b
)

title Otimizacao do PC - Artur
color 09
cls

echo.
echo                  _               
echo   ___  ___  __ _^| ^|__  _ __ __ _ 
echo  / __^|/ _ \/ _` ^| '_ \^| '__/ _` ^|
echo  \__ \  __/ (_^| ^| ^|_) ^| ^| ^| (_^| ^|
echo  ^|___/\___/\__,_^|_.__/^|_^|  \__,_^|
echo.
echo                github.com/Seabratex
echo.
echo ================================================
echo         INICIANDO OTIMIZACAO DO SISTEMA
echo ================================================
echo.
pause

:: ============================================
:: 1. LIMPEZA DE ARQUIVOS TEMPORARIOS
:: ============================================
echo.
echo [1/10] Limpando arquivos temporarios...
echo ------------------------------------------------

echo - Limpando %%temp%%...
del /q /f /s "%temp%\*.*" >nul 2>&1
for /d %%x in ("%temp%\*") do rd /s /q "%%x" >nul 2>&1

echo - Limpando C:\Windows\Temp...
del /q /f /s "C:\Windows\Temp\*.*" >nul 2>&1
for /d %%x in ("C:\Windows\Temp\*") do rd /s /q "%%x" >nul 2>&1

echo - Limpando Prefetch...
takeown /f "C:\Windows\Prefetch" /r /d y >nul 2>&1
icacls "C:\Windows\Prefetch" /grant administradores:F /t >nul 2>&1
del /q /f /s "C:\Windows\Prefetch\*.*" >nul 2>&1

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

:: ============================================
:: 2. VERIFICACAO DE DISCO E ARQUIVOS DE SISTEMA
:: ============================================
echo [2/10] Verificando disco e integridade do sistema...
echo ------------------------------------------------

echo - Agendando verificacao de disco (chkdsk)...
chkdsk C: /scan

echo.
set /p rodarchk="Deseja agendar verificacao completa de disco (chkdsk /f /r)? Isso exige reiniciar o PC. (S/N): "
if /i "%rodarchk%"=="S" (
    echo Agendando chkdsk /f /r para a proxima reinicializacao...
    chkdsk C: /f /r
) else (
    echo Pulando chkdsk /f /r.
)
echo.

echo - Verificando arquivos de sistema (sfc)...
sfc /scannow

echo.

:: ============================================
:: 3. RESTAURACAO DA IMAGEM DO WINDOWS (DISM)
:: ============================================
echo [3/10] Verificando e restaurando imagem do Windows...
echo ------------------------------------------------

dism /online /cleanup-image /checkhealth
dism /online /cleanup-image /scanhealth

echo.
echo - Executando RestoreHealth (limite de seguranca: 15 minutos)...
echo   Se travar sem avancar, o script cancela automaticamente e continua.
echo.

powershell -NoProfile -Command ^
    "$job = Start-Job -ScriptBlock { dism /online /cleanup-image /restorehealth }; ^
    if (Wait-Job $job -Timeout 900) { Receive-Job $job } ^
    else { Write-Host '[AVISO] RestoreHealth excedeu 15 minutos sem concluir - cancelando e seguindo em frente.' -ForegroundColor Yellow; Stop-Job $job; Remove-Job $job -Force; Get-Process dism -ErrorAction SilentlyContinue | Stop-Process -Force }"

echo.
echo Se o RestoreHealth foi cancelado por timeout, rode manualmente depois com:
echo   DISM /Online /Cleanup-Image /RestoreHealth
echo (idealmente com uma ISO do Windows como fonte, se sua internet/Windows Update estiver com problema)

echo.

:: ============================================
:: 4. LIMPEZA DE COMPONENTES ANTIGOS (WinSxS)
:: ============================================
echo [4/10] Analisando e limpando componentes antigos do Windows (WinSxS)...
echo ------------------------------------------------

echo - Analisando o repositorio de componentes...
dism /online /cleanup-image /AnalyzeComponentStore

echo.
echo - Removendo componentes antigos ja substituidos (mantem opcao de rollback dos updates mais recentes)...
dism /online /cleanup-image /StartComponentCleanup

echo.
set /p resetbase="Deseja tambem remover TODAS as versoes antigas de updates (/ResetBase)? Isso libera mais espaco, mas voce perde a opcao de desinstalar atualizacoes ja aplicadas. (S/N): "
if /i "%resetbase%"=="S" (
    echo Executando limpeza completa com ResetBase...
    dism /online /cleanup-image /StartComponentCleanup /ResetBase
) else (
    echo Pulando /ResetBase - mantendo opcao de rollback de updates recentes.
)
echo.

:: ============================================
:: 5. OTIMIZACAO DE DISCO (SSD/HDD AUTOMATICO)
:: ============================================
echo [5/10] Otimizando disco (detectando tipo automaticamente)...
echo ------------------------------------------------

powershell -NoProfile -Command "$disk = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq 0 }; if ($disk.MediaType -eq 'SSD') { Write-Host 'Disco SSD detectado - executando TRIM...'; Optimize-Volume -DriveLetter C -ReTrim -Verbose } else { Write-Host 'Disco HDD detectado - executando desfragmentacao...'; Optimize-Volume -DriveLetter C -Defrag -Verbose }"

echo.

:: ============================================
:: 6. LIMPEZA DE LOGS DE EVENTOS
:: ============================================
echo [6/10] Limpando logs de eventos do Windows...
echo ------------------------------------------------

powershell -NoProfile -Command "Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | ForEach-Object { wevtutil.exe clear-log $_.LogName 2>$null }"
echo Logs de eventos limpos.

echo.

:: ============================================
:: 7. LIMPEZA ADICIONAL (CLEANMGR + STORAGE SENSE)
:: ============================================
echo [7/10] Limpeza adicional do sistema...
echo ------------------------------------------------

echo - Configurando perfil completo do Limpeza de Disco (cleanmgr)...
for /f "tokens=1" %%K in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" 2^>nul ^| findstr /r "HKLM"') do (
    reg add "%%K" /v StateFlags0100 /t REG_DWORD /d 2 /f >nul 2>&1
)

echo - Executando Limpeza de Disco completa (isso pode levar alguns minutos)...
cleanmgr /sagerun:100

echo.
echo - Ativando Storage Sense (limpeza automatica recorrente do Windows)...
powershell -NoProfile -Command "New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' -Force | Out-Null; Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' -Name '01' -Value 1 -Type DWord -ErrorAction SilentlyContinue"
echo Storage Sense ativado - o Windows vai limpar arquivos temporarios automaticamente a partir de agora.

echo.

:: ============================================
:: 8. REDE (DNS, WINSOCK E TCP/IP)
:: ============================================
echo [8/10] Otimizando e resetando configuracoes de rede...
echo ------------------------------------------------

echo - Limpando cache DNS...
ipconfig /flushdns >nul 2>&1

echo - Liberando e renovando IP...
ipconfig /release >nul 2>&1
ipconfig /renew >nul 2>&1

echo.
set /p resetrede="Deseja resetar Winsock e TCP/IP tambem? Util se a internet estiver lenta/instavel. Requer REINICIAR o PC depois. (S/N): "
if /i "%resetrede%"=="S" (
    echo Resetando Winsock...
    netsh winsock reset >nul 2>&1
    echo Resetando TCP/IP...
    netsh int ip reset >nul 2>&1
    echo Reset de rede concluido - REINICIE o computador para aplicar.
) else (
    echo Pulando reset de Winsock/TCP-IP.
)

echo.

:: ============================================
:: 9. ATUALIZACAO DE PROGRAMAS (WINGET)
:: ============================================
echo [9/10] Atualizando todos os programas via winget...
echo ------------------------------------------------

where winget >nul 2>&1
if errorlevel 1 (
    echo [AVISO] Winget nao foi encontrado no PATH desta sessao elevada.
    echo Isso e comum quando o script eleva para administrador.
    echo Tentando localizar o executavel diretamente...
    for /f "delims=" %%W in ('powershell -NoProfile -Command "(Get-AppxPackage -Name Microsoft.DesktopAppInstaller).InstallLocation"') do set "wingetpath=%%W"
    if defined wingetpath (
        set "winget_exe=%wingetpath%\winget.exe"
    ) else (
        echo [ERRO] Nao foi possivel localizar o winget. Pulando atualizacao.
        goto pular_winget
    )
) else (
    set "winget_exe=winget"
)

echo Executando: %winget_exe% upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements
"%winget_exe%" upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements --disable-interactivity

:pular_winget
echo.

:: ============================================
:: 10. AJUSTES DE ENERGIA
:: ============================================
echo [10/10] Ajustando configuracoes de energia...
echo ------------------------------------------------

echo - Desativando hibernacao...
powercfg.exe /hibernate off

echo - Ativando plano de Desempenho Maximo...
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61

echo.
echo ================================================
echo   OTIMIZACAO CONCLUIDA COM SUCESSO!
echo   Recomenda-se reiniciar o computador.
echo ================================================
echo.
pause

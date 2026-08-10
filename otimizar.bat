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
echo [1/5] Limpando arquivos temporarios...
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

echo Limpeza concluida (arquivos em uso sao ignorados automaticamente).
echo.

:: ============================================
:: 2. VERIFICACAO DE DISCO E ARQUIVOS DE SISTEMA
:: ============================================
echo [2/5] Verificando disco e integridade do sistema...
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
echo [3/5] Verificando e restaurando imagem do Windows...
echo ------------------------------------------------

dism /online /cleanup-image /checkhealth
dism /online /cleanup-image /scanhealth
dism /online /cleanup-image /restorehealth

echo.

:: ============================================
:: 4. ATUALIZACAO DE PROGRAMAS (WINGET)
:: ============================================
echo [4/5] Atualizando todos os programas via winget...
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
:: 5. AJUSTES DE ENERGIA
:: ============================================
echo [5/5] Ajustando configuracoes de energia...
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
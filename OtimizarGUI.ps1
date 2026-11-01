<#
    Otimizar Windows - Interface Gráfica
    github.com/Seabratex

    Abre uma janela para escolher as etapas e as opções, e executa o otimizar.bat
    (na mesma pasta) em modo gráfico, mostrando a saída ao vivo.
    Salve este arquivo como UTF-8 com BOM para os acentos aparecerem certos.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------- administrador
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', ('"{0}"' -f $PSCommandPath))
    } catch {
        [System.Windows.Forms.MessageBox]::Show('Esta interface precisa de permissão de administrador.', 'Otimizar Windows', 'OK', 'Warning') | Out-Null
    }
    exit
}

# ---------------------------------------------------------------- nitidez em telas HiDPI
try {
    Add-Type -Namespace Seabra -Name Dpi -MemberDefinition '[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
    [void][Seabra.Dpi]::SetProcessDPIAware()
} catch { }
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------------------------------------------------------------- caminhos
$ScriptDir = Split-Path -Parent $PSCommandPath
$BatPath   = Join-Path $ScriptDir 'otimizar.bat'
$LogPath   = Join-Path $ScriptDir 'otimizar_log.txt'
if (-not (Test-Path -LiteralPath $BatPath)) {
    [System.Windows.Forms.MessageBox]::Show("Não encontrei o otimizar.bat em:`n$ScriptDir`n`nColoque os dois arquivos na mesma pasta.", 'Otimizar Windows', 'OK', 'Error') | Out-Null
    exit
}

# A saída do cmd usa a página de código OEM (ex.: 850), não UTF-8.
try {
    $oemCp = [int](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage' -Name OEMCP).OEMCP
    $OemEncoding = [System.Text.Encoding]::GetEncoding($oemCp)
} catch {
    $OemEncoding = [System.Text.Encoding]::GetEncoding(850)
}

# ---------------------------------------------------------------- tema azul-marinho e dourado
function Get-Color([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
$Navy      = Get-Color '#0A1A33'
$NavyLight = Get-Color '#12294D'
$NavyDeep  = Get-Color '#06101F'
$Gold      = Get-Color '#D4AF37'
$GoldDim   = Get-Color '#8F7727'
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
        $b.BackColor = $Gold; $b.ForeColor = $NavyDeep
        $b.FlatAppearance.BorderColor = $Gold
    } else {
        $b.BackColor = $NavyLight; $b.ForeColor = $TextLight
        $b.FlatAppearance.BorderColor = $GoldDim
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
$lblArt.ForeColor = $Gold
$lblArt.AutoSize  = $true
$lblArt.Location  = New-Object System.Drawing.Point(24, 16)
$header.Controls.Add($lblArt)

$lblTitle = New-Label 'Otimizar Windows' 372 14 560 44 (New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)) $Gold
$header.Controls.Add($lblTitle)
$lblSub = New-Label 'Manutenção e otimização para Windows 10 e 11' 375 62 560 22 $FontUi $TextMuted
$header.Controls.Add($lblSub)

$lnk = New-Object System.Windows.Forms.LinkLabel
$lnk.Text = 'github.com/Seabratex'
$lnk.Font = $FontUi
$lnk.LinkColor = $Gold
$lnk.ActiveLinkColor = $TextLight
$lnk.VisitedLinkColor = $Gold
$lnk.BackColor = [System.Drawing.Color]::Transparent
$lnk.LinkBehavior = 'HoverUnderline'
$lnk.Location = New-Object System.Drawing.Point(375, 84)
$lnk.Size = New-Object System.Drawing.Size(300, 22)
$lnk.Add_LinkClicked({ Start-Process 'https://github.com/Seabratex' })
$header.Controls.Add($lnk)

# ---- etapas
$form.Controls.Add((New-Label 'ETAPAS' 24 126 300 22 $FontHead $Gold))
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
$form.Controls.Add((New-Label 'OPÇÕES  (as perguntas que o script faria)' 516 126 460 22 $FontHead $Gold))
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
$form.Controls.Add((New-Label 'SAÍDA' 24 474 300 22 $FontHead $Gold))
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
$barFill.BackColor = $Gold
$barBg.Controls.Add($barFill)

$lblStatus = New-Label 'Pronto. Escolha as etapas e clique em Executar.' 24 708 320 24 $FontUi $TextMuted
$form.Controls.Add($lblStatus)

# ---- botões
$btnAll    = New-Button 'Selecionar tudo' 346 700 140 36 $false
$btnRun    = New-Button 'Executar'        496 700 150 36 $true
$btnCancel = New-Button 'Cancelar'        656 700 100 36 $false
$btnLog    = New-Button 'Abrir log'       766 700 110 36 $false
$btnExit   = New-Button 'Sair'            886 700 90  36 $false
$btnCancel.Enabled = $false
foreach ($b in @($btnAll, $btnRun, $btnCancel, $btnLog, $btnExit)) { $form.Controls.Add($b) }

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
    $btnAll.Enabled    = -not $on
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
        Add-Log $t $Gold $true
    }
    elseif ($t -match '^\s*\[ERRO\]')  { Add-Log $t $Red }
    elseif ($t -match '^\s*\[AVISO\]') { Add-Log $t $Amber }
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
        Add-Log 'Concluído. Recomenda-se reiniciar o computador.' $Green $true
        $lblStatus.Text = 'Concluído. Recomenda-se reiniciar o computador.'
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
$btnAll.Add_Click({
    $allOn = $true
    foreach ($c in $stepChecks) { if (-not $c.Checked) { $allOn = $false } }
    foreach ($c in $stepChecks) { $c.Checked = (-not $allOn) }
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

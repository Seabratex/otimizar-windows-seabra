using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;

namespace OtimizarWindows;

public sealed class MainForm : Form
{
    private static readonly Color Navy = ColorTranslator.FromHtml("#0A1A33");
    private static readonly Color NavyLight = ColorTranslator.FromHtml("#12294D");
    private static readonly Color NavyDeep = ColorTranslator.FromHtml("#06101F");
    private static readonly Color Silver = ColorTranslator.FromHtml("#D3DCEA");
    private static readonly Color SilverDim = ColorTranslator.FromHtml("#7F8CA3");
    private static readonly Color TextLight = ColorTranslator.FromHtml("#EDEFF3");
    private static readonly Color TextMuted = ColorTranslator.FromHtml("#9AA8BF");
    private static readonly Color Green = ColorTranslator.FromHtml("#6FD99A");
    private static readonly Color Amber = ColorTranslator.FromHtml("#F2C14E");
    private static readonly Color Red = ColorTranslator.FromHtml("#FF7B7B");

    private readonly CheckBox[] stepChecks = new CheckBox[10];
    private readonly Dictionary<string, CheckBox> optionChecks = new();
    private readonly RichTextBox output = new();
    private readonly Panel progressFill = new();
    private readonly Label status = new();
    private readonly Button runButton;
    private readonly Button cancelButton;
    private readonly Button logButton;
    private bool running;

    private static readonly (string Title, string Tip)[] Steps =
    {
        ("Limpeza de temporários", "Temp, Recent, cache do Windows Update, miniaturas, ícones e relatórios de erro."),
        ("Verificação de disco e sistema", "chkdsk /scan e sfc /scannow."),
        ("Diagnóstico da imagem do Windows", "DISM CheckHealth e ScanHealth (só diagnóstico)."),
        ("Limpeza de componentes antigos", "Limpeza do WinSxS via DISM."),
        ("Otimização de disco", "TRIM em SSD ou desfragmentação em HDD."),
        ("Logs de eventos do Windows", "Limpa o Visualizador de Eventos, se a opção estiver marcada."),
        ("Limpeza adicional", "Limpeza de Disco do Windows e Storage Sense."),
        ("Rede", "Limpa DNS e renova IP. Resets opcionais na lista de opções."),
        ("Atualização de programas", "winget upgrade --all."),
        ("Ajustes de energia", "Só age se a opção de energia estiver marcada.")
    };

    private static readonly (string Key, int Step, string Text, string Tip)[] Options =
    {
        ("limparpref", 1, "Limpar a pasta Prefetch (geralmente desnecessário)", "O Windows recria a pasta; apps podem abrir um pouco mais lentos na primeira vez."),
        ("rodarchk", 2, "Agendar verificação completa do disco (chkdsk /f /r). Exige reiniciar", "A verificação roda na próxima inicialização e pode demorar bastante."),
        ("resetbase", 4, "Remover TODAS as versões antigas de updates (/ResetBase). Sem volta", "Libera espaço, mas remove a opção de desinstalar atualizações aplicadas."),
        ("limparlogs", 6, "Limpar os logs do Visualizador de Eventos. Apaga histórico de diagnóstico", "Os logs ajudam a descobrir a causa de erros e travamentos."),
        ("resetrede", 8, "Resetar Winsock, proxy e TCP/IP. Exige reiniciar", "Útil quando a internet está instável ou lenta."),
        ("alterarenergia", 10, "Desativar hibernação e ativar Desempenho Máximo. Evite em notebook na bateria", "Mantém o PC em alto desempenho, com maior consumo de energia.")
    };

    public MainForm()
    {
        Text = "Otimizar Windows - Seabra";
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        BackColor = Navy;
        ForeColor = TextLight;
        Font = new Font("Segoe UI", 9.5f);
        ClientSize = new Size(1000, 750);
        AutoScaleMode = AutoScaleMode.Dpi;

        BuildHeader();
        BuildSteps();
        BuildOptions();
        BuildOutput();

        var progressBackground = new Panel
        {
            Location = new Point(24, 662), Size = new Size(952, 12),
            BackColor = NavyLight
        };
        progressFill.BackColor = Silver;
        progressFill.Location = Point.Empty;
        progressFill.Size = new Size(0, 12);
        progressBackground.Controls.Add(progressFill);
        Controls.Add(progressBackground);

        status.Text = "Interface migrada. As rotinas estão sendo integradas em C#.";
        status.Location = new Point(24, 708);
        status.Size = new Size(460, 24);
        status.ForeColor = TextMuted;
        Controls.Add(status);

        runButton = CreateButton("Executar", 496, 700, 150, 36, true);
        cancelButton = CreateButton("Cancelar", 656, 700, 100, 36, false);
        logButton = CreateButton("Abrir log", 766, 700, 110, 36, false);
        var exitButton = CreateButton("Sair", 886, 700, 90, 36, false);

        // O botão será habilitado quando o executor C# das etapas estiver integrado.
        runButton.Enabled = false;
        cancelButton.Enabled = false;
        logButton.Click += (_, _) => OpenLog();
        exitButton.Click += (_, _) => Close();
        Controls.AddRange(new Control[] { runButton, cancelButton, logButton, exitButton });

        AddOutput("Base visual em C# criada.", Silver, true);
        AddOutput("Próxima etapa: migrar as rotinas de manutenção sem chamar o BAT ou extrair scripts.", TextMuted);
    }

    private void BuildHeader()
    {
        var header = new Panel { Location = new Point(0, 0), Size = new Size(1000, 112), BackColor = NavyDeep };
        var art = new Label
        {
            Text = "                 _\n  ___  ___  __ _| |__  _ __ __ _\n / __|/ _ \\/ _` | '_ \\| '__/ _` |\n \\__ \\  __/ (_| | |_) | | | (_| |\n |___/\\___|\\__,_|_.__/|_|  \\__,_|",
            Font = new Font("Consolas", 10), ForeColor = Silver, AutoSize = true,
            Location = new Point(24, 16)
        };
        header.Controls.Add(art);
        header.Controls.Add(CreateLabel("Otimizar Windows", 372, 14, 560, 44,
            new Font("Segoe UI", 22, FontStyle.Bold), Silver));
        header.Controls.Add(CreateLabel("Manutenção e otimização para Windows 10 e 11", 375, 62, 560, 22,
            Font, TextMuted));

        var link = new LinkLabel
        {
            Text = "github.com/Seabratex", Location = new Point(375, 84),
            Size = new Size(300, 22), Font = Font, LinkColor = Silver,
            ActiveLinkColor = TextLight, VisitedLinkColor = Silver,
            BackColor = Color.Transparent, LinkBehavior = LinkBehavior.HoverUnderline
        };
        link.LinkClicked += (_, _) => Process.Start(new ProcessStartInfo("https://github.com/Seabratex") { UseShellExecute = true });
        header.Controls.Add(link);
        Controls.Add(header);
    }

    private void BuildSteps()
    {
        Controls.Add(CreateLabel("ETAPAS", 24, 126, 300, 22, new Font("Segoe UI", 10, FontStyle.Bold), Silver));
        var panel = new Panel { Location = new Point(24, 152), Size = new Size(460, 312), BackColor = NavyLight };
        for (var i = 0; i < Steps.Length; i++)
        {
            var number = i + 1;
            var check = new CheckBox
            {
                Text = $"{number}.   {Steps[i].Title}", Tag = number, Checked = true,
                AutoSize = false, Location = new Point(16, 10 + i * 30),
                Size = new Size(430, 26), ForeColor = TextLight,
                BackColor = Color.Transparent, Cursor = Cursors.Hand
            };
            new ToolTip().SetToolTip(check, Steps[i].Tip);
            stepChecks[i] = check;
            panel.Controls.Add(check);
        }
        Controls.Add(panel);
    }

    private void BuildOptions()
    {
        Controls.Add(CreateLabel("OPÇÕES  (as perguntas que o script faria)", 516, 126, 460, 22,
            new Font("Segoe UI", 10, FontStyle.Bold), Silver));
        var panel = new Panel { Location = new Point(516, 152), Size = new Size(460, 312), BackColor = NavyLight };
        for (var i = 0; i < Options.Length; i++)
        {
            var option = Options[i];
            var check = new CheckBox
            {
                Text = option.Text, Tag = option.Key, Checked = false,
                AutoSize = false, Location = new Point(16, 12 + i * 49),
                Size = new Size(430, 44), ForeColor = TextLight,
                BackColor = Color.Transparent, Cursor = Cursors.Hand
            };
            new ToolTip().SetToolTip(check, option.Tip);
            optionChecks.Add(option.Key, check);
            panel.Controls.Add(check);
        }
        Controls.Add(panel);
    }

    private void BuildOutput()
    {
        Controls.Add(CreateLabel("SAÍDA", 24, 474, 300, 22, new Font("Segoe UI", 10, FontStyle.Bold), Silver));
        output.Location = new Point(24, 498);
        output.Size = new Size(952, 152);
        output.BackColor = NavyDeep;
        output.ForeColor = TextLight;
        output.Font = new Font("Consolas", 9);
        output.BorderStyle = BorderStyle.None;
        output.ReadOnly = true;
        output.DetectUrls = false;
        output.WordWrap = true;
        output.ScrollBars = RichTextBoxScrollBars.Vertical;
        Controls.Add(output);
    }

    private static Label CreateLabel(string text, int x, int y, int width, int height, Font font, Color color) =>
        new()
        {
            Text = text, Location = new Point(x, y), Size = new Size(width, height),
            Font = font, ForeColor = color, BackColor = Color.Transparent
        };

    private static Button CreateButton(string text, int x, int y, int width, int height, bool primary)
    {
        var button = new Button
        {
            Text = text, Location = new Point(x, y), Size = new Size(width, height),
            FlatStyle = FlatStyle.Flat, Cursor = Cursors.Hand,
            Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
            BackColor = primary ? Silver : NavyLight,
            ForeColor = primary ? NavyDeep : TextLight
        };
        button.FlatAppearance.BorderSize = 1;
        button.FlatAppearance.BorderColor = primary ? Silver : SilverDim;
        return button;
    }

    private void AddOutput(string text, Color? color = null, bool bold = false)
    {
        output.SelectionStart = output.TextLength;
        output.SelectionLength = 0;
        output.SelectionColor = color ?? TextLight;
        output.SelectionFont = new Font("Consolas", 9, bold ? FontStyle.Bold : FontStyle.Regular);
        output.AppendText(text + Environment.NewLine);
        output.SelectionStart = output.TextLength;
        output.ScrollToCaret();
    }

    private void OpenLog()
    {
        var logPath = Path.Combine(AppContext.BaseDirectory, "OtimizarWindows_log.txt");
        if (!File.Exists(logPath))
        {
            MessageBox.Show("Nenhum log encontrado ainda. Rode a otimização primeiro.",
                "Otimizar Windows", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }
        Process.Start(new ProcessStartInfo("notepad.exe", $"\"{logPath}\"") { UseShellExecute = true });
    }
}

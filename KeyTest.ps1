Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$wfPath  = [System.Windows.Forms.Form].Assembly.Location
$drwPath = [System.Drawing.Color].Assembly.Location

Add-Type -TypeDefinition @"
using System.Windows.Forms;
public class KTestForm : Form {
    public void FireKeyDown(Keys k) { OnKeyDown(new KeyEventArgs(k)); }
}
public class KTestFilter : IMessageFilter {
    private KTestForm _form;
    public static int HitCount = 0;
    public KTestFilter(KTestForm f) { _form = f; }
    public bool PreFilterMessage(ref Message m) {
        if (m.Msg == 0x0100) {
            HitCount++;
            Keys k = (Keys)(int)m.WParam & Keys.KeyCode;
            _form.FireKeyDown(k);
            return true;
        }
        return false;
    }
}
"@ -ReferencedAssemblies $wfPath, $drwPath

$form = [KTestForm]::new()
$form.Text       = "Key Test"
$form.ClientSize = [System.Drawing.Size]::new(320, 120)

$lbl            = [System.Windows.Forms.Label]::new()
$lbl.Text       = "Press any key..."
$lbl.AutoSize   = $false
$lbl.Size       = [System.Drawing.Size]::new(300, 80)
$lbl.Location   = [System.Drawing.Point]::new(10, 20)
$lbl.Font       = [System.Drawing.Font]::new("Segoe UI", 14)
$form.Controls.Add($lbl)

$filter = [KTestFilter]::new($form)
[System.Windows.Forms.Application]::AddMessageFilter($filter)

$form.Add_KeyDown({
    param($s, $e)
    $lbl.Text = "KeyDown fired!`nKeyCode = $($e.KeyCode)`nFilter hits = $([KTestFilter]::HitCount)"
})

# Also a timer to show filter hit count even if KeyDown doesn't fire
$t          = [System.Windows.Forms.Timer]::new()
$t.Interval = 200
$t.Add_Tick({ $form.Text = "Key Test  [filter hits: $([KTestFilter]::HitCount)]" })
$t.Start()

[System.Windows.Forms.Application]::Run($form)

# ================================================================
#   NARDTECH - Script di installazione automatica software
#   Autore: Fabio Narducci | nardtech.altervista.org
#   TikTok: @nardtech88
# ================================================================
#   Uso: eseguire come amministratore (o tramite avvia-installazione.cmd)
# ================================================================

# ---- Auto-elevazione UAC ----
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Richiesta elevazione privilegi amministratore..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$ErrorActionPreference = "Continue"

# ---- Setup log ----
$logDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = Join-Path $logDir "installazione_$timestamp.log"

function Write-Log {
    param([string]$msg)
    Add-Content -Path $logFile -Value "$(Get-Date -Format 'HH:mm:ss') - $msg"
}

function Show-Banner {
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "   _   _   _    ____  ____ _____ _____ ____ _   _             " -ForegroundColor Cyan
    Write-Host "  | \ | | / \  |  _ \|  _ \_   _| ____/ ___| | | |            " -ForegroundColor Cyan
    Write-Host "  |  \| |/ _ \ | |_) | | | || | |  _|| |   | |_| |            " -ForegroundColor Cyan
    Write-Host "  | |\  / ___ \|  _ <| |_| || | | |__| |___|  _  |            " -ForegroundColor Cyan
    Write-Host "  |_| \_/_/   \_\_| \_\____/ |_| |_____\____|_| |_|           " -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   Script di installazione automatica software" -ForegroundColor White
    Write-Host "   by Fabio Narducci - nardtech.altervista.org" -ForegroundColor DarkCyan
    Write-Host "   TikTok: @nardtech88" -ForegroundColor DarkCyan
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host ""
}

Show-Banner
Write-Log "=== NARDTECH install-software.ps1 avviato ==="

# ---- Tabella spiegazione errori winget piu' comuni (solo per errori VERI, non per "gia' installato") ----
$errorExplanations = @{
    "-1978335189" = "Hash del pacchetto non corrisponde al manifest winget (l'installer e' cambiato piu' di recente rispetto al catalogo winget). Di solito non e' un problema reale: uso --force per bypassare."
    "-1978335215" = "Nessun pacchetto trovato con questo ID: l'ID winget potrebbe essere cambiato o il pacchetto essere stato rimosso dal catalogo."
    "1603"        = "Errore generico del installer MSI. Spesso causato da un'installazione precedente incompleta o da permessi insufficienti."
    "1618"        = "Un'altra installazione e' gia' in corso: attendere e riprovare."
    "3010"        = "Installazione completata, ma serve un riavvio del PC per finalizzare."
}
function Explain-ErrorCode {
    param([string]$code)
    if ($errorExplanations.ContainsKey($code)) { return $errorExplanations[$code] }
    return "Codice non catalogato. Consultare il log completo o cercare 'winget exit code $code' per maggiori dettagli."
}

# ---- Verifica se un pacchetto winget e' gia' installato (controllo reale, non basato su codici di errore) ----
function Test-WingetInstalled {
    param([string]$id)
    $null = & winget list --id $id --exact --accept-source-agreements 2>&1
    return ($LASTEXITCODE -eq 0)
}

# ---- Verifica connessione Internet ----
Write-Host "[1/5] Verifica connessione Internet..." -ForegroundColor Yellow
Write-Log "Verifica connessione Internet"
if (-not (Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet)) {
    Write-Host "[ERRORE] Nessuna connessione Internet rilevata. Impossibile procedere." -ForegroundColor Red
    Write-Host "         Motivo: lo script deve scaricare gli installer dei programmi da Internet." -ForegroundColor Red
    Write-Log "ERRORE - Nessuna connessione Internet"
    Read-Host "Premi INVIO per uscire"
    exit 1
}
Write-Host "[OK] Connessione Internet disponibile." -ForegroundColor Green
Write-Log "OK - Connessione Internet disponibile"
Write-Host ""

# ---- Verifica winget ----
Write-Host "[2/5] Verifica disponibilita' di winget..." -ForegroundColor Yellow
Write-Log "Verifica winget"
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "[ERRORE] winget non trovato sul sistema." -ForegroundColor Red
    Write-Host "         Motivo: manca 'App Installer'. Scaricalo da: https://aka.ms/getwinget" -ForegroundColor Red
    Write-Log "ERRORE - winget non disponibile"
    Read-Host "Premi INVIO per uscire"
    exit 1
}
Write-Host "[OK] winget disponibile." -ForegroundColor Green
Write-Log "OK - winget disponibile"
Write-Host ""

# ================================================================
#   Catalogo software (Id univoco = Nome, Categoria, Tipo, Essenziale)
#   Tipo: Winget | Office | RustDesk
# ================================================================
$catalogo = [ordered]@{
    "OFFICE365" = @{ Nome = "Microsoft 365 (Office)";        Categoria = "Consigliati";      Tipo = "Office";    Essenziale = $false }
    "CHROME"    = @{ Nome = "Google Chrome";                 Categoria = "Essenziali";        Tipo = "Winget";    Id = "Google.Chrome";                       Essenziale = $true }
    "7ZIP"      = @{ Nome = "7-Zip";                         Categoria = "Essenziali";        Tipo = "Winget";    Id = "7zip.7zip";                           Essenziale = $true }
    "VLC"       = @{ Nome = "VLC Media Player";               Categoria = "Essenziali";        Tipo = "Winget";    Id = "VideoLAN.VLC";                        Essenziale = $true }
    "DOTNET8"   = @{ Nome = ".NET Desktop Runtime 8";         Categoria = "Essenziali";        Tipo = "Winget";    Id = "Microsoft.DotNet.DesktopRuntime.8";   Essenziale = $true }
    "VCREDIST"  = @{ Nome = "Visual C++ Redistributable x64"; Categoria = "Essenziali";        Tipo = "Winget";    Id = "Microsoft.VCRedist.2015+.x64";        Essenziale = $true }

    "TEAMS"     = @{ Nome = "Microsoft Teams";                Categoria = "Consigliati";       Tipo = "Winget";    Id = "Microsoft.Teams";                     Essenziale = $false }
    "PDFGEAR"   = @{ Nome = "PDFgear (editor PDF gratuito)";  Categoria = "Consigliati";       Tipo = "Winget";    Id = "PDFgear.PDFgear";                     Essenziale = $false }
    "WHATSAPP"  = @{ Nome = "WhatsApp Desktop";               Categoria = "Consigliati";       Tipo = "Winget";    Id = "9NKSQGP7F2NH";                         Essenziale = $false }
    "RUSTDESK"  = @{ Nome = "RustDesk (assistenza remota)";   Categoria = "Consigliati";       Tipo = "RustDesk";  Essenziale = $false }

    "IPSCAN"    = @{ Nome = "Advanced IP Scanner";            Categoria = "Diagnostica IT";    Tipo = "Winget";    Id = "Famatech.AdvancedIPScanner";          Essenziale = $false }
    "SYSINT"    = @{ Nome = "Sysinternals Suite";             Categoria = "Diagnostica IT";    Tipo = "Winget";    Id = "Microsoft.Sysinternals.Suite";        Essenziale = $false }
    "CRYSTALDI" = @{ Nome = "CrystalDiskInfo (salute dischi)"; Categoria = "Diagnostica IT";   Tipo = "Winget";    Id = "CrystalDewWorld.CrystalDiskInfo";     Essenziale = $false }
    "MALWARE"   = @{ Nome = "Malwarebytes (scansione malware)"; Categoria = "Diagnostica IT"; Tipo = "Winget";    Id = "Malwarebytes.Malwarebytes";           Essenziale = $false }
    "CPUZ"      = @{ Nome = "CPU-Z (info hardware)";          Categoria = "Diagnostica IT";    Tipo = "Winget";    Id = "CPUID.CPU-Z.CM";                      Essenziale = $false }
    "EVERYTHING"= @{ Nome = "Everything (ricerca file rapida)"; Categoria = "Diagnostica IT"; Tipo = "Winget";    Id = "voidtools.Everything";                Essenziale = $false }
    "HWINFO"    = @{ Nome = "HWiNFO (monitoraggio hardware)"; Categoria = "Diagnostica IT";    Tipo = "Winget";    Id = "REALiX.HWiNFO";                       Essenziale = $false }

    "WINRAR"    = @{ Nome = "WinRAR";                         Categoria = "Opzionali";         Tipo = "Winget";    Id = "RARLab.WinRAR";                       Essenziale = $false }
    "ADOBE"     = @{ Nome = "Adobe Acrobat Reader";           Categoria = "Opzionali";         Tipo = "Winget";    Id = "Adobe.Acrobat.Reader.64-bit";         Essenziale = $false }
    "NPP"       = @{ Nome = "Notepad++";                      Categoria = "Opzionali";         Tipo = "Winget";    Id = "Notepad++.Notepad++";                 Essenziale = $false }
    "FIREFOX"   = @{ Nome = "Mozilla Firefox";                Categoria = "Opzionali";         Tipo = "Winget";    Id = "Mozilla.Firefox";                     Essenziale = $false }
}

# ================================================================
#   [3/5] Menu di scelta
# ================================================================
Write-Host "[3/5] Cosa vuoi installare?" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1) Tutto" -ForegroundColor White
Write-Host "  2) Solo i programmi essenziali" -ForegroundColor White
Write-Host "  3) Scelgo io i programmi" -ForegroundColor White
Write-Host ""
$scelta = Read-Host "Digita 1, 2 o 3"

$daInstallare = @()

switch ($scelta) {
    "2" {
        $daInstallare = $catalogo.Keys | Where-Object { $catalogo[$_].Essenziale }
    }
    "3" {
        Write-Host ""
        Write-Host "Elenco programmi disponibili:" -ForegroundColor Cyan
        $indice = @{}
        $n = 1
        $categorieOrdine = @("Essenziali", "Consigliati", "Diagnostica IT", "Opzionali")
        foreach ($cat in $categorieOrdine) {
            Write-Host ""
            Write-Host "-- $cat --" -ForegroundColor DarkCyan
            foreach ($key in $catalogo.Keys | Where-Object { $catalogo[$_].Categoria -eq $cat }) {
                Write-Host ("  {0,2}) {1}" -f $n, $catalogo[$key].Nome)
                $indice[$n] = $key
                $n++
            }
        }
        Write-Host ""
        $sel = Read-Host "Digita i numeri separati da virgola (es: 1,2,5,9)"
        $numeri = $sel -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
        foreach ($num in $numeri) {
            if ($indice.ContainsKey($num)) { $daInstallare += $indice[$num] }
        }
        if ($daInstallare.Count -eq 0) {
            Write-Host "[ATTENZIONE] Nessun programma valido selezionato, installo solo gli essenziali." -ForegroundColor Red
            $daInstallare = $catalogo.Keys | Where-Object { $catalogo[$_].Essenziale }
        }
    }
    default {
        $daInstallare = $catalogo.Keys
    }
}

Write-Log "Modalita' scelta: $scelta - Pacchetti selezionati: $($daInstallare -join ', ')"
Write-Host ""
Write-Host "[OK] Verranno installati $($daInstallare.Count) programmi." -ForegroundColor Green
Write-Host ""

# ---- Controlli "gia' installato" per Office e RustDesk (non passano da winget) ----
function Test-OfficeInstalled {
    return (Test-Path "$env:ProgramFiles\Microsoft Office\root\Office16\WINWORD.EXE") -or
           (Test-Path "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\WINWORD.EXE")
}

function Test-RustDeskInstalled {
    return (Test-Path "$env:ProgramFiles\RustDesk\rustdesk.exe") -or
           (Test-Path "${env:ProgramFiles(x86)}\RustDesk\rustdesk.exe")
}

# ---- Installazione Office 365 tramite ODT ----
function Install-Office {
    if (Test-OfficeInstalled) {
        Write-Host "[SALTATO] Microsoft 365 (Office) e' gia' installato, nessuna azione necessaria." -ForegroundColor DarkYellow
        Write-Log "GIA' INSTALLATO - Microsoft 365 (Office)"
        Write-Host ""
        return [PSCustomObject]@{ Software = "Microsoft 365 (Office)"; Esito = "GIA' INSTALLATO"; Dettaglio = "Nessuna azione necessaria" }
    }
    Write-Host "  Cosa sta facendo: scarica l'ODT ufficiale Microsoft, genera una configurazione" -ForegroundColor DarkGray
    Write-Host "  silenziosa (64 bit, italiano, canale Current) e installa senza prompt aggiuntivi." -ForegroundColor DarkGray
    Write-Host "  Operazione silenziosa in corso, puo' richiedere diversi minuti - attendere..." -ForegroundColor DarkGray
    Write-Log "INIZIO installazione - Microsoft 365 (Office) via ODT"
    try {
        $odtUrl = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=49117"
        $page = Invoke-WebRequest -Uri $odtUrl -UseBasicParsing
        $downloadLink = ($page.Links | Where-Object { $_.href -match "officedeploymenttool.*\.exe$" } | Select-Object -First 1).href
        if (-not $downloadLink) { throw "Impossibile trovare il link di download dell'ODT sulla pagina Microsoft." }

        $odtDir = Join-Path $env:TEMP "NARDTECH_ODT"
        New-Item -ItemType Directory -Path $odtDir -Force | Out-Null
        $odtExe = Join-Path $odtDir "odtsetup.exe"
        Invoke-WebRequest -Uri $downloadLink -OutFile $odtExe -UseBasicParsing

        Start-Process -FilePath $odtExe -ArgumentList "/quiet /extract:$odtDir" -Wait

        $configXml = @"
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="it-it" />
    </Product>
  </Add>
  <Display Level="None" AcceptEULA="TRUE" />
  <Property Name="AUTOACTIVATE" Value="1" />
</Configuration>
"@
        $configPath = Join-Path $odtDir "config.xml"
        Set-Content -Path $configPath -Value $configXml -Encoding UTF8

        $setupExe = Join-Path $odtDir "setup.exe"
        Start-Process -FilePath $setupExe -ArgumentList "/configure `"$configPath`"" -Wait

        Write-Host "[FINE - OK] Microsoft 365 (Office) installato." -ForegroundColor Green
        Write-Log "FINE OK - Microsoft 365 (Office)"
        return [PSCustomObject]@{ Software = "Microsoft 365 (Office)"; Esito = "OK"; Dettaglio = "Installazione completata" }
    }
    catch {
        $msg = $_.Exception.Message
        Write-Host "[FINE - ATTENZIONE] Installazione Office fallita." -ForegroundColor Red
        Write-Host "                     Motivo: $msg" -ForegroundColor Red
        Write-Log "FINE ERRORE - Microsoft 365 (Office) - $msg"
        return [PSCustomObject]@{ Software = "Microsoft 365 (Office)"; Esito = "ERRORE"; Dettaglio = $msg }
    }
    finally { Write-Host "" }
}

# ---- Installazione RustDesk (non disponibile su winget: MSI ufficiale scaricato da GitHub) ----
function Install-RustDesk {
    if (Test-RustDeskInstalled) {
        Write-Host "[SALTATO] RustDesk e' gia' installato, nessuna azione necessaria." -ForegroundColor DarkYellow
        Write-Log "GIA' INSTALLATO - RustDesk"
        Write-Host ""
        return [PSCustomObject]@{ Software = "RustDesk"; Esito = "GIA' INSTALLATO"; Dettaglio = "Nessuna azione necessaria" }
    }
    Write-Host "  Cosa sta facendo: RustDesk non e' disponibile tramite winget (rimosso per un falso" -ForegroundColor DarkGray
    Write-Host "  positivo antivirus sull'installer EXE), quindi scarico il pacchetto MSI ufficiale" -ForegroundColor DarkGray
    Write-Host "  dall'ultima release su GitHub e lo installo in modo silenzioso con msiexec." -ForegroundColor DarkGray
    Write-Host "  Operazione silenziosa in corso, attendere (timeout di sicurezza: 5 minuti)..." -ForegroundColor DarkGray
    Write-Log "INIZIO installazione - RustDesk da GitHub (MSI)"
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/rustdesk/rustdesk/releases/latest" -UseBasicParsing
        $asset = $release.assets | Where-Object { $_.name -match "^rustdesk-.*-x86_64\.msi$" } | Select-Object -First 1
        if (-not $asset) { throw "Impossibile trovare l'installer MSI x86_64 nella release piu' recente di RustDesk." }

        $rdDir = Join-Path $env:TEMP "NARDTECH_RustDesk"
        New-Item -ItemType Directory -Path $rdDir -Force | Out-Null
        $rdMsi = Join-Path $rdDir $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $rdMsi -UseBasicParsing

        $rdLog = Join-Path $rdDir "install.log"
        $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$rdMsi`" /qn /norestart /l*v `"$rdLog`"" -PassThru
        $finito = $proc.WaitForExit(300000)  # timeout di sicurezza: 5 minuti

        if (-not $finito) {
            Write-Host "   [ATTENZIONE] Timeout raggiunto, interrompo il processo di installazione." -ForegroundColor Red
            try { $proc.Kill() } catch {}
            Write-Log "ATTENZIONE - RustDesk - timeout msiexec, processo interrotto"
        }

        # Verifica reale sul disco, indipendentemente dal codice di uscita di msiexec
        Start-Sleep -Seconds 2
        if (Test-RustDeskInstalled) {
            Write-Host "[FINE - OK] RustDesk installato." -ForegroundColor Green
            Write-Log "FINE OK - RustDesk"
            return [PSCustomObject]@{ Software = "RustDesk"; Esito = "OK"; Dettaglio = "Installazione completata" }
        } else {
            $codice = if ($finito) { $proc.ExitCode } else { "timeout" }
            Write-Host "[FINE - ATTENZIONE] RustDesk non risulta installato (codice msiexec: $codice)." -ForegroundColor Red
            Write-Host "                     Log dettagliato: $rdLog" -ForegroundColor Red
            Write-Log "FINE ERRORE - RustDesk - codice $codice - vedi $rdLog"
            return [PSCustomObject]@{ Software = "RustDesk"; Esito = "ERRORE"; Dettaglio = "Codice msiexec: $codice - vedi $rdLog" }
        }
    }
    catch {
        $msg = $_.Exception.Message
        Write-Host "[FINE - ATTENZIONE] Installazione RustDesk fallita." -ForegroundColor Red
        Write-Host "                     Motivo: $msg" -ForegroundColor Red
        Write-Log "FINE ERRORE - RustDesk - $msg"
        return [PSCustomObject]@{ Software = "RustDesk"; Esito = "ERRORE"; Dettaglio = $msg }
    }
    finally { Write-Host "" }
}

# ================================================================
#   [4/5] Installazione
# ================================================================
Write-Host "[4/5] Avvio installazione ($($daInstallare.Count) programmi)..." -ForegroundColor Yellow
Write-Host ""

$results = @()
$i = 0
foreach ($key in $daInstallare) {
    $i++
    $voce = $catalogo[$key]
    Write-Host "-> ($i/$($daInstallare.Count)) INIZIO: $($voce.Nome)" -ForegroundColor Cyan
    Write-Log "INIZIO - $($voce.Nome)"

    switch ($voce.Tipo) {
        "Office"    { $results += Install-Office; continue }
        "RustDesk"  { $results += Install-RustDesk; continue }
        "Winget" {
            if (Test-WingetInstalled -id $voce.Id) {
                Write-Host "   [SALTATO] $($voce.Nome) e' gia' installato, nessuna azione necessaria." -ForegroundColor DarkYellow
                Write-Log "FINE GIA' INSTALLATO - $($voce.Nome)"
                $results += [PSCustomObject]@{ Software = $voce.Nome; Esito = "GIA' INSTALLATO"; Dettaglio = "Nessuna azione necessaria" }
                Write-Host ""
                continue
            }

            Write-Host "   Installazione silenziosa in corso..." -ForegroundColor DarkGray
            $proc = Start-Process -FilePath "winget" -ArgumentList "install --id $($voce.Id) --silent --accept-package-agreements --accept-source-agreements --force" -Wait -PassThru -NoNewWindow
            $exitCode = $proc.ExitCode

            if ($exitCode -eq 0) {
                Write-Host "   [FINE - OK] $($voce.Nome) installato correttamente." -ForegroundColor Green
                Write-Log "FINE OK - $($voce.Nome)"
                $results += [PSCustomObject]@{ Software = $voce.Nome; Esito = "OK"; Dettaglio = "Installazione completata" }
            } else {
                $spiegazione = Explain-ErrorCode -code "$exitCode"
                Write-Host "   [FINE - ATTENZIONE] $($voce.Nome) - codice errore: $exitCode" -ForegroundColor Red
                Write-Host "                        Motivo probabile: $spiegazione" -ForegroundColor Red
                Write-Log "FINE ERRORE - $($voce.Nome) - codice $exitCode - $spiegazione"
                $results += [PSCustomObject]@{ Software = $voce.Nome; Esito = "ERRORE ($exitCode)"; Dettaglio = $spiegazione }
            }
        }
    }
    Write-Host ""
}

# ================================================================
#   [5/5] Riepilogo finale
# ================================================================
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "   [5/5] Installazione completata - Riepilogo" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""
$results | Format-Table -AutoSize -Wrap
Write-Host ""
Write-Host "Log completo salvato in: $logFile" -ForegroundColor DarkGray
Write-Host ""
Write-Host "---------------------------------------------------------------" -ForegroundColor DarkCyan
Write-Host " Script fornito da NARDTECH | nardtech.altervista.org | @nardtech88" -ForegroundColor DarkCyan
Write-Host "---------------------------------------------------------------" -ForegroundColor DarkCyan

Write-Log "=== Script completato ==="
Write-Log "Firma: NARDTECH - nardtech.altervista.org"

Read-Host "Premi INVIO per uscire"

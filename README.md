# NARDTECH - Installazione automatica software

Script by **Fabio Narducci** — [nardtech.altervista.org](https://nardtech.altervista.org) — TikTok [@nardtech88](https://www.tiktok.com/@nardtech88)

## Come si usa
Doppio click su `NARDTECH Deploy Kit.cmd`. Lo script:
1. Si auto-eleva a privilegi Amministratore (comparirà il prompt UAC di Windows — unico click richiesto, non evitabile via script).
2. Mostra il banner NARDTECH.
3. Verifica connessione Internet e disponibilità di `winget`.
4. **Chiede all'utente cosa installare**:
   - **1) Tutto**
   - **2) Solo gli essenziali**
   - **3) Scelta manuale** (elenco numerato diviso per categoria, si digitano i numeri separati da virgola)
5. Per ogni programma mostra a schermo un blocco **INIZIO / FINE** ben distinto, anche per le installazioni completamente silenziose (Office, RustDesk, pacchetti winget con `--silent`): l'utente vede sempre quando un'installazione parte e quando finisce, con esito OK / GIA' INSTALLATO / ERRORE.
6. Alla fine mostra una tabella riepilogativa e salva tutto in `logs/installazione_<data>.log`.

## Catalogo software

**Essenziali** (sempre inclusi anche nella modalità "solo essenziali"):
- Google Chrome, 7-Zip, VLC Media Player, .NET Desktop Runtime 8, Visual C++ Redistributable x64

**Consigliati**:
- Microsoft 365 (Office, via Office Deployment Tool)
- Microsoft Teams
- PDFgear (editor PDF gratuito)
- WhatsApp Desktop
- RustDesk (assistenza remota — vedi nota sotto)

**Diagnostica IT** (per assistenza/troubleshooting):
- Advanced IP Scanner (scansione rete)
- Sysinternals Suite (Process Explorer, Autoruns, ecc.)
- CrystalDiskInfo (salute dischi)
- Malwarebytes (scansione malware on-demand)
- CPU-Z (info hardware)
- Everything (ricerca file istantanea)
- HWiNFO (monitoraggio hardware)

**Opzionali**:
- WinRAR, Adobe Acrobat Reader, Notepad++, Mozilla Firefox

## Note tecniche importanti

- **Rilevamento "già installato" affidabile**: per i pacchetti winget lo script esegue prima un controllo reale con `winget list --id <id> --exact` (non si basa più su un'interpretazione dei codici di errore, che si era rivelata inaffidabile — vedi bug WhatsApp qui sotto). Per Office e RustDesk il controllo è sulla presenza effettiva dell'eseguibile su disco. In tutti i casi il programma già presente non viene toccato.
- **WhatsApp Desktop**: l'ID winget classico `WhatsApp.WhatsApp` non è più valido (rimosso dal catalogo, l'app è ora distribuita solo tramite Microsoft Store). Aggiornato all'ID Store corretto `9NKSQGP7F2NH`. Questo era anche la causa del falso "già installato" che avevi visto: winget restituiva "nessun pacchetto trovato" e il vecchio script interpretava male quel codice di errore.
- **RustDesk**: non è più disponibile su winget (rimosso dal repository ufficiale per un falso positivo antivirus sull'installer EXE). Lo script ora scarica il pacchetto **MSI** ufficiale dall'ultima release GitHub e lo installa con `msiexec /qn`, che termina in modo affidabile (l'EXE con `--silent-install` usato in precedenza poteva restare "appeso" senza chiudere il processo, causando il blocco che avevi riscontrato). C'è anche un timeout di sicurezza di 5 minuti: se per qualche motivo il processo non termina, viene interrotto e lo script prosegue comunque con gli altri programmi.
- Se in futuro Microsoft cambia la struttura della pagina di download ODT, il rilevamento automatico del link Office potrebbe smettere di funzionare: in tal caso va aggiornato l'URL nello script.
- Il flag `--force` su winget evita falsi positivi di hash mismatch (es. Chrome, il cui installer cambia più spesso del manifest winget).
- La tabella `$errorExplanations` nello script contiene le spiegazioni dei codici di errore veri più comuni: si può ampliare aggiungendo altre coppie `"codice" = "spiegazione"`.
- Per aggiungere/togliere programmi dal catalogo, basta modificare l'hashtable `$catalogo` in cima allo script (categoria, tipo, id winget, se essenziale).

# 🇮🇹 README.md (Italiano) - Versione 3.0.1

# 🚀 Proxmox LXC OS Update Script (Debian & Major Upgrade)

Questo script Bash avanzato semplifica la manutenzione dei container LXC su Proxmox VE. Grazie a un'interfaccia ibrida (GUI interattiva e CLI), gestisce aggiornamenti di sicurezza (**Minor**) e passaggi di versione (**Major Upgrade**) in modo sicuro, anche quando sei collegato tramite una VPN che gira dentro uno degli LXC da aggiornare (Tailscale, WireGuard, reverse proxy).

## ✨ Novità Versione 3.0.x
* **APT staccato dalla sessione:** l'aggiornamento gira sull'host con `setsid nohup`. Se SSH o la VPN cadono, APT **non viene interrotto a metà** (evita pacchetti `dpkg` rotti). L'output resta visibile in diretta e salvato in `/root/os_update_<ID>.log`.
* **LXC critici per ultimi:** gli LXC che portano la tua connessione (Tailscale, Termix, WireGuard, reverse proxy) vengono aggiornati dopo tutti gli altri.
* **Riavvio differito dei critici:** gli LXC normali si riavviano subito dopo l'aggiornamento. I critici si riavviano **alla fine**, dopo il report, con uno script staccato che prosegue anche se la connessione cade.
* **Ordine garantito in ogni modalità:** anche in `BACKGROUND` viene lanciata una sola esecuzione con tutti gli ID, quindi l'ordine è sempre rispettato.
* **Più ID da CLI:** puoi indicare più container nello stesso comando (`105 107 109`).
* **Versione di partenza automatica:** nel Major Upgrade lo script legge il codename attuale dal container, se non lo indichi tu.
* **Report finale:** ✅ aggiornato, ❌ errore, ⏭️ saltato, per ogni LXC.

## 🛠️ Prerequisiti
* **Host:** Proxmox VE con utente `root`.
* **Container:** LXC basati su Debian (testato da Debian 12+).
* **Pacchetti:** `whiptail` (solitamente preinstallato su Proxmox).

## 📥 Installazione consigliata
Per la modalità `BACKGROUND` lo script deve esistere come file locale, perché si rilancia da solo in una sessione staccata. Salvalo così:

```bash
curl -fsSL https://raw.githubusercontent.com/fcaronte/proxmox_os_lxc_update/main/update-os-lxc.sh -o /root/update-os-lxc.sh
chmod +x /root/update-os-lxc.sh
```

Poi lancialo con `/root/update-os-lxc.sh`. Lanciandolo con `bash -c "$(curl ...)"` tutto funziona tranne `BACKGROUND`.

## 🚀 Utilizzo

### 🖥️ Modalità Interattiva (GUI)
Senza argomenti si apre un menu guidato:
```bash
/root/update-os-lxc.sh
```
1.  **Selezione LXC:** scegli i container da aggiornare. `ALL` li seleziona tutti quelli attivi, `BACKGROUND` esegue tutto in una sessione staccata.
2.  **Sicurezza:** scegli se creare uno snapshot e se pulirlo alla fine (default: snapshot attivo, pulizia **attiva**).
3.  **Tipo Upgrade:** `MINOR` (solo patch) o `MAJOR` (cambio versione).

---

### ⌨️ Modalità Riga di Comando (CLI)

#### 1. Aggiornamento Minor (Patch di sicurezza)
Esegue `apt update`, `upgrade`, `dist-upgrade` e `autoremove`.
* **Tutti i container attivi:** `... all`
* **Singolo ID:** `... 100`
* **Più ID:** `... 100 101 102`

#### 2. Aggiornamento Major (Cambio Versione)
Modifica `/etc/apt/sources.list` e aggiorna l'intero sistema.
* **Aggiorna il container 100 a *Trixie*:** `... 100 trixie`
* **Con versione di partenza specifica:** `... 100 trixie bookworm`

Se non indichi la versione di partenza, viene letta da `/etc/os-release` del container.

#### 3. Opzioni Speciali (Flag)
* `--no-snap`: salta la creazione dello snapshot (più veloce, meno sicuro).
* `--clean`: rimuove lo snapshot se l'aggiornamento riesce.

---

## 🔒 LXC critici

Un LXC è considerato **critico** se almeno una di queste condizioni è vera:
* il suo ID è in `CRITICAL_LXC_IDS`;
* il suo hostname contiene uno dei nomi in `CRITICAL_NAMES`;
* ha uno stack Docker (cartella con `compose.yml` o `docker-compose.yml`) il cui nome contiene uno di quei nomi.

Configurazione all'inizio dello script:

```bash
CRITICAL_NAMES="tailscale termix wireguard nginx npmplus"
CRITICAL_LXC_IDS=""        # es. "9007 9009"
SCAN_ROOTS="/root /opt/stacks"
APT_TIMEOUT=3600           # attesa massima per l'APT di un LXC (secondi)
```

Il confronto è per sottostringa e non distingue maiuscole/minuscole. Evita nomi troppo generici, che catturerebbero anche LXC non critici.

**Come vengono trattati:**
1. Vengono aggiornati dopo tutti gli altri LXC.
2. Il loro riavvio non parte subito: viene messo in coda.
3. A fine processo, dopo il report, uno script staccato li riavvia uno alla volta (log in `/root/reboot_critici.log`).

> ⚠️ Se la sessione cade durante l'APT di un LXC critico, l'aggiornamento finisce comunque ma il riavvio non parte. In quel caso lancia `pct reboot <ID>` a mano.

---

## 💡 Esempi Pratici CLI

**Aggiorna tutti i container (solo patch) con pulizia snapshot finale:**
```bash
/root/update-os-lxc.sh all --clean
```

**Passaggio Major da Bookworm a Trixie per il container 105:**
```bash
/root/update-os-lxc.sh 105 trixie bookworm
```

**Più container, senza snapshot:**
```bash
/root/update-os-lxc.sh 105 107 109 --no-snap
```

## 📄 File di log
| File | Contenuto |
|---|---|
| `/root/os_update_<ID>.log` | Output di APT per ogni LXC |
| `/root/reboot_critici.log` | Esito del riavvio differito |
| `/root/script.tmp` | Log complessivo in modalità `BACKGROUND` |

Per seguire un aggiornamento in background: `tail -f /root/script.tmp`.

## 🛡️ Nota di sicurezza
Di default lo script crea uno snapshot chiamato `DEB_UPGRADE_SNAP_...`. Se l'aggiornamento fallisce, lo snapshot viene **conservato** e il container **non viene riavviato**, così puoi ripristinarlo dalla UI di Proxmox.

## ⚠️ Limiti noti
* Il cambio di repository nel Major Upgrade agisce su `/etc/apt/sources.list`. Se il container usa il formato `.sources` (`/etc/apt/sources.list.d/*.sources`), controlla i file a mano.
* Il rilevamento dei critici è basato sui nomi: uno stack con un nome diverso (per esempio `vpn`) va aggiunto a `CRITICAL_NAMES`.

---

# 🇬🇧 README.md (English) - Version 3.0.1

# 🚀 Proxmox LXC OS Update Script (Debian & Major Upgrade)

An advanced Bash script that streamlines LXC container maintenance on Proxmox VE. With a hybrid interface (interactive GUI and CLI), it handles security patches (**Minor**) and distribution upgrades (**Major**) safely, even when you are connected through a VPN running inside one of the LXCs being updated (Tailscale, WireGuard, reverse proxy).

## ✨ New in Version 3.0.x
* **APT detached from your session:** the update runs on the host with `setsid nohup`. If SSH or the VPN drops, APT is **not interrupted midway** (no half-configured `dpkg`). Output is shown live and saved to `/root/os_update_<ID>.log`.
* **Critical LXCs last:** LXCs that carry your connection (Tailscale, Termix, WireGuard, reverse proxy) are updated after all the others.
* **Deferred reboot for critical LXCs:** normal LXCs reboot right after the update. Critical ones reboot **at the end**, after the report, through a detached script that keeps going even if your connection drops.
* **Order guaranteed in every mode:** even in `BACKGROUND`, a single run handles all IDs, so the order is always respected.
* **Multiple IDs on the CLI:** `105 107 109`.
* **Automatic starting version:** for a Major Upgrade the script reads the current codename from the container if you don't pass it.
* **Final report:** ✅ updated, ❌ error, ⏭️ skipped, for each LXC.

## 📥 Recommended installation
`BACKGROUND` mode needs the script as a local file, because it relaunches itself in a detached session:

```bash
curl -fsSL https://raw.githubusercontent.com/fcaronte/proxmox_os_lxc_update/main/update-os-lxc.sh -o /root/update-os-lxc.sh
chmod +x /root/update-os-lxc.sh
```

Running it through `bash -c "$(curl ...)"` works for everything except `BACKGROUND`.

## 🚀 Usage

### 🖥️ Interactive Mode (GUI)
```bash
/root/update-os-lxc.sh
```
Pick the LXCs (`ALL` selects every running one, `BACKGROUND` runs everything in a detached session), choose snapshot options (snapshot on, cleanup **on** by default), then `MINOR` or `MAJOR`.

### ⌨️ Command Line Mode (CLI)
* **Minor, all running containers:** `... all`
* **Minor, specific IDs:** `... 100 101 102`
* **Major to Trixie:** `... 100 trixie`
* **Major with explicit starting version:** `... 100 trixie bookworm`

Flags:
* `--no-snap`: skip snapshot creation.
* `--clean`: remove the snapshot if the update succeeds.

## 🔒 Critical LXCs

An LXC is **critical** if its ID is in `CRITICAL_LXC_IDS`, its hostname contains a name from `CRITICAL_NAMES`, or it has a Docker stack folder whose name contains one of those names.

```bash
CRITICAL_NAMES="tailscale termix wireguard nginx npmplus"
CRITICAL_LXC_IDS=""        # e.g. "9007 9009"
SCAN_ROOTS="/root /opt/stacks"
APT_TIMEOUT=3600           # max wait for one LXC's APT run (seconds)
```

Matching is a case-insensitive substring match, so avoid generic names.

Critical LXCs are updated last, their reboot is queued, and after the final report a detached script reboots them one by one (log in `/root/reboot_critici.log`).

> ⚠️ If your session drops during a critical LXC's APT run, the update still completes but the reboot does not start. Run `pct reboot <ID>` manually.

## 💡 Examples

```bash
/root/update-os-lxc.sh all --clean
/root/update-os-lxc.sh 105 trixie bookworm
/root/update-os-lxc.sh 105 107 109 --no-snap
```

## 📄 Log files
| File | Content |
|---|---|
| `/root/os_update_<ID>.log` | APT output for each LXC |
| `/root/reboot_critici.log` | Deferred reboot result |
| `/root/script.tmp` | Combined log in `BACKGROUND` mode |

## 🛡️ Safety Note
By default the script creates a snapshot named `DEB_UPGRADE_SNAP_...`. If an update fails, the snapshot is **kept** and the container is **not rebooted**, so you can restore it from the Proxmox UI.

## ⚠️ Known limitations
* Major Upgrade edits `/etc/apt/sources.list` only. If a container uses the `.sources` format, check those files manually.
* Critical detection is name-based: a stack with a different name (for example `vpn`) must be added to `CRITICAL_NAMES`.
* 

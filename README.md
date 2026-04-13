
---

# 🇮🇹 README.md (Italiano) - Versione 2.2.0

# 🚀 Proxmox LXC OS Update Script (Debian & Major Upgrade)

Questo script Bash avanzato è progettato per semplificare la manutenzione dei container LXC su Proxmox VE. Grazie a un'interfaccia ibrida (GUI interattiva e CLI), permette di gestire aggiornamenti di sicurezza (**Minor**) e passaggi di versione (**Major Upgrade**) con estrema facilità e sicurezza.

## ✨ Novità Versione 2.2.x
* **Interfaccia Grafica (GUI):** Menu interattivo basato su `whiptail` per chi preferisce non usare la riga di comando.
* **Gestione Snapshot:** Creazione automatica di snapshot prima di ogni aggiornamento per un rollback immediato in caso di errori.
* **Pulizia Automatica:** Opzione per eliminare lo snapshot creato se l'aggiornamento va a buon fine.
* **Supporto Major Upgrade:** Automazione del cambio repository (es. da *Bookworm* a *Trixie*).

## 🛠️ Prerequisiti
* **Host:** Proxmox VE con utente `root`.
* **Container:** LXC basati su Debian (testato da Debian 12+).
* **Pacchetti:** `whiptail` (solitamente preinstallato su Proxmox).

## 🚀 Utilizzo

Puoi lanciare lo script direttamente dal tuo terminale Proxmox.

### 🖥️ Modalità Interattiva (GUI)
Se lanci lo script senza argomenti, si aprirà un menu guidato:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fcaronte/proxmox_os_lxc_update/main/update-os-lxc.sh)"
```
1.  **Selezione LXC:** Scegli quali container aggiornare dalla lista dei container attivi.
2.  **Sicurezza:** Scegli se creare uno snapshot e se pulirlo automaticamente alla fine (Default: Snapshot attivo, Pulizia disattivata).
3.  **Tipo Upgrade:** Scegli tra `MINOR` (solo patch) o `MAJOR` (cambio versione).

---

### ⌨️ Modalità Riga di Comando (CLI)
Per automazioni o utenti avanzati, lo script accetta diversi parametri:

#### 1. Aggiornamento Minor (Patch di sicurezza)
Esegue `apt update`, `upgrade` e `full-upgrade` sulla versione attuale.
* **Tutti i container:** `... -- all`
* **Singolo ID:** `... -- 100`

#### 2. Aggiornamento Major (Cambio Versione)
Modifica i file `sources.list` e aggiorna l'intero sistema.
* **Esempio:** Aggiorna il container 100 a *Trixie*:
    `... -- 100 trixie`
* **Esempio con versione partenza specifica:** Aggiorna da *Bookworm* a *Trixie*:
    `... -- 100 trixie bookworm`

#### 3. Opzioni Speciali (Flag)
Puoi aggiungere questi flag alla fine di qualsiasi comando CLI:
* `--no-snap`: Salta completamente la creazione dello snapshot (più veloce, meno sicuro).
* `--clean`: Rimuove lo snapshot creato se l'aggiornamento si conclude con successo.

---

## 💡 Esempi Pratici CLI

**Aggiorna tutti i container (solo patch) con pulizia snapshot finale:**
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fcaronte/proxmox_os_lxc_update/main/update-os-lxc.sh)" -- all --clean
```

**Passaggio Major da Bookworm a Trixie per il container 105:**
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fcaronte/proxmox_os_lxc_update/main/update-os-lxc.sh)" -- 105 trixie bookworm
```

---

# 🇬🇧 README.md (English) - Version 2.2.0

# 🚀 Proxmox LXC OS Update Script (Debian & Major Upgrade)

An advanced Bash script designed to streamline LXC container maintenance on Proxmox VE. Featuring a hybrid interface (Interactive GUI and CLI), it handles security patches (**Minor**) and distribution upgrades (**Major Upgrade**) with ease and built-in safety.

## ✨ New in Version 2.2.x
* **Interactive GUI:** `whiptail`-based menus for ease of use.
* **Snapshot Management:** Automatic snapshot creation before updates for instant rollback if needed.
* **Auto-Cleanup:** Option to delete the temporary snapshot upon successful update.
* **Major Upgrade Support:** Automatic repository switching (e.g., from *Bookworm* to *Trixie*).

## 🚀 Usage

### 🖥️ Interactive Mode (GUI)
Run without arguments to open the guided menu:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fcaronte/proxmox_os_lxc_update/main/update-os-lxc.sh)"
```

### ⌨️ Command Line Mode (CLI)
#### 1. Minor Update (Security Patches)
* **All containers:** `... -- all`
* **Specific ID:** `... -- 100`

#### 2. Major Update (Distribution Upgrade)
* **Update ID 100 to Trixie:** `... -- 100 trixie`
* **Specify starting version:** `... -- 100 trixie bookworm`

#### 3. Special Flags
* `--no-snap`: Skip snapshot creation.
* `--clean`: Remove the snapshot automatically if the update succeeds.

---

## 🛡️ Safety Note
By default, the script creates a snapshot named `DEB_UPGRADE_SNAP_...`. If an update fails, the snapshot is **kept** to allow you to restore the container from the Proxmox UI.

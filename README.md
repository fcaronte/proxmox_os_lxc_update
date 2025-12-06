
# 🇮🇹 README.md (Italiano) Aggiornato

# 🚀 Proxmox LXC OS Update Script (Debian 13+)

Questo script Bash è progettato per semplificare l'amministrazione di container LXC su Proxmox VE. Consente di eseguire aggiornamenti di sistema completi (sia **Minor** che **Major Releases**) sui container basati su **Debian 13 (Trixie)** o successivi, il tutto direttamente dall'host Proxmox con un unico comando.

Il processo utilizza il comando nativo `pct exec` per garantire la massima integrazione.

## Funzionalità

  * **Aggiornamento Minor (Patch/Point Release):** Aggiorna tutti i pacchetti all'interno della versione Debian corrente (es. 13.1 a 13.2).
  * **Aggiornamento Major (Release Upgrade):** Esegue l'aggiornamento completo della distribuzione (es. da Debian 13 "Trixie" a Debian 14 "Chimaera") modificando i repository di `apt` in modo automatico.
  * **Targeting Flessibile:** Supporta l'aggiornamento di tutti i container in stato `running` (`all`) o solo di container specifici tramite il loro ID.
  * **Gestione Versioni Specifiche:** Permette di specificare la versione corrente (`VECCHIO_CODENAME`) per gli aggiornamenti Major di singoli container, garantendo flessibilità tra LXC con versioni Debian diverse.
  * **Robustezza:** Include il riavvio automatico per applicare le modifiche al kernel o ai servizi critici.

## 🛠️ Prerequisiti

  * Sistema Host: Proxmox VE.
  * Container: LXC basati su **Debian 13 (Trixie)** o successivi.
  * Lo script deve essere eseguito come utente **root** sull'host.

## 🚀 Utilizzo

Lo script è progettato per essere eseguito direttamente dalla shell del tuo host Proxmox.

### Metodo Consigliato (Esecuzione Diretta da GitHub)

Utilizza `curl` per scaricare ed eseguire lo script in un unico passaggio, passando gli argomenti:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fcaronte/proxmox_os_lxc_update/main/update-os-lxc.sh)" -- <ARGOMENTI>
```

Sostituisci `<ARGOMENTI>` con una delle opzioni seguenti.

-----

### Modalità 1: Aggiornamento Minor (Patch/Point Release)

Questo aggiornamento esegue `apt update`, `apt upgrade`, `apt full-upgrade` e `apt autoremove` sui repository attuali.

| Target | Sintassi d'Esempio |
| :--- | :--- |
| **TUTTI** i container running | `-- all` |
| **SINGOLI** container (ID 8006, 8007) | `-- 8006 8007` |

-----

### Modalità 2: Aggiornamento Major (Cambio Versione)

Questa modalità esegue il `sed` per sostituire il nome in codice nei file `/etc/apt/sources.list` dei container, seguito dall'aggiornamento completo.

#### A. Aggiornamento Major per TUTTI (Usa Versione di Default)

Se tutti i tuoi LXC sono alla versione di default definita nello script (`CURRENT_CODENAME_DEFAULT`):

| Target | Sintassi | Esempio |
| :--- | :--- | :--- |
| **TUTTI** i container | `-- all <NUOVO_CODENAME>` | `-- all chimaera` |

#### B. Aggiornamento Major per Singolo LXC (Uso Flessibile)

Se devi aggiornare un container la cui versione di partenza non è quella di default (es. è ancora Bookworm), puoi specificare tre argomenti.

| Target | Sintassi | Esempio |
| :--- | :--- | :--- |
| **SINGOLO** container | `-- <ID_LXC> <NUOVO_CODENAME> <VECCHIO_CODENAME>` | `-- 100 trixie bookworm` |

-----

## Esempio di Utilizzo

Per eseguire l'aggiornamento Major (a **Trixie**) sul solo container **101**, assumendo che sia ancora su **Bookworm**:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fcaronte/proxmox_os_lxc_update/main/update-os-lxc.sh)" -- 101 trixie bookworm
```

-----


# 🇬🇧 README.md (English)

# 🚀 Proxmox LXC OS Update Script (Debian 13+)

This Bash script is designed to simplify the administration of LXC containers on Proxmox VE. It allows you to perform full system updates (both **Minor** and **Major Releases**) on containers based on **Debian 13 (Trixie)** or later, all from the Proxmox host using a single command.

The process leverages the native `pct exec` command for maximum integration.

## Features

  * **Minor Update (Patch/Point Release):** Updates all packages within the current Debian major version (e.g., 13.1 to 13.2).
  * **Major Update (Release Upgrade):** Performs the full distribution upgrade (e.g., from Debian 13 "Trixie" to Debian 14 "Chimaera") by automatically modifying the `apt` repositories.
  * **Flexible Targeting:** Supports updating all containers in a `running` state (`all`) or only specific containers by their ID.
  * **Specific Version Handling:** Allows specifying the current version (`OLD_CODENAME`) for Major upgrades of single containers, ensuring flexibility for LXCs with different Debian versions.
  * **Robustness:** Includes automatic rebooting to apply kernel or critical service changes.

## 🛠️ Prerequisites

  * Host System: Proxmox VE.
  * Containers: LXC based on **Debian 13 (Trixie)** or later.
  * The script must be run as the **root** user on the host.

## 🚀 Usage

The script is designed to be executed directly from your Proxmox host shell.

### Recommended Method (Direct Execution from GitHub)

Use `curl` to download and execute the script in a single step, passing the arguments:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fcaronte/proxmox_os_lxc_update/main/update-os-lxc.sh)" -- <ARGUMENTS>
```

Replace `<ARGUMENTS>` with one of the following options.

-----

### Mode 1: Minor Update (Patch/Point Release)

This update performs `apt update`, `apt upgrade`, `apt full-upgrade`, and `apt autoremove` against the current repositories.

| Target | Example Syntax |
| :--- | :--- |
| **ALL** running containers | `-- all` |
| **SPECIFIC** containers (IDs 8006, 8007) | `-- 8006 8007` |

-----

### Mode 2: Major Update (Version Change)

This mode executes a `sed` command to replace the codename in the containers' `/etc/apt/sources.list` files, followed by the full system upgrade.

#### A. Major Update for ALL Containers (Using Default Current Version)

If all your LXCs are on the default starting version defined in the script (`CURRENT_CODENAME_DEFAULT`):

| Target | Syntax | Example |
| :--- | :--- | :--- |
| **ALL** containers | `-- all <NEW_CODENAME>` | `-- all chimaera` |

#### B. Major Update for Single LXC (Flexible Usage)

If you need to upgrade a container whose starting version is *not* the script's default (e.g., it's still Bookworm), you must specify three arguments.

| Target | Syntax | Example |
| :--- | :--- | :--- |
| **SINGLE** container | `-- <LXC_ID> <NEW_CODENAME> <OLD_CODENAME>` | `-- 100 trixie bookworm` |

-----

## Usage Example

To perform a Major Upgrade (to **Trixie**) on container **101** only, assuming it is currently on **Bookworm**:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fcaronte/proxmox_os_lxc_update/main/update-os-lxc.sh)" -- 101 trixie bookworm
```

-----

Qual è il prossimo elemento che vuoi configurare nel tuo ambiente? Ad esempio, NGINX Proxy Manager, Frigate o un altro servizio?



# 🇮🇹 README.md (Italiano)

# 🚀 Proxmox LXC OS Update Script (Debian 13+)

Questo script Bash è progettato per semplificare l'amministrazione di container LXC su Proxmox VE. Consente di eseguire aggiornamenti di sistema completi (sia **Minor** che **Major Releases**) sui container basati su **Debian 13 (Trixie)** o successivi, il tutto direttamente dall'host Proxmox con un unico comando.

Il processo utilizza il comando nativo `pct exec` per garantire la massima integrazione.

## Funzionalità

  * **Aggiornamento Minor (Patch/Point Release):** Aggiorna tutti i pacchetti all'interno della versione Debian corrente (es. 13.1 a 13.2).
  * **Aggiornamento Major (Release Upgrade):** Esegue l'aggiornamento completo della distribuzione (es. da Debian 13 "Trixie" a Debian 14 "Chimaera") modificando i repository di `apt` in modo automatico.
  * **Targeting Flessibile:** Supporta l'aggiornamento di tutti i container in stato `running` (`all`) o solo di container specifici tramite il loro ID.
  * **Robustezza:** Include il riavvio automatico per applicare le modifiche al kernel o ai servizi critici.

## 🛠️ Prerequisiti

  * Sistema Host: Proxmox VE.
  * Container: LXC basati su **Debian 13 (Trixie)** o successivi.
  * Lo script deve essere eseguito come utente **root** sull'host.

## 🚀 Utilizzo

Lo script è progettato per essere eseguito direttamente dalla shell del tuo host Proxmox.

### Metodo Consigliato (Esecuzione Diretta da GitHub)

Utilizza `curl` per scaricare ed eseguire lo script in un unico passaggio, passandogli gli argomenti:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fcaronte/proxmox_os_lxc_update/main/update-os-lxc.sh)" -- <ARGOMENTI>
```

Sostituisci `<ARGOMENTI>` con una delle opzioni seguenti.

-----

### Modalità 1: Aggiornamento Minor (Patch/Point Release)

Questo aggiornamento esegue `apt update`, `apt upgrade`, `apt full-upgrade` e `apt autoremove` sui repository attuali (es. `trixie`).

  * **Sintassi:**
    ```bash
    bash -c "$(curl -fsSL .../update-os-lxc.sh)" -- all
    ```

### Modalità 2: Aggiornamento Major (Cambio Versione)

Questa modalità modifica prima il file `/etc/apt/sources.list` all'interno dei container, sostituendo il **vecchio** nome in codice con il **nuovo**, e poi esegue l'aggiornamento completo.

  * **Sintassi:**
    ```bash
    bash -c "$(curl -fsSL .../update-os-lxc.sh)" -- all <NUOVO_CODENAME>
    ```

| Scenario | Nome in Codice Corrente | Sintassi d'Esempio |
| :--- | :--- | :--- |
| **Upgrade a Debian 14** | `trixie` | `-- all chimaera` |
| **Upgrade a Debian 15** | `chimaera` | `-- all futurocodice` |

-----

### Modalità 3: Aggiornamento Container Specifici

Per limitare l'aggiornamento a container specifici (senza usare `all`), elenca gli ID:

  * **Aggiornamento Minor (ID Specifici):**
    ```bash
    bash -c "$(curl -fsSL .../update-os-lxc.sh)" -- 8006 8007
    ```

-----

-----

# 🇬🇧 README.md (English)

# 🚀 Proxmox LXC OS Update Script (Debian 13+)

This Bash script is designed to simplify the administration of LXC containers on Proxmox VE. It allows you to perform full system updates (both **Minor** and **Major Releases**) on containers based on **Debian 13 (Trixie)** or later, all from the Proxmox host using a single command.

The process leverages the native `pct exec` command for maximum integration.

## Features

  * **Minor Update (Patch/Point Release):** Updates all packages within the current Debian major version (e.g., 13.1 to 13.2).
  * **Major Update (Release Upgrade):** Performs the full distribution upgrade (e.g., from Debian 13 "Trixie" to Debian 14 "Chimaera") by automatically modifying the `apt` repositories.
  * **Flexible Targeting:** Supports updating all containers in a `running` state (`all`) or only specific containers by their ID.
  * **Robustness:** Includes automatic rebooting to apply kernel or critical service changes.

## 🛠️ Prerequisites

  * Host System: Proxmox VE.
  * Containers: LXC based on **Debian 13 (Trixie)** or later.
  * The script must be run as the **root** user on the host.

## 🚀 Usage

The script is designed to be executed directly from your Proxmox host shell.

### Recommended Method (Direct Execution from GitHub)

Use `curl` to download and execute the script in a single step, passing the arguments directly:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/fcaronte/proxmox_os_lxc_update/main/update-os-lxc.sh)" -- <ARGUMENTS>
```

Replace `<ARGUMENTS>` with one of the following options.

-----

### Mode 1: Minor Update (Patch/Point Release)

This update performs `apt update`, `apt upgrade`, `apt full-upgrade`, and `apt autoremove` against the current repositories (e.g., `trixie`).

  * **Syntax:**
    ```bash
    bash -c "$(curl -fsSL .../update-os-lxc.sh)" -- all
    ```

### Mode 2: Major Update (Version Change)

This mode first modifies the `/etc/apt/sources.list` file inside the containers, replacing the **old** codename with the **new** one, and then executes the full system upgrade.

  * **Syntax:**
    ```bash
    bash -c "$(curl -fsSL .../update-os-lxc.sh)" -- all <NEW_CODENAME>
    ```

| Scenario | Current Codename | Example Syntax |
| :--- | :--- | :--- |
| **Upgrade to Debian 14** | `trixie` | `-- all chimaera` |
| **Upgrade to Debian 15** | `chimaera` | `-- all futurecodename` |

-----

### Mode 3: Specific Container Update

To limit the update to specific containers (without using `all`), list their IDs:

  * **Minor Update (Specific IDs):**
    ```bash
    bash -c "$(curl -fsSL .../update-os-lxc.sh)" -- 8006 8007
    ```

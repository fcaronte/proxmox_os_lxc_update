#!/bin/bash

# ======================================================================
# SCRIPT: update-debian.sh
# VERSIONE: 2.0.0 (Hybrid GUI/CLI for Debian Major/Minor Updates)
# ======================================================================

# --- COLORI ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- DEFAULT ---
CURRENT_CODENAME_DEFAULT="trixie"
SNAP_PREFIX="DEB_UPGRADE_SNAP"
UPDATE_CMD="apt update -y && apt upgrade -y && apt full-upgrade -y && apt autoremove --purge -y"

# --- FUNZIONE HELP ---
show_help() {
    echo -e "${CYAN}Utilizzo CLI:${NC} $0 <all|ID_LXC> [nuovo_codename] [vecchio_codename]"
    echo -e "  $0 100               (Minor Update / Patches)"
    echo -e "  $0 all trixie        (Major Update: tutti da default a trixie)"
    echo -e "  $0 100 trixie bookworm (Major Update specifico)"
    echo -e "\n${CYAN}Info:${NC} Avvia senza argomenti per l'interfaccia grafica."
    exit 0
}

# --- FUNZIONE CORE DI AGGIORNAMENTO ---
update_lxc() {
    local LXC_ID=$1
    local NEW_CODENAME=$2
    local OLD_CODENAME=${3:-$CURRENT_CODENAME_DEFAULT}
    
    echo -e "\n${CYAN}----------------------------------------------------------------${NC}"
    echo -e "${GREEN}### Elaborazione LXC ID ${LXC_ID}... ###${NC}"

    STATUS=$(pct status $LXC_ID 2>/dev/null)
    if [[ $? -ne 0 || "$STATUS" != "status: running" ]]; then
        echo -e "${RED}SKIPPATO: LXC ${LXC_ID} non trovato o non attivo.${NC}"
        return
    fi

    # 1. Creazione Snapshot di sicurezza
    local SNAP_NAME="${SNAP_PREFIX}_$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}-> Creazione snapshot: $SNAP_NAME...${NC}"
    if ! pct snapshot $LXC_ID "$SNAP_NAME" --description "Pre-upgrade Debian script"; then
        echo -e "${RED}ERRORE: Impossibile creare lo snapshot. Interruzione per sicurezza.${NC}"
        return
    fi

    # 2. Gestione Major Upgrade (sed)
    if [ ! -z "$NEW_CODENAME" ]; then
        echo -e "${YELLOW}!!! MAJOR UPGRADE: ${OLD_CODENAME} -> ${NEW_CODENAME} !!!${NC}"
        MOD_CMD="sed -i 's/${OLD_CODENAME}/${NEW_CODENAME}/g' /etc/apt/sources.list"
        pct exec $LXC_ID -- bash -c "$MOD_CMD"
    fi

    # 3. Esecuzione Aggiornamento
    echo -e "${YELLOW}-> Esecuzione comandi APT...${NC}"
    pct exec $LXC_ID -- bash -c "export DEBIAN_FRONTEND=noninteractive && $UPDATE_CMD"

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Aggiornamento completato. Riavvio in corso...${NC}"
        pct reboot $LXC_ID
    else
        echo -e "${RED}ERRORE durante l'aggiornamento. Ripristinare lo snapshot $SNAP_NAME se necessario.${NC}"
    fi
}

# --- LOGICA INTERATTIVA (GUI) ---
if [ "$#" -eq 0 ]; then
    if ! command -v whiptail &> /dev/null; then echo "Errore: whiptail non trovato."; exit 1; fi

    # 1. Scelta Container
    LXC_RAW=$(pct list | awk 'NR>1 {print $1 " [" $3 "] off"}')
    LXC_MENU="ALL [Tutti_i_container] off $LXC_RAW"
    CHOICES=$(whiptail --title "Debian Update Manager" --checklist "Seleziona LXC da aggiornare:" 20 75 10 $LXC_MENU 3>&1 1>&2 2>&3)
    [ -z "$CHOICES" ] && exit 0
    CHOICES=$(echo "$CHOICES" | tr -d '"')
    [[ " $CHOICES " == *" ALL "* ]] && CHOICES="all"

    # 2. Scelta Tipo Aggiornamento
    UP_TYPE=$(whiptail --title "Tipo di Aggiornamento" --menu "Cosa vuoi fare?" 15 60 4 \
        "MINOR" "Patch e upgrade della versione attuale" \
        "MAJOR" "Cambio di versione (es. bookworm -> trixie)" 3>&1 1>&2 2>&3)
    
    NEW_CN=""
    OLD_CN=""

    if [ "$UP_TYPE" == "MAJOR" ]; then
        OLD_CN=$(whiptail --inputbox "Codename ATTUALE (es. bookworm):" 10 60 "$CURRENT_CODENAME_DEFAULT" 3>&1 1>&2 2>&3)
        NEW_CN=$(whiptail --inputbox "Codename NUOVO (es. trixie):" 10 60 "" 3>&1 1>&2 2>&3)
        [ -z "$NEW_CN" ] && { echo "Annullato: Codename mancante."; exit 1; }
    fi

    # Esecuzione Loop GUI
    LXC_LIST=""
    if [ "$CHOICES" == "all" ]; then
        LXC_LIST=$(pct list | grep running | awk '{print $1}')
    else
        LXC_LIST=$CHOICES
    fi

    for ID in $LXC_LIST; do
        update_lxc "$ID" "$NEW_CN" "$OLD_CN"
    done
    echo -e "\n${GREEN}Tutte le operazioni completate.${NC}"
    exit 0
fi

# --- LOGICA CLI (Se vengono passati argomenti) ---
case "$1" in
    -h|--help) show_help ;;
    all)
        LXC_LIST=$(pct list | grep running | awk '{print $1}')
        for ID in $LXC_LIST; do update_lxc "$ID" "$2"; done
        ;;
    *)
        if [[ "$1" =~ ^[0-9]+$ ]]; then
            update_lxc "$1" "$2" "$3"
        else
            show_help
        fi
        ;;
esac

echo -e "\n${GREEN}Operazioni completate.${NC}"

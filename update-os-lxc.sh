#!/bin/bash

# ======================================================================
# SCRIPT: update-debian.sh
# VERSIONE: 2.1.0 (GUI/CLI with Snapshot Management)
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

# Variabili di stato
SKIP_SNAPSHOT=false
CLEAN_SNAPSHOT=false

# --- FUNZIONE HELP ---
show_help() {
    echo -e "${CYAN}Utilizzo CLI:${NC} $0 <all|ID_LXC> [nuovo_codename] [opzioni]"
    echo -e "Opzioni:"
    echo -e "  --no-snap      Salta la creazione dello snapshot"
    echo -e "  --clean        Rimuovi lo snapshot se l'aggiornamento riesce"
    echo -e "\nEsempio Major con pulizia: $0 100 trixie --clean"
    exit 0
}

# --- FUNZIONE CORE DI AGGIORNAMENTO ---
update_lxc() {
    local LXC_ID=$1
    local NEW_CODENAME=$2
    local OLD_CODENAME=${3:-$CURRENT_CODENAME_DEFAULT}
    local CURRENT_SNAP=""
    
    echo -e "\n${CYAN}----------------------------------------------------------------${NC}"
    echo -e "${GREEN}### Elaborazione LXC ID ${LXC_ID}... ###${NC}"

    STATUS=$(pct status $LXC_ID 2>/dev/null)
    if [[ $? -ne 0 || "$STATUS" != "status: running" ]]; then
        echo -e "${RED}SKIPPATO: LXC ${LXC_ID} non trovato o non attivo.${NC}"
        return
    fi

    # 1. Gestione Snapshot
    if [ "$SKIP_SNAPSHOT" = false ]; then
        CURRENT_SNAP="${SNAP_PREFIX}_$(date +%Y%m%d_%H%M%S)"
        echo -e "${YELLOW}-> Creazione snapshot: $CURRENT_SNAP...${NC}"
        if ! pct snapshot $LXC_ID "$CURRENT_SNAP" --description "Pre-upgrade Debian script"; then
            echo -e "${RED}ERRORE: Impossibile creare lo snapshot. Interruzione.${NC}"
            return
        fi
    fi

    # 2. Gestione Major Upgrade
    if [[ ! -z "$NEW_CODENAME" && "$NEW_CODENAME" != "--clean" && "$NEW_CODENAME" != "--no-snap" ]]; then
        echo -e "${YELLOW}!!! MAJOR UPGRADE: ${OLD_CODENAME} -> ${NEW_CODENAME} !!!${NC}"
        pct exec $LXC_ID -- bash -c "sed -i 's/${OLD_CODENAME}/${NEW_CODENAME}/g' /etc/apt/sources.list"
    fi

    # 3. Esecuzione Aggiornamento
    echo -e "${YELLOW}-> Esecuzione comandi APT...${NC}"
    pct exec $LXC_ID -- bash -c "export DEBIAN_FRONTEND=noninteractive && $UPDATE_CMD"

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Aggiornamento completato.${NC}"
        
        # Pulizia snapshot se richiesto
        if [[ "$CLEAN_SNAPSHOT" = true && ! -z "$CURRENT_SNAP" ]]; then
            echo -e "${YELLOW}-> Pulizia snapshot temporaneo...${NC}"
            pct delsnapshot $LXC_ID "$CURRENT_SNAP"
        fi
        
        echo -e "${GREEN}Riavvio in corso...${NC}"
        pct reboot $LXC_ID
    else
        echo -e "${RED}ERRORE nell'aggiornamento. Snapshot $CURRENT_SNAP conservato.${NC}"
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

    # 2. Scelta Opzioni Snapshot
    SNAP_OPTS=$(whiptail --title "Gestione Snapshot" --checklist "Opzioni di sicurezza:" 15 60 2 \
        "nosnap" "Salta creazione snapshot" OFF \
        "clean" "Rimuovi snapshot se OK" ON 3>&1 1>&2 2>&3)
    
    [[ "$SNAP_OPTS" == *"nosnap"* ]] && SKIP_SNAPSHOT=true
    [[ "$SNAP_OPTS" == *"clean"* ]] && CLEAN_SNAPSHOT=true

    # 3. Scelta Tipo Aggiornamento
    UP_TYPE=$(whiptail --title "Tipo di Aggiornamento" --menu "Cosa vuoi fare?" 15 60 4 \
        "MINOR" "Patch e upgrade attuale" \
        "MAJOR" "Cambio versione (es. bookworm -> trixie)" 3>&1 1>&2 2>&3)
    
    NEW_CN=""
    if [ "$UP_TYPE" == "MAJOR" ]; then
        NEW_CN=$(whiptail --inputbox "Codename NUOVO (es. trixie):" 10 60 "" 3>&1 1>&2 2>&3)
        [ -z "$NEW_CN" ] && exit 1
    fi

    # Esecuzione Loop
    LXC_LIST=$([[ "$CHOICES" == "all" ]] && pct list | grep running | awk '{print $1}' || echo $CHOICES)
    for ID in $LXC_LIST; do update_lxc "$ID" "$NEW_CN"; done
    exit 0
fi

# --- LOGICA CLI ---
# Parsing basico opzioni
[[ "$*" == *"--no-snap"* ]] && SKIP_SNAPSHOT=true
[[ "$*" == *"--clean"* ]] && CLEAN_SNAPSHOT=true

case "$1" in
    all)
        LXC_LIST=$(pct list | grep running | awk '{print $1}')
        for ID in $LXC_LIST; do update_lxc "$ID" "$2"; done
        ;;
    [0-9]*)
        update_lxc "$1" "$2" "$3"
        ;;
    *)
        show_help
        ;;
esac

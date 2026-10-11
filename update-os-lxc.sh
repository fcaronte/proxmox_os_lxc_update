#!/bin/bash

# ======================================================================
# SCRIPT: update-os-lxc.sh
# VERSIONE: 3.0.0 (APT staccato dalla sessione, LXC critici per ultimi,
#                  riavvio dei critici differito a fine processo)
# ======================================================================

LOG_FILE="/root/script.tmp"
SCRIPT_FISICO="/tmp/script.sh"
[ -f "$SCRIPT_FISICO" ] || SCRIPT_FISICO="$(readlink -f "$0")"

# --- CONFIGURAZIONE LXC CRITICI ---
# Un LXC è critico se: il suo ID è in CRITICAL_LXC_IDS, oppure il suo hostname
# contiene uno di questi nomi, oppure ha uno stack docker con questo nome.
CRITICAL_NAMES="tailscale termix wireguard nginx npmplus"
CRITICAL_LXC_IDS=""                  # es. "9007 9009"
SCAN_ROOTS="/root /opt/stacks"
APT_TIMEOUT=3600                     # secondi massimi di attesa per l'APT di un LXC
REBOOT_LOG="/root/reboot_critici.log"

# --- RILEVAMENTO DIMENSIONI ADATTIVE ---
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)

IFACE_WIDTH=$(( TERM_WIDTH * 90 / 100 ))
[ $IFACE_WIDTH -gt 75 ] && IFACE_WIDTH=75
[ $IFACE_WIDTH -lt 45 ] && IFACE_WIDTH=45

IFACE_HEIGHT=$(( TERM_HEIGHT * 80 / 100 ))
[ $IFACE_HEIGHT -lt 16 ] && IFACE_HEIGHT=16

LIST_HEIGHT=$(( IFACE_HEIGHT - 8 ))

# --- COLORI ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- DEFAULT ---
CURRENT_CODENAME_DEFAULT="trixie"
SNAP_PREFIX="DEB_UPGRADE_SNAP"

# Comando APT 100% non interattivo
UPDATE_CMD="export DEBIAN_FRONTEND=noninteractive; apt-get update -y && apt-get upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' && apt-get dist-upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' && apt-get autoremove --purge -y"

# Variabili di stato
SKIP_SNAPSHOT=false
CLEAN_SNAPSHOT=false
CRIT_LIST=""            # ID degli LXC critici di questa esecuzione
REBOOT_QUEUE=""         # LXC critici da riavviare a fine processo
declare -a REPORT

# --- FUNZIONE HELP ---
show_help() {
    echo -e "${CYAN}Utilizzo CLI:${NC} $0 <all|ID_LXC [ID_LXC...]> [nuovo_codename] [opzioni]"
    echo -e "Opzioni:"
    echo -e "  --no-snap      Salta la creazione dello snapshot"
    echo -e "  --clean        Rimuovi lo snapshot se l'aggiornamento riesce"
    echo -e "\nEsempio Major con pulizia: $0 100 trixie --clean"
    exit 0
}

# ======================================================================
# FUNZIONI
# ======================================================================

# Ritorna 0 se l'LXC è critico (porta la VPN / il proxy da cui ti colleghi)
lxc_critico() {
    local ID=$1 N B P
    for N in $CRITICAL_LXC_IDS; do [ "$N" = "$ID" ] && return 0; done

    local HN
    HN=$(pct config "$ID" 2>/dev/null | awk '/^hostname:/ {print tolower($2)}')
    for N in $CRITICAL_NAMES; do [[ "$HN" == *"$N"* ]] && return 0; done

    # Controllo sugli stack docker (solo se l'LXC è acceso)
    [ "$(pct status "$ID" 2>/dev/null)" = "status: running" ] || return 1
    for P in $(pct exec "$ID" -- bash -c "find $SCAN_ROOTS -mindepth 1 -maxdepth 2 -type f -regex \".*\(docker-compose\|compose\).y\(a\)?ml\" -print0 2>/dev/null | xargs -0 -r -I {} dirname {} | sort -u" 2>/dev/null); do
        B="${P##*/}"; B="${B,,}"
        for N in $CRITICAL_NAMES; do [[ "$B" == *"$N"* ]] && return 0; done
    done
    return 1
}

# Esegue APT staccato dalla sessione: continua anche se SSH/VPN cadono.
# Ritorna il codice di uscita di APT (124 = timeout).
esegui_apt() {
    local ID=$1
    local HLOG="/root/os_update_${ID}.log"
    local HSCRIPT
    HSCRIPT=$(mktemp /tmp/os_update.XXXXXX)

    cat > "$HSCRIPT" <<EOF
#!/bin/bash
pct exec $ID -- bash -c "$UPDATE_CMD"
echo "__RC=\$?"
EOF

    : > "$HLOG"
    setsid nohup bash "$HSCRIPT" >"$HLOG" 2>&1 </dev/null &
    disown $! 2>/dev/null

    # Mostra l'output in diretta
    tail -n +1 -f "$HLOG" 2>/dev/null &
    local TAIL_PID=$!
    disown $TAIL_PID 2>/dev/null

    local WAITED=0 RC=""
    while [ $WAITED -lt $APT_TIMEOUT ]; do
        RC=$(grep -o '__RC=[0-9]*' "$HLOG" | tail -n 1 | cut -d= -f2)
        [ -n "$RC" ] && break
        sleep 3
        WAITED=$((WAITED + 3))
    done

    sleep 1
    kill $TAIL_PID 2>/dev/null
    rm -f "$HSCRIPT"

    [ -z "$RC" ] && RC=124
    return "$RC"
}

# Riavvia gli LXC critici in modo staccato, per ultimi
riavvia_critici() {
    [ -z "$REBOOT_QUEUE" ] && return 0

    echo -e "\n${CYAN}----------------------------------------------------------------${NC}"
    echo -e "${YELLOW}-> Riavvio differito degli LXC critici: ${REBOOT_QUEUE}${NC}"
    echo -e "${YELLOW}   La connessione potrebbe cadere: il riavvio prosegue comunque.${NC}"
    echo -e "${YELLOW}   Log: $REBOOT_LOG${NC}"

    local RS
    RS=$(mktemp /tmp/reboot_critici.XXXXXX)
    cat > "$RS" <<EOF
#!/bin/bash
sleep 3
for ID in $REBOOT_QUEUE; do
    echo "\$(date) - riavvio LXC \$ID"
    pct reboot \$ID
    sleep 10
done
echo __DONE__
EOF
    : > "$REBOOT_LOG"
    setsid nohup bash "$RS" >"$REBOOT_LOG" 2>&1 </dev/null &
    disown $! 2>/dev/null

    # Se la sessione resta viva, mostra l'esito
    local T
    for T in $(seq 1 30); do
        sleep 3
        if grep -q "__DONE__" "$REBOOT_LOG" 2>/dev/null; then
            echo -e "${GREEN}Riavvio degli LXC critici completato.${NC}"
            break
        fi
    done
    rm -f "$RS"
}

# --- FUNZIONE CORE DI AGGIORNAMENTO ---
update_lxc() {
    local LXC_ID=$1
    local NEW_CODENAME=$2
    local OLD_CODENAME=${3:-$CURRENT_CODENAME_DEFAULT}
    local CURRENT_SNAP=""
    local IS_CRIT=false
    [[ " $CRIT_LIST " == *" $LXC_ID "* ]] && IS_CRIT=true

    echo -e "\n${CYAN}----------------------------------------------------------------${NC}"
    if [ "$IS_CRIT" = true ]; then
        echo -e "${GREEN}### Elaborazione LXC ID ${LXC_ID} (CRITICO: riavvio differito) ###${NC}"
    else
        echo -e "${GREEN}### Elaborazione LXC ID ${LXC_ID}... ###${NC}"
    fi

    STATUS=$(pct status $LXC_ID 2>/dev/null)
    if [[ $? -ne 0 || "$STATUS" != "status: running" ]]; then
        echo -e "${RED}SKIPPATO: LXC ${LXC_ID} non trovato o non attivo.${NC}"
        REPORT+=("⏭️ LXC $LXC_ID: saltato (non attivo)")
        return
    fi

    # 1. Gestione Snapshot
    if [ "$SKIP_SNAPSHOT" = false ]; then
        CURRENT_SNAP="${SNAP_PREFIX}_$(date +%Y%m%d_%H%M%S)"
        echo -e "${YELLOW}-> Creazione snapshot: $CURRENT_SNAP...${NC}"
        if ! pct snapshot $LXC_ID "$CURRENT_SNAP" --description "Pre-upgrade Debian script"; then
            echo -e "${RED}ERRORE: Impossibile creare lo snapshot. Interruzione.${NC}"
            REPORT+=("❌ LXC $LXC_ID: snapshot fallito, non aggiornato")
            return
        fi
    fi

    # 2. Gestione Major Upgrade
    if [[ ! -z "$NEW_CODENAME" && "$NEW_CODENAME" != "--clean" && "$NEW_CODENAME" != "--no-snap" ]]; then
        echo -e "${YELLOW}!!! MAJOR UPGRADE: ${OLD_CODENAME} -> ${NEW_CODENAME} !!!${NC}"
        pct exec $LXC_ID -- bash -c "sed -i 's/${OLD_CODENAME}/${NEW_CODENAME}/g' /etc/apt/sources.list"
    fi

    # 3. Esecuzione Aggiornamento (APT staccato dalla sessione)
    echo -e "${YELLOW}-> Esecuzione comandi APT (log: /root/os_update_${LXC_ID}.log)...${NC}"
    esegui_apt "$LXC_ID"
    local RC=$?

    if [[ $RC -eq 0 ]]; then
        echo -e "${GREEN}Aggiornamento completato con successo su LXC ${LXC_ID}.${NC}"

        # Pulizia snapshot se richiesto
        if [[ "$CLEAN_SNAPSHOT" = true && ! -z "$CURRENT_SNAP" ]]; then
            echo -e "${YELLOW}-> Pulizia snapshot temporaneo...${NC}"
            pct delsnapshot $LXC_ID "$CURRENT_SNAP"
        fi

        if [ "$IS_CRIT" = true ]; then
            echo -e "${YELLOW}Riavvio di LXC ${LXC_ID} rimandato a fine processo.${NC}"
            REBOOT_QUEUE+="$LXC_ID "
            REPORT+=("✅ LXC $LXC_ID: aggiornato (riavvio differito)")
        else
            echo -e "${GREEN}Riavvio LXC in corso...${NC}"
            pct reboot $LXC_ID
            REPORT+=("✅ LXC $LXC_ID: aggiornato e riavviato")
        fi
    else
        echo -e "${RED}ERRORE nell'aggiornamento (codice $RC). Snapshot ${CURRENT_SNAP:-nessuno} conservato.${NC}"
        REPORT+=("❌ LXC $LXC_ID: errore APT (codice $RC), nessun riavvio")
    fi
}

# Ordina gli LXC (critici per ultimi), li aggiorna e riavvia i critici alla fine
processa_lista() {
    local CN=$1; shift
    local NORMAL="" CRIT="" ID

    for ID in "$@"; do
        if lxc_critico "$ID"; then CRIT+="$ID "; else NORMAL+="$ID "; fi
    done
    CRIT_LIST="$CRIT"

    if [ -n "$CRIT" ]; then
        echo -e "${YELLOW}LXC critici (processati per ultimi, riavvio differito): $CRIT${NC}"
    fi

    for ID in $NORMAL $CRIT; do
        update_lxc "$ID" "$CN"
    done

    echo -e "\n${CYAN}--- REPORT FINALE ---${NC}"
    local E
    for E in "${REPORT[@]}"; do echo -e "$E"; done

    riavvia_critici
}

# ======================================================================
# LOGICA INTERATTIVA (GUI)
# ======================================================================
if [ "$#" -eq 0 ]; then
    if ! command -v whiptail &> /dev/null; then echo "Errore: whiptail non trovato."; exit 1; fi

    # 1. Scelta Container
    LXC_RAW=$(pct list | awk 'NR>1 {print $1 " [" $3 "] off"}')
    LXC_MENU="BACKGROUND [Esegui_in_background] off ALL [Tutti] off $LXC_RAW"
    CHOICES=$(whiptail --title "Debian Update Manager" \
        --checklist "Seleziona LXC da aggiornare (Spazio per selezionare):" \
        $IFACE_HEIGHT $IFACE_WIDTH $LIST_HEIGHT \
        $LXC_MENU 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then echo -e "\n${YELLOW}Annullato.${NC}"; exit 0; fi
    [ -z "$CHOICES" ] && exit 0
    CHOICES=$(echo "$CHOICES" | tr -d '"')

    IS_PERSISTENT=false
    [[ " $CHOICES " == *" BACKGROUND "* ]] && { IS_PERSISTENT=true; CHOICES=$(echo "$CHOICES" | sed 's/BACKGROUND//g'); }

    [[ " $CHOICES " == *" ALL "* ]] && CHOICES="all"

    # 2. Scelta Opzioni Snapshot
    SNAP_OPTS=$(whiptail --title "Gestione Snapshot" \
        --checklist "Opzioni di sicurezza:" \
        $IFACE_HEIGHT $IFACE_WIDTH 5 \
        "nosnap" "Salta creazione snapshot" OFF \
        "clean" "Rimuovi snapshot se OK" ON 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then echo -e "\n${YELLOW}Annullato.${NC}"; exit 0; fi

    [[ "$SNAP_OPTS" == *"nosnap"* ]] && SKIP_SNAPSHOT=true
    [[ "$SNAP_OPTS" == *"clean"* ]] && CLEAN_SNAPSHOT=true

    # 3. Scelta Tipo Aggiornamento
    UP_TYPE=$(whiptail --title "Tipo di Aggiornamento" \
        --menu "Cosa vuoi fare?" \
        $IFACE_HEIGHT $IFACE_WIDTH 4 \
        "MINOR" "Patch e upgrade attuale" \
        "MAJOR" "Cambio versione (es. bookworm -> trixie)" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then echo -e "\n${YELLOW}Annullato.${NC}"; exit 0; fi

    NEW_CN=""
    if [ "$UP_TYPE" == "MAJOR" ]; then
        NEW_CN=$(whiptail --inputbox "Codename NUOVO (es. trixie):" 10 $IFACE_WIDTH "" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ] || [ -z "$NEW_CN" ]; then echo -e "\n${YELLOW}Annullato.${NC}"; exit 0; fi
    fi

    # Flag per il rilancio CLI
    CLI_ARGS=""
    [ "$SKIP_SNAPSHOT" = true ] && CLI_ARGS="$CLI_ARGS --no-snap"
    [ "$CLEAN_SNAPSHOT" = true ] && CLI_ARGS="$CLI_ARGS --clean"

    CODENAME_PARAM="${NEW_CN:-_minor_}"

    # BACKGROUND: una SOLA esecuzione con tutti gli ID, così l'ordine (critici per ultimi) è sempre rispettato
    if [ "$IS_PERSISTENT" = true ]; then
        > "$LOG_FILE"
        echo -e "🚀 Aggiornamento OS LXC avviato in background alle $(date)\n" >> "$LOG_FILE"

        setsid bash -c '
            LOG="$1"; SCRIPT="$2"; shift 2
            bash "$SCRIPT" "$@" >> "$LOG" 2>&1
            echo -e "\n🏁 Tutti i task completati alle $(date)" >> "$LOG"
        ' _ "$LOG_FILE" "$SCRIPT_FISICO" $CHOICES $CODENAME_PARAM $CLI_ARGS </dev/null >/dev/null 2>&1 &
        disown

        echo -e "${GREEN}🚀 Processo inviato in background con successo!${NC}"
        echo -e "⚠️  Se la connessione Tailscale cade, l'aggiornamento CONTINUERÀ comunque."
        echo -e "--------------------------------------------------------"
        echo -e "📋 Apertura dei log... (Ctrl+C per uscire senza fermare i task)\n"
        sleep 1
        tail -f "$LOG_FILE"
        exit 0
    fi

    # Esecuzione in primo piano
    if [[ "$CHOICES" == "all" ]]; then
        LXC_LIST=$(pct list | awk 'NR>1 && $2=="running" {print $1}')
    else
        LXC_LIST="$CHOICES"
    fi
    processa_lista "$NEW_CN" $LXC_LIST
    exit 0
fi

# ======================================================================
# LOGICA CLI
# ======================================================================
[[ "$*" == *"--no-snap"* ]] && SKIP_SNAPSHOT=true
[[ "$*" == *"--clean"* ]] && CLEAN_SNAPSHOT=true

case "$1" in
    all)
        CN_CLI="$2"
        [[ "$CN_CLI" == "_minor_" || "$CN_CLI" == --* ]] && CN_CLI=""
        LXC_LIST=$(pct list | awk 'NR>1 && $2=="running" {print $1}')
        processa_lista "$CN_CLI" $LXC_LIST
        ;;
    [0-9]*)
        CN_CLI=""
        IDS_CLI=()
        for ARG in "$@"; do
            if [[ "$ARG" =~ ^[0-9]+$ ]]; then
                IDS_CLI+=("$ARG")
            elif [[ ! "$ARG" =~ ^--.*$ && -z "$CN_CLI" ]]; then
                CN_CLI="$ARG"
            fi
        done
        [[ "$CN_CLI" == "_minor_" ]] && CN_CLI=""
        processa_lista "$CN_CLI" "${IDS_CLI[@]}"
        ;;
    *)
        show_help
        ;;
esac

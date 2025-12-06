#!/bin/bash

# Script per aggiornare le Point Releases (Minor) o Versioni Major (Major) di Debian in remoto.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Variabile del nome in codice ATTUALE di default (per aggiornamenti multipli)
# Modifica questo valore per il nome in codice della maggior parte dei tuoi LXC (es. "bookworm" o "trixie")
CURRENT_CODENAME_DEFAULT="trixie"

# Nome in codice della NUOVA versione (Se specificato come secondo argomento)
NEW_CODENAME=$2

# Comando base di aggiornamento
UPDATE_CMD="apt update -y && apt upgrade -y && apt full-upgrade -y && apt autoremove --purge -y"

# --- Funzione di Aggiornamento ---
update_lxc() {
    LXC_ID=$1
    # La variabile $3 (argomento opzionale) è la versione di partenza, usa il default se non specificata.
    CURRENT_CODENAME_USED=${3:-$CURRENT_CODENAME_DEFAULT}
    
    echo -e "${YELLOW}================================================================${NC}"
    echo -e "${GREEN}### Inizio elaborazione LXC ID ${LXC_ID}... ###${NC}"

    STATUS=$(/usr/sbin/pct status $LXC_ID 2>/dev/null)
    if [[ $? -ne 0 || "$STATUS" != "status: running" ]]; then
        echo -e "${RED}ATTENZIONE: LXC ID ${LXC_ID} non trovato, spento o bloccato. SKIPPATO.${NC}"
        return
    fi
    
    # 1. GESTIONE AGGIORNAMENTO MAJOR (Se è stato specificato un nuovo nome in codice)
    if [ ! -z "$NEW_CODENAME" ]; then
        echo -e "${YELLOW}!!! Preparazione Aggiornamento MAJOR: ${CURRENT_CODENAME_USED} -> ${NEW_CODENAME} !!!${NC}"
        
        # Aggiorna i repository nel container da CURRENT_CODENAME_USED a NEW_CODENAME
        MOD_CMD="sed -i 's/${CURRENT_CODENAME_USED}/${NEW_CODENAME}/g' /etc/apt/sources.list"
        echo -e "${YELLOW} -> Modifica Sources.list: ${MOD_CMD}${NC}"
        
        /usr/sbin/pct exec $LXC_ID -- bash -c "$MOD_CMD" | cat
        
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}ERRORE: La modifica di sources.list è fallita.${NC}"
            return
        fi
    fi

    # 2. Esegue i comandi di aggiornamento (Major o Minor)
    echo -e "${YELLOW} -> Esecuzione: ${UPDATE_CMD}${NC}"
    
    /usr/sbin/pct exec $LXC_ID -- bash -c "$UPDATE_CMD" | cat

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Aggiornamento LXC ID ${LXC_ID} completato. Riavvio in corso...${NC}"
        /usr/sbin/pct reboot $LXC_ID
    else
        echo -e "${RED}ERRORE nell'aggiornamento di LXC ID ${LXC_ID}. Controllare l'output sopra.${NC}"
    fi
    echo -e "${YELLOW}================================================================${NC}"
}

# --- Logica di Parsing degli Argomenti ---

if [ "$#" -eq 0 ]; then
    echo "Uso: $0 <all|ID_LXC> [nuovo_nome_in_codice] [vecchio_nome_in_codice]"
    echo "Esempio Minor Upgrade (patch): $0 100"
    echo "Esempio Major Upgrade (tutti da default a nuovo): $0 all chimaera"
    echo "Esempio Major Upgrade (singolo da bookworm a trixie): $0 100 trixie bookworm"
    exit 1
fi

# 2. Assegnazione e Loop

if [[ "$1" == "all" ]]; then
    # Scenario 1: Aggiorna TUTTI (usando il default per la versione corrente)
    echo -e "${GREEN}Trovati tutti i container in esecuzione...${NC}"
    LXC_LIST=$(/usr/sbin/pct list | grep running | awk '{print $1}')
    
    for ID in $LXC_LIST; do
        # Passa solo ID e NUOVO_CODENAME. CURRENT_CODENAME viene preso da DEFAULT
        update_lxc $ID $NEW_CODENAME
    done
    
elif [[ "$1" =~ ^[0-9]+$ ]]; then
    # Scenario 2: Aggiorna SINGOLO ID
    LXC_ID_SINGLE="$1"
    
    echo -e "${GREEN}Inizio aggiornamento per LXC ID ${LXC_ID_SINGLE}...${NC}"

    # Passa ID, NUOVO_CODENAME ($2), e la versione corrente opzionale ($3)
    update_lxc $LXC_ID_SINGLE $NEW_CODENAME $3

else
    # Scenario 3: Argomento non valido
    echo -e "${RED}ERRORE: Argomento non valido. Deve essere 'all' o un ID LXC numerico.${NC}"
    echo "Uso: $0 <all|ID_LXC> [nuovo_nome_in_codice] [vecchio_nome_in_codice]"
    echo "Esempio Major Upgrade (singolo da bookworm a trixie): $0 100 trixie bookworm"
    exit 1
fi

echo -e "${GREEN}Tutte le operazioni completate.${NC}"

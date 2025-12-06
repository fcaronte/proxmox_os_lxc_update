#!/bin/bash

# Script per aggiornare le Point Releases (Minor) o Versioni Major (Major) di Debian in remoto.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Variabile del nome in codice ATTUALE (da cui stai aggiornando)
# ASSICURATI DI MODIFICARE QUESTA VARIABILE PRIMA DI UN MAJOR UPGRADE!
CURRENT_CODENAME="trixie"

# Nome in codice della NUOVA versione (Se specificato come secondo argomento)
NEW_CODENAME=$2

# Comando base di aggiornamento
UPDATE_CMD="apt update -y && apt upgrade -y && apt full-upgrade -y && apt autoremove --purge -y"

# --- Funzione di Aggiornamento ---
update_lxc() {
    LXC_ID=$1
    echo -e "${YELLOW}================================================================${NC}"
    echo -e "${GREEN}### Inizio elaborazione LXC ID ${LXC_ID}... ###${NC}"

    STATUS=$(/usr/sbin/pct status $LXC_ID 2>/dev/null)
    if [[ $? -ne 0 || "$STATUS" != "status: running" ]]; then
        echo -e "${RED}ATTENZIONE: LXC ID ${LXC_ID} non trovato, spento o bloccato. SKIPPATO.${NC}"
        return
    fi
    
    # 1. GESTIONE AGGIORNAMENTO MAJOR (Se è stato specificato un nuovo nome in codice)
    if [ ! -z "$NEW_CODENAME" ]; then
        echo -e "${YELLOW}!!! Preparazione Aggiornamento MAJOR: ${CURRENT_CODENAME} -> ${NEW_CODENAME} !!!${NC}"
        
        # Aggiorna i repository nel container da trixie a chimaera
        MOD_CMD="sed -i 's/${CURRENT_CODENAME}/${NEW_CODENAME}/g' /etc/apt/sources.list"
        echo -e "${YELLOW} -> Modifica Sources.list: ${MOD_CMD}${NC}"
        
        /usr/sbin/pct exec $LXC_ID -- bash -c "$MOD_CMD" | cat
        
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}ERRORE: La modifica di sources.list è fallita.${NC}"
            return
        fi
    fi

    # 2. Esegue i comandi di aggiornamento (Major o Minor)
    echo -e "${YELLOW} -> Esecuzione: ${UPDATE_CMD}${NC}"
    
    # pct exec esegue il comando e | cat forza l'output immediato
    /usr/sbin/pct exec $LXC_ID -- bash -c "$UPDATE_CMD" | cat

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Aggiornamento LXC ID ${LXC_ID} completato. Riavvio in corso...${NC}"
        /usr/sbin/pct reboot $LXC_ID
    else
        echo -e "${RED}ERRORE nell'aggiornamento di LXC ID ${LXC_ID}. Controllare l'output sopra.${NC}"
    fi
    echo -e "${YELLOW}================================================================${NC}"
}

# --- Logica di Parsing degli Argomenti CORRETTA ---

# 1. Controllo base: Deve essere fornito almeno un argomento
if [ "$#" -eq 0 ]; then
    echo "Uso: $0 <all|ID_LXC> [nuovo_nome_in_codice]"
    echo "Esempio Minor Upgrade di un ID: $0 100"
    echo "Esempio Minor Upgrade di tutti: $0 all"
    echo "Esempio Major Upgrade: $0 all chimaera"
    exit 1
fi

# 2. Assegnazione della LXC_LIST in base all'argomento
if [[ "$1" == "all" ]]; then
    echo -e "${GREEN}Trovati tutti i container in esecuzione...${NC}"
    # Se 'all', popola la lista con tutti gli ID running
    LXC_LIST=$(/usr/sbin/pct list | grep running | awk '{print $1}')
elif [[ "$1" =~ ^[0-9]+$ ]]; then
    # Se è un ID numerico, popola la lista solo con quell'ID
    LXC_LIST="$1"
    echo -e "${GREEN}Inizio aggiornamento per LXC ID ${LXC_LIST}...${NC}"
else
    # Se non è 'all' né un ID numerico
    echo -e "${RED}ERRORE: Argomento non valido. Deve essere 'all' o un ID LXC numerico.${NC}"
    echo "Uso: $0 <all|ID_LXC> [nuovo_nome_in_codice]"
    echo "Esempio Minor Upgrade di un ID: $0 100"
    echo "Esempio Minor Upgrade di tutti: $0 all"
    echo "Esempio Major Upgrade: $0 all chimaera"
    exit 1
fi

# Esegue la funzione di aggiornamento per ogni ID nella lista
for ID in $LXC_LIST; do
    update_lxc $ID
done

echo -e "${GREEN}Tutte le operazioni completate.${NC}"

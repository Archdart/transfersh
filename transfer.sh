#!/bin/bash

# Colori ANSI
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# Input utente
read -p "Inserisci l'IP della macchina di destinazione: " DEST_IP
read -p "Inserisci la porta SSH (default 22): " SSH_PORT
read -p "Inserisci il nome utente SSH: " SSH_USER
read -p "Inserisci il percorso della cartella da trasferire: " SOURCE_PATH
read -p "Inserisci il percorso di destinazione sul computer remoto: " DEST_PATH
read -p "Vuoi usare una chiave SSH temporanea per evitare di digitare la password? (s/n): " USE_KEY

# Default porta
SSH_PORT=${SSH_PORT:-22}
SOURCE_PATH="${SOURCE_PATH%/}"

# Percorso chiave temporanea
KEY_PATH="$HOME/.ssh/temp_migrazione"
KEY_PUB="$KEY_PATH.pub"

# Se l'utente vuole la chiave temporanea
if [[ "$USE_KEY" =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Generazione chiave SSH temporanea...${RESET}"
    ssh-keygen -t rsa -f "$KEY_PATH" -N "" || {
        echo -e "${RED}Errore durante la generazione della chiave.${RESET}"
        exit 1
    }

    echo -e "${YELLOW}Copia della chiave sulla macchina remota...${RESET}"
    PUB_KEY_CONTENT=$(cat "$KEY_PUB")
    ssh -p "$SSH_PORT" "$SSH_USER@$DEST_IP" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUB_KEY_CONTENT' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" || {
        echo -e "${RED}Errore durante la copia della chiave pubblica. Verifica la connessione e i permessi.${RESET}"
        exit 1
    }

    SSH_OPTIONS="-i $KEY_PATH -p $SSH_PORT"
else
    SSH_OPTIONS="-p $SSH_PORT"
fi

# Verifica esistenza cartella locale
if [ ! -d "$SOURCE_PATH" ]; then
    echo -e "${RED}Errore: La cartella di origine '$SOURCE_PATH' non esiste!${RESET}"
    exit 1
fi

# BRASATURA (modifica proprietario e permessi) SULLA CARTELLA DI PARTENZA
echo -e "${YELLOW}Imposto proprietario e permessi per evitare problemi di accesso...${RESET}"
sudo chown -R "$USER":"$USER" "$SOURCE_PATH" || {
    echo -e "${RED}Errore nel cambiare proprietario. Controlla i permessi di sudo.${RESET}"
    exit 1
}
sudo chmod -R 777 "$SOURCE_PATH" || {
    echo -e "${RED}Errore nel cambiare i permessi.${RESET}"
    exit 1
}
echo -e "${GREEN}Proprietario e permessi impostati correttamente.${RESET}"

# Verifica connessione SSH
echo -e "${YELLOW}Verifica della connessione SSH a $SSH_USER@$DEST_IP sulla porta $SSH_PORT...${RESET}"
if ! ssh $SSH_OPTIONS "$SSH_USER@$DEST_IP" "exit" &>/dev/null; then
    echo -e "${RED}Errore: Impossibile connettersi. Controlla le credenziali o la rete.${RESET}"
    exit 1
fi

# Verifica o creazione cartella di destinazione
echo -e "${YELLOW}Verifica esistenza cartella remota...${RESET}"
if ! ssh $SSH_OPTIONS "$SSH_USER@$DEST_IP" "[ -d '$DEST_PATH' ]"; then
    echo -e "${YELLOW}La cartella di destinazione non esiste. Tentativo di creazione...${RESET}"
    ssh $SSH_OPTIONS "$SSH_USER@$DEST_IP" "mkdir -p '$DEST_PATH'" || {
        echo -e "${RED}Errore: Permessi insufficienti per creare '$DEST_PATH'. Verifica l'accesso dell'utente remoto.${RESET}"
        exit 1
    }
fi

# Conteggio file sorgente (escludendo .sock e .lock)
echo "Conteggio file nella sorgente (escludendo *.sock e *.lock)..."
SOURCE_LIST=$(mktemp)
find "$SOURCE_PATH" -type f ! -name '*.sock' ! -name '*.lock' > "$SOURCE_LIST"
SOURCE_COUNT=$(wc -l < "$SOURCE_LIST")
echo "File totali nella sorgente (esclusi .sock e .lock): $SOURCE_COUNT"

read -n 1 -s -r -p "Premi un tasto per continuare con il trasferimento..."

# Trasferimento con esclusione e verbose per errori
echo "Avvio rsync con barra di avanzamento e output dettagliato..."
rsync -avz -vv --exclude='*.sock' --exclude='*.lock' --info=progress2 -e "ssh $SSH_OPTIONS" "$SOURCE_PATH/" "$SSH_USER@$DEST_IP:$DEST_PATH/"
RSYNC_EXIT=$?

if [ "$RSYNC_EXIT" -ne 0 ]; then
    echo -e "${RED}Errore durante il trasferimento con rsync. Codice: $RSYNC_EXIT${RESET}"
    rm -f "$SOURCE_LIST"
    exit 1
fi

# Conteggio file remoto (escludendo .sock e .lock)
echo "Conteggio file sul computer remoto (escludendo *.sock e *.lock)..."
REMOTE_LIST=$(mktemp)
ssh $SSH_OPTIONS "$SSH_USER@$DEST_IP" "find '$DEST_PATH' -type f ! -name '*.sock' ! -name '*.lock'" > "$REMOTE_LIST"
REMOTE_COUNT=$(wc -l < "$REMOTE_LIST")
echo "File totali sul destinatario (esclusi .sock e .lock): $REMOTE_COUNT"

# Verifica finale
if [ "$SOURCE_COUNT" -eq "$REMOTE_COUNT" ]; then
    echo -e "${GREEN}Trasferimento completato con successo! I file corrispondono.${RESET}"
else
    echo -e "${RED}ATTENZIONE: Il numero di file non corrisponde!${RESET}"
    echo -e "${RED}Sorgente: $SOURCE_COUNT | Destinazione: $REMOTE_COUNT${RESET}"
    rm -f "$SOURCE_LIST" "$REMOTE_LIST"
    exit 1
fi

# Pulizia file temporanei
rm -f "$SOURCE_LIST" "$REMOTE_LIST"

# Pulizia chiave temporanea se usata
if [[ "$USE_KEY" =~ ^[Ss]$ ]]; then
    read -p "Vuoi rimuovere la chiave SSH temporanea (locale e remota)? (s/n): " CLEAN_KEY
    if [[ "$CLEAN_KEY" =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}Rimozione della chiave locale...${RESET}"
        rm -f "$KEY_PATH" "$KEY_PUB"

        echo -e "${YELLOW}Rimozione della chiave remota da authorized_keys...${RESET}"
        ssh -p "$SSH_PORT" "$SSH_USER@$DEST_IP" "sed -i \"/$(echo $PUB_KEY_CONTENT | sed 's/\//\\\//g')/d\" ~/.ssh/authorized_keys"

        echo -e "${GREEN}Chiave temporanea rimossa.${RESET}"
    else
        echo -e "${YELLOW}La chiave SSH temporanea è ancora presente.${RESET}"
        echo -e "${YELLOW}Puoi rimuoverla manualmente se lo desideri:${RESET}"
        echo -e "  ${GREEN}rm -f $KEY_PATH $KEY_PUB${RESET}"
        echo -e "  ${GREEN}ssh -p $SSH_PORT $SSH_USER@$DEST_IP 'nano ~/.ssh/authorized_keys'${RESET}"
    fi
fi

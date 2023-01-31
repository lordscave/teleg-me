#!/bin/bash
CHAIN_ID=euphoria-1
AURA_HOME="/tmp/aurad$(date +%s)"
RANDOM_KEY="randomvalidatorkey"
DENOM=ueaura
MAXBOND=3600000000 # 3600 eaura
MINCOMMISSION="0.05"

GENTX_SUBMISSION_START=$(date -u -d '2022-07-07T12:00:00.000Z' +'%s')
GENTX_SUBMISSION_DEADLINE=$(date -u -d '2022-07-11T02:00:00.000Z' +'%s')

now=$(date -u +'%s')

if [ $now -lt $GENTX_SUBMISSION_START ]; then
    echo 'Gentx submission not started yet'
    exit 1
fi

if [ $now -gt $GENTX_SUBMISSION_DEADLINE ]; then
    echo 'Gentx submission is closed'
    exit 1
fi

GENTX_FILE=$(find ./$CHAIN_ID/gentx -iname "*.json")
FILES_COUNT=$(find ./$CHAIN_ID/gentx -iname "*.json" | wc -l)
LEN_GENTX=$(echo ${#GENTX_FILE})

if [ $FILES_COUNT -gt 1 ]; then
    echo 'Invalid! found more than 1 json file'
    exit 1
fi

if [ $LEN_GENTX -eq 0 ]; then
    echo "gentx file not found."
    exit 1
else
    set -e

    echo "GentxFile::::"
    echo $GENTX_FILE

    denom=$(jq -r '.body.messages[0].value.denom' $GENTX_FILE)
    if [ $denom != $DENOM ]; then
        echo "invalid denom"
        exit 1
    fi

    amount=$(jq -r '.body.messages[0].value.amount' $GENTX_FILE)

    if [ $amount -ne $MAXBOND ]; then
        echo "bonded amount is different with 3600eaura: $amt != $MAXBOND"
        exit 1
    fi

    commission=$(jq -r '.body.messages[0].commission.rate' $GENTX_FILE)
    out=$(echo "$commission < $MINCOMMISSION" | bc -q)
    if [ $out = 1  ]; then
        echo "commission is low: $commission < $MINCOMMISSION"
        exit 1
    fi
    echo "...........Init Aura node.............."

    git clone https://github.com/aura-nw/aura
    cd aura
    git checkout euphoria
    make build
    chmod +x ./build/aurad
    
    ./build/aurad keys add $RANDOM_KEY --keyring-backend test --home $AURA_HOME

    ./build/aurad init --chain-id $CHAIN_ID validator --home $AURA_HOME

    echo "..........Fetching genesis......."

    # rm -rf $AURA_HOME/config/genesis.json
    # curl -s https://raw.githubusercontent.com/aura-nw/testnets/main/$CHAIN_ID/pre-genesis.json >$AURA_HOME/config/genesis.json

    sed -i "s/\"stake\"/\"ueaura\"/g" $AURA_HOME/config/genesis.json
    
    GENACC=$(jq -r '.body.messages[0].delegator_address' ../$GENTX_FILE)

    echo $GENACC

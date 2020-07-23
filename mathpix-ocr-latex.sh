#!/usr/bin/env bash

MATHPIX_ID=
MATHPIX_KEY=
PASTE_CMD=${PASTE_CMD:-"wl-paste"}
COPY_CMD=${COPY_CMD:-"wl-copy"}

function debug() {
    echo ">> $1" >&2
}

function error() {
    local message="$1"
    local code="$2"

    notify "Error" "${message}"
    debug "Error: ${message}; exiting with status ${code}"

    exit "${code}"
}

function notify() {
    local message="$1"
    local body="$2"

    notify-send "mathpix-ocr-latex: $message" "$body"
}

function image_to_latex() {
    local data="$1"
    local mode="$2"

    local response=$(
        curl --silent https://api.mathpix.com/v3/${mode} -X POST \
            -H "app_id: ${MATHPIX_ID}" \
            -H "app_key: ${MATHPIX_KEY}" \
            -H "Content-Type: application/json" \
            --data "{\"src\":\"data:image/jpeg;base64,'$data'\"}")

    if [ ! -n "$response" ]; then
        echo "connection error"
        return 1
    fi

    debug "received response $response"

    local error=$(echo $response | jq -r .error)
    local latex=$(echo $response | jq -r .latex)

    if [ -n "$error" ]; then
        echo "$error"
        return 1
    fi

    # return latex equation
    echo $latex
}

function main() {
    if [ ! -n "$MATHPIX_ID" ]; then
        error "no mathpix id provided" 1
    fi

    if [ ! -n "$MATHPIX_KEY" ]; then
        error "no mathpix key provided" 1
    fi

    local mime_type=$($PASTE_CMD | file - -b --mime-type)

    debug "detected mime: $mime_type"

    if [[ ! $mime_type =~ "image" ]]; then
        error "invalid mime type: ${mime_type}" 1
    fi

    local clipboard_data_b64=$($PASTE_CMD | base64 -w 0)
    latex=$(image_to_latex "$clipboard_data_b64" "latex")

    if [ $? -ne 0 ]; then
        error "error converting image to latex: ${latex}" 1
    fi

    echo $latex | $COPY_CMD

    notify 'equation copied' "$latex"
}

# install error handler
trap 'error "" ${LINENO}' ERR

source ~/.secrets

main

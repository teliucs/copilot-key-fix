#!/bin/bash

# Fedora Assistant
# A simple GUI wrapper that sends your query to a Hugging Face model
# and displays the AI’s response using Zenity dialogs.

# --- Configuration ---
# This script can read the Hugging Face token from:
#   1. The environment variable HF_TOKEN, OR
#   2. A local .env file in the same directory, containing:
#        HF_TOKEN=your_token_here

MODEL="meta-llama/Meta-Llama-3-8B-Instruct"
ENV_FILE="$(dirname "$0")/.env"

# --- Load token from .env if available ---
if [ -f "$ENV_FILE" ]; then
    # Load key-value pairs (only lines with "KEY=value")
    export $(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$ENV_FILE" | xargs)
fi

# --- Check dependencies ---
for cmd in curl jq zenity; do
    if ! command -v $cmd &>/dev/null; then
        zenity --error --title="Missing Dependency" \
            --text="The command '$cmd' is required but not installed."
        exit 1
    fi
done

# --- Verify token ---
if [ -z "$HF_TOKEN" ]; then
    zenity --error --title="Missing Token" \
        --text="No Hugging Face token found.\n\nPlease set it either by:\n  export HF_TOKEN='your_token_here'\n\nor by creating a .env file containing:\n  HF_TOKEN=your_token_here"
    exit 1
fi

# --- Prompt user ---
PROMPT=$(zenity --entry --title="Fedora Assistant" --text="Ask anything:")
[ -z "$PROMPT" ] && exit

# --- Send request to Hugging Face API ---
RESPONSE=$(curl -s https://router.huggingface.co/v1/chat/completions \
  -H "Authorization: Bearer $HF_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
        \"model\": \"$MODEL\",
        \"messages\": [
            {\"role\": \"user\", \"content\": \"$PROMPT\"}
        ],
        \"stream\": false
      }")

# --- Parse and display ---
if echo "$RESPONSE" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
    REPLY=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')
    zenity --info --title="Answer" --text="$REPLY" --width=400 --height=300
else
    zenity --error --title="API Error" --text="API response:\n$RESPONSE"
fi


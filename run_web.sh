#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="$(dirname "$0")/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

URL=""
KEY=""

while IFS= read -r line || [[ -n "$line" ]]; do
    key_name="${line%%=*}"
    value="${line#*=}"
    if [[ "$key_name" == "SUPABASE_URL" ]]; then
        URL="${value#\"}"
        URL="${URL%\"}"
    elif [[ "$key_name" == "SUPABASE_PUBLISHABLE_KEY" ]]; then
        KEY="${value#\"}"
        KEY="${KEY%\"}"
    fi
done < "$ENV_FILE"

if [[ -z "$URL" ]]; then
    echo "Error: SUPABASE_URL is not set in .env"
    exit 1
fi

if [[ -z "$KEY" ]]; then
    echo "Error: SUPABASE_PUBLISHABLE_KEY is not set in .env"
    exit 1
fi

echo "Running with SUPABASE_URL=$URL"
flutter run -d chrome --dart-define=SUPABASE_URL="$URL" --dart-define=SUPABASE_PUBLISHABLE_KEY="$KEY"
exit $?

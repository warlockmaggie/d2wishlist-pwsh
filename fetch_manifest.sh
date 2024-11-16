#!/usr/bin/env bash

# This doesn't matter for fetching the Manifest, but Bungie's API requires something be sent
API_KEY="vootvoot"

TMP_MANIFEST="$(mktemp)"

curl -s \
    -o "${TMP_MANIFEST}" \
    -H "X-API-Key: ${API_KEY}" \
    https://www.bungie.net/Platform/Destiny2/Manifest/

echo -n "Current manifest version: "
jq -r .Response.version "${TMP_MANIFEST}"

MANIFEST_PATH=$(jq -r .Response.mobileWorldContentPaths.en "${TMP_MANIFEST}")

echo "=== Fetching manifest archive..."
curl -o manifest.sqlite.zip "https://www.bungie.net${MANIFEST_PATH}"

echo "=== Extracting manifest database..."
unzip manifest.sqlite.zip
SQLITE_FILE="$(basename ${MANIFEST_PATH})"
mv "./$SQLITE_FILE" ./manifest.sqlite3

rm manifest.sqlite.zip
rm "${TMP_MANIFEST}"

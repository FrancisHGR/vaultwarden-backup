#!/bin/bash

# !IMPORTANT! set the environment variables in the .env file!

echo "$(TZ=CET date "+%H:%M:%S") - Starting Vaultwarden vault backup. (If login fails, please set environment variables)"
echo "$(TZ=CET date "+%H:%M:%S") - Attempting Login"

# Checking current status of bw cli config, especially whether the server adress has been set
STATUS="$(bw status | jq -r '.status')"

# if not already logged in or unauthenticated still, login into Vaultwarden server
if [[ "$STATUS" == "unauthenticated" ]]; then
  bw config server "$SERVER_HOST_URL" && echo
  bw login --apikey > /dev/null 2>&1
fi

# unlocking the Session
echo "$(TZ=CET date "+%H:%M:%S") - Attempting session unlock"
export BW_SESSION=$(bw unlock --raw $BW_PASSWORD)

# If session unlock fails, error message. Possible to add also notifaction via email or other messenger here
if [ "$BW_SESSION" == "" ]; then
    echo "$(TZ=CET date "+%H:%M:%S") - Error: Session unlock failed"
    bw logout
    exit 1
fi;

# preparing the location for backups as well as file name
if [ ! -d $BACKUP_LOCATION ]; then
  mkdir -p $BACKUP_LOCATION;
fi

EXPORT_OUTPUT_BASE="bw_export_"
TIMESTAMP=$(TZ=CET date "+%Y-%m-%d_%H-%M")
ENC_OUTPUT_FILE=$BACKUP_LOCATION/$EXPORT_OUTPUT_BASE$TIMESTAMP.enc

# individual user vault backup export and encryption
echo "$(TZ=CET date "+%H:%M:%S") - Exporting inidivual user vault, encrypted with env password"
bw --raw --session $BW_SESSION export --format json | openssl enc -aes-256-cbc -pbkdf2 -iter 1000000 -k $BW_PASSWORD -out $ENC_OUTPUT_FILE

# if organization vault exists, also backup export and encryption
if [[ -n "$BW_ORGID" ]]; then
  echo "$(TZ=CET date "+%H:%M:%S") - Exporting organization vault, encrypted with env password"
  TIMESTAMP=$(TZ=CET date "+%Y-%m-%d_%H-%M")
  EXPORT_OUTPUT_END="_ORG"
  ENC_OUTPUT_FILE=$BACKUP_LOCATION/$EXPORT_OUTPUT_BASE$TIMESTAMP$EXPORT_OUTPUT_END.enc
  bw --raw export --organizationid 46ef9e5f-9aea-4d86-b31d-5c0b4ae888d3 --format json | openssl enc -aes-256-cbc -pbkdf2 -iter 1000000 -k $BW_PASSWORD -out $ENC_OUTPUT_FILE
fi

# logout
echo "$(TZ=CET date "+%H:%M:%S") - Logout"
bw logout
unset BW_SESSION

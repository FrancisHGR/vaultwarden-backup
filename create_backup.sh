#!/bin/bash

# !IMPORTANT! set the environment variables in the .env file!

echo "$(TZ=CET date "+%H:%M:%S") - Starting Vaultwarden vault backup on $(TZ=CET date "+%d.%m.%Y"). (If login fails, please set environment variables)" | tee /proc/1/fd/1
echo "$(TZ=CET date "+%H:%M:%S") - Attempting Login" | tee /proc/1/fd/1

# Checking current status of bw cli config, especially whether the server adress has been set
STATUS="$(bw status | jq -r '.status')"

# if not already logged in or unauthenticated still, login into Vaultwarden server
if [[ "$STATUS" == "unauthenticated" ]]; then
  bw config server "$SERVER_HOST_URL" && echo
  bw login --apikey > /dev/null 2>&1
fi

# unlocking the Session
echo "$(TZ=CET date "+%H:%M:%S") - Attempting session unlock" | tee /proc/1/fd/1
export BW_SESSION=$(bw unlock --raw $BW_PASSWORD)

# If session unlock fails, error message. Possible to add also notifaction via email or other messenger here
if [ "$BW_SESSION" == "" ]; then
    echo "$(TZ=CET date "+%H:%M:%S") - Error: Session unlock failed" | tee /proc/1/fd/1
    bw logout
    echo
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
echo "$(TZ=CET date "+%H:%M:%S") - Exporting inidivual user vault, encrypted with env password" | tee /proc/1/fd/1
bw --raw --session $BW_SESSION export --format json | openssl enc -aes-256-cbc -pbkdf2 -iter 1000000 -k $BW_PASSWORD -out $ENC_OUTPUT_FILE

# if organization vault exists, also backup export and encryption
if [[ -n "$BW_ORGID" ]]; then
  echo "$(TZ=CET date "+%H:%M:%S") - Exporting organization vault, encrypted with env password" | tee /proc/1/fd/1
  TIMESTAMP=$(TZ=CET date "+%Y-%m-%d_%H-%M")
  EXPORT_OUTPUT_END="_ORG"
  ENC_OUTPUT_FILE=$BACKUP_LOCATION/$EXPORT_OUTPUT_BASE$TIMESTAMP$EXPORT_OUTPUT_END.enc
  bw --raw export --organizationid 46ef9e5f-9aea-4d86-b31d-5c0b4ae888d3 --format json | openssl enc -aes-256-cbc -pbkdf2 -iter 1000000 -k $BW_PASSWORD -out $ENC_OUTPUT_FILE
fi

# logout
echo "$(TZ=CET date "+%H:%M:%S") - Logout" | tee /proc/1/fd/1
bw logout
unset BW_SESSION 

# Delete all backups that are older then environment variable $max_keep_days - but keep one weekly for the last $max_keep_months months

if [[ -n "$max_keep_days" ]]; then

echo "$(TZ=CET date "+%H:%M:%S") - Deleting all backups older than $max_keep_days days while keeping one weekly backup for the last $max_keep_months months" | tee /proc/1/fd/1

# recalculate retention periods
WEEKS_TO_KEEP=$(($max_keep_months*4))     # Number of weeks

# Temporary file to store files to keep
TMP_KEEP_LIST="/tmp/keep_files.txt"
> "$TMP_KEEP_LIST" # Clear the file if it exists

# Get today's date in YYYY-MM-DD format
TODAY=$(date +%Y-%m-%d)

# Step 1: Keep all backups from the last $DAYS_TO_KEEP days
find "$BACKUP_LOCATION" -type f -name '*' -newermt "$(date -d "$max_keep_days days ago" +%Y-%m-%d)" -print >> "$TMP_KEEP_LIST"

# Step 2: Keep the two newest backups per week for the previous $WEEKS_TO_KEEP weeks
for ((i=1; i<=WEEKS_TO_KEEP; i++)); do
    WEEK_START=$(date -d "$((i * 7)) days ago" +%Y-%m-%d)       # Start of the week
    NEXT_WEEK_START=$(date -d "$(((i - 1) * 7)) days ago" +%Y-%m-%d) # Start of the next week

    # Find files modified during that week and get the two newest ones
    find "$BACKUP_LOCATION" -type f -name '*' -newermt "$WEEK_START" ! -newermt "$NEXT_WEEK_START" -printf '%T@ %p\n' | \
    sort -nr | \
    head -n 2 | \
    cut -d' ' -f2- >> "$TMP_KEEP_LIST"
done

# Step 3: Delete all other files not in the keep list
find "$BACKUP_LOCATION" -type f -name '*' | grep -vFf "$TMP_KEEP_LIST" | while read -r file; do
    echo "$(TZ=CET date "+%H:%M:%S") - Deleting: $file" | tee /proc/1/fd/1
    rm -- "$file"
done

# Cleanup temporary file
rm "$TMP_KEEP_LIST"

echo "$(TZ=CET date "+%H:%M:%S") - Cleanup complete. Kept all backups for the last $max_keep_days days and the two newest backups per week for the previous $max_keep_months months." | tee /proc/1/fd/1

fi

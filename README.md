## Encrypted json export as backup for vaultwarden (own-hosted bitwarden)

### tl;dr
```
- clone repo, populate .env file and run docker compose up -d
- run the create_backup.sh from within the container or from outside:
docker exec -ti vaultwarden-backup /app-data/create_backup.sh
```

### I. Background
- uses the bitwarden cli (https://bitwarden.com/help/cli/) within a docker container to export an encrypted json version of the password vault
- main purpose is a very easily accessible list of all your passwords, in case of emergency when there is no running vaultwarden instance available (hardware failure, OS screwed up, internet down etc.)
- result is an 256 bit encrypted list of the user and organization vaults that can be then stored as a copy on a seperate drive, machine or remotely in a cloud storage
- first and most important backup should be of the whole docker vaultwarden container (most important is the sqlite database) or a snapshot etc, ideally on a different machine (https://github.com/ttionya/vaultwarden-backup or https://github.com/Bruceforce/vaultwarden-backup)

### II. Instructions
- ! You need a running and working vaultwarden instance that is reachable from the vaultwarden-backup container !
- clone the repository: git clone https://github.com/FrancisHGR/vaultwarden-backup
- edit the .env.example file with all your personal details and rename it to .env
- run the container via "docker compose -up -d" from the same folder where you downloaded this repo in
- container needs not run on the same machine like the vaultwarden instance, however vaultwarden instance needs to be reachable 
- (Alternativly just build the image and use it without docker compose or use it in Portainer)
- To create an encrypted backup, execute the create_backup.sh script from within the container or via the oneliner from the docker host: docker exec -ti vaultwarden-backup /app-data/create_backup.sh
- Note: If there is an BW_ORGID environment variable provided, it will automatically also backup your organization vault
- To decrypt a backup into readable json, excute the decrypt_backup.sh script followed by the path to the backup file from within the container, e.g. "./decrypt_backup.sh /app-data/backups/bw_export_2025-02-25_17-43.enc" or via the oneliner from the docker host: docker exec -ti vaultwarden-backup /app-data/decrypt_backup.sh /app-data/backups/bw_export_2025-02-25_17-43.enc
- Set up repeating backups of your vault via e.g. a cronjob => daily backup at 3 am "0 3 * * * docker exec vaultwarden-backup /app-data/create_backup.sh"

### III. Configuration
**.env**
- read the comments in the .env.example file
- all data for the environment variables in the .env file can be found when you are logged into your vaultwarden instances webpage under settings
- APP_DATA_LOCATION and BACKUP_LOCATION don't need to be edited. You can find your backups then directly in the repository folder under "backups"
  
**docker-compose.yml**
- edit the first part before the colon to reflect the location where you have saved all of this repos files "/root/docker/vaultwarden-backup:${APP_DATA_LOCATION}"

### IV. further readings
- thanks to the inspirations, especially to https://github.com/tangowithfoxtrot/bw-docker?tab=readme-ov-file for inspiration on the docker image and some backgrounds on the BW CLI usage https://binarypatrick.dev/posts/bitwarden-automated-backup/

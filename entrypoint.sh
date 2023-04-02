#!/bin/sh

#  _____ _  __
# |  ___| |/ /  Finn Krestel, 2023.
# | |_  | ' /   https://github.com/FinnKrestel
# |  _| | . \
# |_|   |_|\_\  FinnKrestel/docker-fritzbox-backup

# Welcome message
echo "
───────────────────────────────────────

    ███████╗██╗  ██╗
    ██╔════╝██║ ██╔╝
    ███████╗█████╔╝
    ██╔════╝██╔═██╗
    ██║     ██║  ██╗
    ╚═╝     ╚═╝  ╚═╝
    Brought to you by Finn Krestel
───────────────────────────────────────"
echo "
For my other projects visit:
https://github.com/FinnKrestel

───────────────────────────────────────"
echo "
UID/GID
───────────────────────────────────────
uid:    $(id -u)
gid:    $(id -g)
───────────────────────────────────────"

echo ""

CRON=${CRON:-0 4 * * *}
echo "$CRON /fritzbox-config-downloader.sh" > /crontab
crontab /crontab
crond -f
#!/usr/bin/env bash

#  _____ _  __
# |  ___| |/ /  Finn Krestel, 2023.
# | |_  | ' /   https://github.com/FinnKrestel
# |  _| | . \
# |_|   |_|\_\  FinnKrestel/docker-fritzbox-backup

# Backup directory
BACKUP_DIR="/backups"

# Configuration
RETENTION_DAYS=${RETENTION_DAYS:-14}
HOST=${HOST:-fritz.box}
USERNAME=$USERNAME
PASSWORD=$PASSWORD
EXPORT_PASSWORD=${EXPORT_PASSWORD:-admin}
EXPORT_FILENAME="$BACKUP_DIR/${EXPORT_FILENAME:-FritzBox.export}"
SECOND_PASSWORD=$SECOND_PASSWORD

curlCmd="curl -ksm 20"

if [[ $HOST != https://* ]]; then
	HOST="https://${HOST}"
fi

# For the older remote access we need HTTP auth
curlCmd="${curlCmd} -u ${USERNAME}:${PASSWORD}"

# login on FRITZ!Box
login=$($curlCmd "${HOST}/login_sid.lua")
if [ "$?" != "0" -o -z "${login}" ]; then
	echo "Can't connect to FRITZ!Box at ${HOST}!"
	exit 2
elif printf "${login}" | grep -q "401 Unauthorized (ERR_ACCESS_DENIED)"; then
    echo "Wrong password!"
    exit 1
fi

SID=$(printf "${login}" | sed -n "s|.*<SID>\([0-9a-f]\{16\}\)</SID>.*|\1|p")
if [ -z "${SID}" ]; then
	echo "Unknown FRITZ!Box version or wrong HOST (${HOST})!\nError:"
	echo "${login}"
	exit 2
elif [ "${SID}" = "0000000000000000" ]; then # 16 zeros
	# Distinguish boxes before Fritz!OS 5.50
	if printf "${login}" | grep -q "<iswriteaccess>"; then
		loginType=1
		PASSWORD="${SECOND_PASSWORD}"
	else
		loginType=2
	fi

	if [ -z "${PASSWORD}" ]; then
		echo "Password required!"
		exit 1
	fi

	challenge=$(echo "${login}" | sed -n "s|.*<Challenge>\([0-9a-f]\{8\}\)</Challenge>.*|\1|p")
	if [ -z "${challenge}" ]; then
		echo "Login does not return a challenge for FRITZ!Box at ${HOST}! Sorry, I'm done here..."
		echo "${login}"
		exit 2
	fi

	response=$(printf "${challenge}-${PASSWORD}" | iconv -f utf-8 -t utf-16le | md5sum -b | sed 's|^\(.* \)\?\([A-Fa-f0-9]\+\)\( .*\)\?|\2|g')
	case "${loginType}" in
		1) login=$($curlCmd -d "login:command/response=${challenge}-${response}" -d "getpage=../html/login_sid.xml" "${HOST}/cgi-bin/webcm") ;;
		2) login=$($curlCmd -d "response=${challenge}-${response}" -d "USERNAME=${USERNAME}" "${HOST}/login_sid.lua") ;;
	esac

	SID=$(echo "${login}" | sed -n "s|.*<SID>\([0-9a-f]\{16\}\)</SID>.*|\1|p")
	if [ -z "${SID}" ]; then
		echo "Login with password does not return an SID on FRITZ!Box at ${HOST}! Sorry, I'm done here..."
		echo "${login}"
		exit 2
	elif [ "${SID}" = "0000000000000000" ]; then
		echo "Login on FRITZ!Box at ${HOST} failed. Wrong password?"
		exit 3
	fi
fi

# Download the backup file (with or without an export password)
if [ -n "${EXPORT_PASSWORD}" ]; then
	$curlCmd -fF "sid=${SID}" -F "ImportExportPassword=${EXPORT_PASSWORD}" -F "ConfigExport=" "${HOST}/cgi-bin/firmwarecfg" -o "${EXPORT_FILENAME}"
else
	$curlCmd -fF "sid=${SID}" -F "ConfigExport=" "${HOST}/cgi-bin/firmwarecfg" -o "${EXPORT_FILENAME}"
fi
if [ "$?" != "0" ]; then
	echo "Downloading backup of FRITZ!Box at ${HOST} failed!"
	echo "Deleting file!"
	rm -f "${EXPORT_FILENAME}"
	exit 2
elif ! head -n 1 "${EXPORT_FILENAME}" | grep -q "^\*\*\*\* FRITZ!Box .* CONFIGURATION EXPORT$"; then
	echo "Downloaded does not appear to be a FRITZ!Box backup file!?"
	echo "Deleting file!"
	rm "${EXPORT_FILENAME}"
	exit 2
elif ! tail -n 1 "${EXPORT_FILENAME}" | grep -q "^\*\*\*\* END OF EXPORT .* \*\*\*\*$"; then
	echo "Download is incomplete!"
	echo "Deleting file!"
	rm "${EXPORT_FILENAME}"
	exit 4
fi

# Logout if necessary
case "${loginType}" in
	1) $curlCmd -d "logout=logout" -d "sid=${SID}" "${HOST}/login_sid.lua" -o /dev/null ;;
	2) $curlCmd -d "security:command/logout=logout" -d "sid=${SID}"  -d "getpage=../html/login_sid.xml" "${HOST}/cgi-bin/webcm" -o /dev/null ;;
esac

filesize=$(wc -c < "${EXPORT_FILENAME}")
filesize=$(printf $filesize | tr -d ' ')
echo "Downloaded backup file to ${EXPORT_FILENAME} (${filesize} bytes)!"

# Delete old backups
if $RETENTION_DAYS > -1; then
	OLD_BACKUPS=$(ls -1 $BACKUP_DIR/*.export | wc -l)
	if [ $OLD_BACKUPS -gt $RETENTION_DAYS ]; then
		find $BACKUP_DIR -name "*.export" -mtime +$RETENTION_DAYS -delete
	fi
fi

exit 0

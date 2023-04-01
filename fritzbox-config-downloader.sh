#!/usr/bin/env bash

# Check if we have advanced getopt
advancedGetopt=0
getopt -T > /dev/null 2>&1
if [ $? -eq 4 ]; then
	advancedGetopt=1
fi

# Prints usage
print_usage() {
	echo "Usage: ${0} [arguments]"
	echo "Arguments:"
	if [ $advancedGetopt -eq 1 ]; then
		hostArg="-h, --host"
		usernameArg="-u, --username"
		passwordArg="-p, --password"
		exportPasswordArg="-e, --export-password"
		outputFileArg="-o, --output-file"
		remoteArg="-r, --remote"
		secondPasswordArg="-s, --second-password"
	else
		hostArg="-h"
		usernameArg="-u"
		passwordArg="-p"
		exportPasswordArg="-e"
		outputFileArg="-o"
		remoteArg="-r"
		secondPasswordArg="-s"
	fi
	echo "${hostArg} HOST\tThe host of the Fritz!Box. Defaults to fritz.box."
	echo "${usernameArg} USERNAME\tThe username for the Fritz!Box. Default is no username."
	echo "${passwordArg} PASSWORD\tThe password for the Fritz!Box. Default is no password."
	echo "${exportPasswordArg}[=PASSWORD]\tThe password for the backup file. Default is admin. If the argument is not present, no password will be used."
	echo "${outputFileArg} OUTPUT_FILE\tThe downloaded backup will be written to this file. Default is FritzBox.export."
	echo "${remoteArg}\tUse remote access to connect to the Fritz!Box."
	echo "${secondPasswordArg}\tSecond password for older Fritz!OS versions. Default is no password."
}

# Set some defaults
host="fritz.box"
username=""
password=""
exportPassword=""
exportFilename="FritzBox.export"
remoteAccess=0
secondPassword=""

# Parse the arguments
if [ $advancedGetopt -eq 1 ]; then
	args=`getopt -o h:u:p:e::o:rs: --long "host:,username:,password:,export-password::,output-file:,remote,second-password:,help" -n 'fritzbox-config-downloader' -- "$@"`
else
	args=`getopt h:u:p:e::o:rs: $*`
fi
if [ $? -ne 0 ]; then
	echo "Invalid arguments!"
	print_usage
	exit 1
fi
eval set -- "${args}"

# Extract the parsed arguments
while true ; do
	case "${1}" in
		-h|--host)
			case "${2}" in
				"") shift 2 ;;
				*) host=$2 ; shift 2 ;;
			esac ;;
		-u|--username)
			case "${2}" in
				"") shift 2 ;;
				*) username=$2 ; shift 2 ;;
			esac ;;
		-p|--password)
			case "${2}" in
				"") shift 2 ;;
				*) password=$2 ; shift 2 ;;
			esac ;;
		-e|--export-password)
			case "${2}" in
				"") exportPassword="admin" ; shift 2 ;;
				*) exportPassword=$2 ; shift 2 ;;
			esac ;;
		-o|--output-file)
			case "${2}" in
				"") shift 2 ;;
				*) exportFilename=$2 ; shift 2 ;;
			esac ;;
		-r|--remote) remoteAccess=1 ; shift ;;
		-s|--second-password)
			case "${2}" in
				"") shift 2 ;;
				*) secondPassword=$2 ; shift 2 ;;
			esac ;;
		--help) print_usage ; exit 0 ;;
		--) shift ; break ;;
		*) echo "Unknown argument ${1}!" ; exit 1 ;;
	esac
done

curlCmd="curl -ksm 20"
# Use HTTPS and HTTP auth for remote access
if [ "${remoteAccess}" = "1" ]; then
	if [[ $host != https://* ]]; then
		host="https://${host}"
	fi
	# For the older remote access we need HTTP auth
	curlCmd="${curlCmd} -u ${username}:${password}"
fi

# login on Fritz!Box
login=$($curlCmd "${host}/login_sid.lua")
if [ "$?" != "0" -o -z "${login}" ]; then
	echo "Can't connect to Fritz!Box at ${host}!"
	exit 2
elif printf "${login}" | grep -q "401 Unauthorized (ERR_ACCESS_DENIED)"; then
    echo "Wrong password!"
    exit 1
fi

SID=$(printf "${login}" | sed -n "s|.*<SID>\([0-9a-f]\{16\}\)</SID>.*|\1|p")
if [ -z "${SID}" ]; then
	echo "Unknown Fritz!Box version or wrong host (${host})!\nError:"
	echo "${login}"
	exit 2
elif [ "${SID}" = "0000000000000000" ]; then # 16 zeros
	# Distinguish boxes before Fritz!OS 5.50
	if printf "${login}" | grep -q "<iswriteaccess>"; then
		loginType=1
		if [ "${remoteAccess}" = "1" ]; then
			password="${secondPassword}"
		fi
	else
		loginType=2
	fi

	if [ -z "${password}" ]; then
		echo "Password required!"
		exit 1
	fi

	challenge=$(echo "${login}" | sed -n "s|.*<Challenge>\([0-9a-f]\{8\}\)</Challenge>.*|\1|p")
	if [ -z "${challenge}" ]; then
		echo "Login does not return a challenge on Fritz!Box at ${host}! Sorry, I'm done here..."
		echo "${login}"
		exit 2
	fi

	if hash md5sum 2>/dev/null; then
		md5command="md5sum -b"
	elif hash md5 2>/dev/null; then
		md5command="md5"
	elif hash openssl 2> /dev/null; then
		md5command="openssl dgst -md5"
	else
		echo "Missing dependency! Please make sure that one of the following commands is installed on your system: md5sum, md5 or openssl"
		exit 1
	fi
	response=$(printf "${challenge}-${password}" | iconv -f utf-8 -t utf-16le | $md5command | sed 's|^\(.* \)\?\([A-Fa-f0-9]\+\)\( .*\)\?|\2|g')
	case "${loginType}" in
		1) login=$($curlCmd -d "login:command/response=${challenge}-${response}" -d "getpage=../html/login_sid.xml" "${host}/cgi-bin/webcm") ;;
		2) login=$($curlCmd -d "response=${challenge}-${response}" -d "username=${username}" "${host}/login_sid.lua") ;;
	esac

	SID=$(echo "${login}" | sed -n "s|.*<SID>\([0-9a-f]\{16\}\)</SID>.*|\1|p")
	if [ -z "${SID}" ]; then
		echo "Login with password does not return an SID on Fritz!Box at ${host}! Sorry, I'm done here..."
		echo "${login}"
		exit 2
	elif [ "${SID}" = "0000000000000000" ]; then
		echo "Login on Fritz!Box at ${host} failed. Wrong password?"
		exit 3
	fi
fi

# Download the backup file (with or without an export password)
if [ -n "${exportPassword}" ]; then
	$curlCmd -fF "sid=${SID}" -F "ImportExportPassword=${exportPassword}" -F "ConfigExport=" "${host}/cgi-bin/firmwarecfg" -o "${exportFilename}"
else
	$curlCmd -fF "sid=${SID}" -F "ConfigExport=" "${host}/cgi-bin/firmwarecfg" -o "${exportFilename}"
fi
if [ "$?" != "0" ]; then
	echo "Downloading backup of Fritz!Box at ${host} failed!"
	echo "Deleting file!"
	rm -f "${exportFilename}"
	exit 2
elif ! head -n 1 "${exportFilename}" | grep -q "^\*\*\*\* FRITZ!Box .* CONFIGURATION EXPORT$"; then
	echo "Downloaded does not appear to be a Fritz!Box backup file!?"
	echo "Deleting file!"
	rm "${exportFilename}"
	exit 2
elif ! tail -n 1 "${exportFilename}" | grep -q "^\*\*\*\* END OF EXPORT .* \*\*\*\*$"; then
	echo "Download is incomplete!"
	echo "Deleting file!"
	rm "${exportFilename}"
	exit 4
fi

# Logout if necessary
case "${loginType}" in
	1) $curlCmd -d "logout=logout" -d "sid=${SID}" "${host}/login_sid.lua" -o /dev/null ;;
	2) $curlCmd -d "security:command/logout=logout" -d "sid=${SID}"  -d "getpage=../html/login_sid.xml" "${host}/cgi-bin/webcm" -o /dev/null ;;
esac

filesize=$(wc -c < "${exportFilename}")
filesize=$(printf $filesize | tr -d ' ')
echo "Downloaded backup file to ${exportFilename} (${filesize} bytes)!"
exit 0

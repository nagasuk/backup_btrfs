#!/usr/bin/env bash

set -ue

#===== Local Parameter =====#
readonly -- thisScriptDir="$(cd "$(dirname "${0}")"; pwd)"
readonly -- libDir="${thisScriptDir}/libbackup_btrfs.d"

#===== Include Libraries =====#
source "${libDir}/libmessages.sh"
source "${libDir}/libdaemon.sh" "${libDir}"

#===== Option Variables =====#
declare -- commDir='/run/backup_btrfsd'
declare -- accessGrp

#===== Setting Trap =====#
function kill_all_children()
{
	local -ir _pid="${1}"
	local -ir _orig_pid="${2}"

	local -- _child

	while read _child
	do
		kill_all_children "${_child}" "${_orig_pid}"
	done < <(ps --ppid "${_pid}" --no-heading | awk '{ print $1 }')

	(( _pid != _orig_pid )) && kill "${_pid}" &>/dev/null
}
function atexit()
{
	set +e
	kill_all_children "${$}" "${$}"
	test -d "${commDir}" && rm -rf "${commDir}"
}
trap atexit EXIT TERM
trap 'trap - EXIT TERM; atexit; exit 1' INT PIPE

#===== Main Process =====#
## Temporally variables
declare -- touchedFile
declare -- pipePath

## Option Analyzing
while (( ${#} > 0 ))
do
	case "${1}" in
		'-c' )
			shift
			commDir="${1}"
			;;

		'-g' )
			shift
			accessGrp="${1}"
			;;

		* )
			error <<< "Invalid argument of ${1}."
			exit 1
			;;
	esac
	shift
done

if [[ ${accessGrp:-UNDEF} == UNDEF ]]
then
	error <<< '"-g" must be set.'
	exit 1
fi

message <<EOS
Option summary is as follows:
 -c ${commDir}
 -g ${accessGrp}
EOS

# Create directory for communication
if [ ! -d "${commDir}" ]
then
	message <<< "Create a directory for connection at ${commDir}."

	rm -rf "${commDir}"
	install -m 770 -o 'root' -g "${accessGrp}" -d "${commDir}"
fi

# Main loop
while read touchedFile
do
	pipePath="${commDir}/${touchedFile}"

	if [ ! -p "${pipePath}" ]
	then
		rm -f "${pipePath}"
		continue
	fi

	message <<< "Start connection through \"${pipePath}\"."
	backup_worker "${pipePath}" &

done < <(inotifywait -e 'create' -m --format '%f' "${commDir}")


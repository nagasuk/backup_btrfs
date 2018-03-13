#!/usr/bin/env bash

set -ue

#===== Local Parameters =====#
readonly -- workDir='.backup_btrfs_work'
readonly -- wholeSnapshot='wholeSnapshot'
readonly -- tempSnapshot="$(date +%y%m%d%H%M%S)"
readonly -- thisScriptDir="$(cd "$(dirname "${0}")"; pwd)"
readonly -- libDir="${thisScriptDir}/libbackup_btrfs.d"

#===== Include Libraries =====#
source "${libDir}/libclient.sh" "${libDir}"
source "${libDir}/libmessages.sh"

#===== Option Variables =====#
declare -- configFilePath
declare -- userWhenSsh
declare -- commDir


#===== Trap Setting =====#
function atexit()
{
	local -- _backupSrcPath
	local -- _localSnapshotPath

	for _backupSrcPath in "${BACKUP_SRC_LIST[@]}"
	do
		_localSnapshotPath="${_backupSrcPath}/${workDir}/${tempSnapshot}"
		test -e "${_localSnapshotPath}" && \
			btrfs subvolume delete "${_localSnapshotPath}" &>/dev/null
	done

	message <<< 'Finalization to finish backup process complete.'
}
trap atexit EXIT
trap 'trap - EXIT; atexit; exit 1' INT PIPE TERM

#===== Main Process =====#
## Temporally use variables
declare -- tgtPathAndRemoteCmd
declare -- backupSrcPath
declare -- backupTgtPath
declare -- remoteCmd
declare -- pipePath
declare -- targetPathInfo
declare -i numBackups
declare -- isWholeBackup

## Analizing arguments
while (( ${#} > 0 ))
do
	case "${1}" in
		'-c' )
			shift
			commDir="${1}"
			;;

		'-C' )
			shift
			configFilePath="${1}"
			;;

		'-u' )
			shift
			userWhenSsh="${1}"
			;;
		* )
			error <<< "Invalid argument of \"${1}\""
			exit 1
			;;
	esac

	shift
done

if [[ (${commDir:-UNDEF} == UNDEF) || (${configFilePath:-UNDEF} == UNDEF) || (${userWhenSsh:-UNDEF} == UNDEF) ]]
then
	error <<< 'All of "-c", "-C", and "-u" must be set.'
	exit 1
fi

message <<EOS
Option summary is as follows:
 -c ${commDir}
 -C ${configFilePath}
 -u ${userWhenSsh}
EOS

## Load configurations
source "${configFilePath}"

for ((i = 0; i < ${#BACKUP_SRC_LIST[@]}; i++))
do
	backupSrcPath="${BACKUP_SRC_LIST[${i}]}"
	tgtPathAndRemoteCmd="$(remote_command_setter "${BACKUP_TGT_LIST[${i}]}" "${userWhenSsh}")"
	backupTgtPath="${tgtPathAndRemoteCmd#*;}"
	remoteCmd="${tgtPathAndRemoteCmd%;*}"
	isWholeBackup='false'

	message <<< "Start main process for ${backupSrcPath}."

	## Create working directory at local
	test ! -e "${backupSrcPath}/${workDir}" && btrfs subvolume create "${backupSrcPath}/${workDir}" &>/dev/null

	## Create connection and get information of backup target path 
	### Check whether daemon is running.
	if ${remoteCmd} test ! -d "${commDir}"
	then
		declare -- errMessage="Backup daemon is not running at ${commDir}."

		if [ -z "${remoteCmd}" ]
		then
			errMessage="Backup daemon is not running at ${commDir}."
		else
			errMessage="Backup daemon is not running at ${commDir} in remote host."
		fi

		error <<< "${errMessage}"
		unset errMessage

		exit 1
	fi

	### Establish connection
	pipePath="${commDir}/$(basename "${backupSrcPath}").$(mktemp -u 'XXXXXX')"
	${remoteCmd} mkfifo "${pipePath}"
	message <<< 'Established connection with backup daemon.'

	### Send backup target path
	${remoteCmd} backup_btrfs-redirect_helper.sh -w "${pipePath}" <<< "${backupTgtPath}"
	message <<< 'Sent target path for backup to backup daemon.'

	### Receive information backup target path
	targetPathInfo="$(${remoteCmd} backup_btrfs-redirect_helper.sh -r "${pipePath}")"
	message <<< 'Received information of target path from backup daemon.'

	## Select backup type
	test -z "${targetPathInfo}" && isWholeBackup='true'

	numBackups="$(wc -l <<< "${targetPathInfo}")"
	(( numBackups >= ${NUM_HOLD_BACKUPS} )) && isWholeBackup='true'

	if [[ ${isWholeBackup} == true ]]
	then
		message <<< 'Start main process for whole backup.'
		${remoteCmd} backup_btrfs-redirect_helper.sh -w "${pipePath}" <<< 'whole'
		whole_backup       "${backupSrcPath}" "${pipePath}" "${remoteCmd}"

	else

		message <<< 'Start main process for incremental backup.'
		${remoteCmd} backup_btrfs-redirect_helper.sh -w "${pipePath}" <<< 'incremental'
		incremental_backup "${backupSrcPath}" "${pipePath}" "${remoteCmd}"
	fi
done

message <<< 'All process for backup complete.'


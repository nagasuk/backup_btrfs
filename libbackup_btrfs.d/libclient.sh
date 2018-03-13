# Include guard
test -n "${__LIBCLIENT_SH__:-}" && return 0
readonly -- __LIBCLIENT_SH__='DEFINED'

#===== Local Parameters =====#
readonly -- thisLibDir="${1}"

#===== Include Libraries =====#
source "${thisLibDir}/libmessages.sh"

function remote_command_setter()
{
	# ssh://kohei@lcarsnet.pgw.jp:22//home/kohei
	local -r _backupTgtPathWithAddr="${1}"
	local -r _userWhenSsh="${2}"

	local -- _addrWithPort
	local -a _addrAndPort
	local -- _addr
	local -i _port=-1

	local -- _remoteCmd
	local -- _backupTgtPath

	if [[ ${_backupTgtPathWithAddr} =~ ^ssh://.+$ ]]
	then
		_addrWithPort="$(echo -n "${_backupTgtPathWithAddr}" | sed -e 's/^ssh:\/\/\([^/]\+\).\+$/\1/g')"
		_addrAndPort=( $(echo -n ${_addrWithPort} | tr ':' ' ') )
		_addr="${_addrAndPort[0]}"
		[[ ${#_addrAndPort[@]} == 2 ]] && _port="${_addrAndPort[1]}"

		if ((_port != -1))
		then
			_remoteCmd="sudo -u ${_userWhenSsh} ssh -p ${_port} ${_addr}"

		else
			_remoteCmd="sudo -u ${_userWhenSsh} ssh ${_addr}"
		fi

		_backupTgtPath="$(echo "${_backupTgtPathWithAddr}" | sed -e 's/^ssh:\/\/[^/]\+\/\(.\+\)$/\1/g')"

	else
		_remoteCmd=''
		_backupTgtPath="${_backupTgtPathWithAddr}"
	fi

	echo -n "${_remoteCmd};${_backupTgtPath}"
}

function whole_backup()
{
	local -r  _backupSrcPath="${1}"
	local -r  _pipePath="${2}"
	local -r  _remoteCmd="${3}"

	local -r  _localSnapshotPath="${_backupSrcPath}/${workDir}/${wholeSnapshot}"

	if [ -e "${_localSnapshotPath}" ]
	then
		btrfs subvolume delete "${_localSnapshotPath}" &>/dev/null
		message <<< 'Removed previous snapshot for whole backup in local.'
	fi

	btrfs subvolume snapshot -r "${_backupSrcPath}" "${_localSnapshotPath}" &>/dev/null
	sync
	message <<< 'Created snapshot in local.'

	message <<< 'Start sending data stream of backup files to backup daemon...'
	btrfs send "${_localSnapshotPath}" 2>/dev/null | \
		${_remoteCmd} backup_btrfs-redirect_helper.sh -w "${_pipePath}"
	message <<< 'Sending data stream is done.'
}

function incremental_backup()
{
	local -r _backupSrcPath="${1}"
	local -r _pipePath="${2}"
	local -r _remoteCmd="${3}"

	local -r _localWholeSnapshotPath="${_backupSrcPath}/${workDir}/${wholeSnapshot}"
	local -r _localTempSnapshotPath="${_backupSrcPath}/${workDir}/${tempSnapshot}"

	btrfs subvolume snapshot -r "${_backupSrcPath}" "${_localTempSnapshotPath}" &>/dev/null
	sync
	message <<< 'Created snapshot in local.'

	message <<< 'Start sending data stream of backup files to backup daemon...'
	btrfs send -p "${_localWholeSnapshotPath}" "${_localTempSnapshotPath}" 2>/dev/null | \
		${_remoteCmd} backup_btrfs-redirect_helper.sh -w "${_pipePath}"
	message <<< 'Sending data stream is done.'
}


# Include guard
test -n "${__LIBDAEMON_SH__:-}" && return 0
readonly -- __LIBDAEMON_SH__='DEFINED'

#===== Local Parameters =====#
readonly -- thisLibDir="${1}"

#===== Include Libraries =====#
source "${thisLibDir}/libmessages.sh"

function backup_worker()
{
	local -r _pipePath="${1}"

	local -- _backupTgtPath
	local -- _backupType

	## 1st: Receive target path
	_backupTgtPath="$(cat "${_pipePath}")"

	message <<-EOS
	@${_pipePath}
	Receive backup target path of "${_backupTgtPath}"
	EOS


	## 2nd: Send information of target path
	message <<-EOS
	@${_pipePath}
	Send information of the path at "${_backupTgtPath}"
	EOS

	ls -1 "${_backupTgtPath}/" 2>/dev/null > "${_pipePath}"

	## 3rd: Receive backup type
	_backupType="$(cat "${_pipePath}")"

	message <<-EOS
	@${_pipePath}
	Receive backup type of "${_backupType}".
	EOS

	## Do backup
	case "${_backupType}" in
		'whole' )
			whole_backup_receiver "${_pipePath}" "${_backupTgtPath}"
			;;

		'incremental' )
			incremental_backup_receiver "${_pipePath}" "${_backupTgtPath}"
			;;

		* )
	error <<-EOS
	@${_pipePath}
	Invalid backup type.
	Do nothing...
	EOS
			;;
	esac


	## Finalize named pipe
	rm -f "${_pipePath}"

	message <<-EOS
	@${_pipePath}
	This connection is finished.
	Finalizing of "${_pipePath}" is completed.
	EOS
}

function whole_backup_receiver()
{
	local -r _pipePath="${1}"
	local -r _backupTgtPath="${2}"

	local -ar _oldTgtBackups=( $(ls -1 "${_backupTgtPath}/" 2>/dev/null) )

	message <<-EOS
	@${_pipePath}
	Start whole backup process.
	EOS

	if [[ ${#_oldTgtBackups[@]} > 0 ]]
	then

	message <<-EOS
	@${_pipePath}
	Save previous whole/incremental backup data.
	EOS

		mkdir "${_backupTgtPath}/old"
		echo "${_oldTgtBackups[@]}" | tr ' ' '\n' | xargs -n1 -I'$' btrfs property set "${_backupTgtPath}/"'$' ro false &>/dev/null
		echo "${_oldTgtBackups[@]}" | tr ' ' '\n' | xargs -n1 -I'$' mv "${_backupTgtPath}/"{'$','old/'}
	fi

	message <<-EOS
	@${_pipePath}
	Wait arrival of backup data stream and start backup...
	EOS

	btrfs receive "${_backupTgtPath}" &>/dev/null < "${_pipePath}"

	message <<-EOS
	@${_pipePath}
	The backup is complete.
	EOS

	if [[ ${#_oldTgtBackups[@]} > 0 ]]
	then

	message <<-EOS
	@${_pipePath}
	Remove previous whole/incremental backup data.
	EOS

		echo "${_oldTgtBackups[@]}" | tr ' ' '\n' |  xargs -n1 -I'{}' btrfs subvolume delete "${_backupTgtPath}/old/"'{}' &>/dev/null
		rmdir "${_backupTgtPath}/old"
	fi
}

function incremental_backup_receiver()
{
	local -r _pipePath="${1}"
	local -r _backupTgtPath="${2}"

	message <<-EOS
	@${_pipePath}
	Start incremental backup process.
	EOS

	message <<-EOS
	@${_pipePath}
	Wait arrival of backup data stream and start backup...
	EOS

	btrfs receive "${_backupTgtPath}" &>/dev/null < "${_pipePath}"

	message <<-EOS
	@${_pipePath}
	The backup is complete.
	EOS
}


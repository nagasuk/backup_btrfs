# Include guard
test -n "${__LIBMESSAGES_SH__:-}" && return 0
readonly -- __LIBMESSAGES_SH__='DEFINED'

function messageCaster()
{
	local --  _line
	local -r  _prefix="${1}"
	local -ri _num_indent=${#_prefix}+2

	read _line
	echo "${_prefix}: ${_line}"

	while IFS= read _line
	do
		for ((i = 0; i < _num_indent; i++))
		do
			echo -n ' '
		done

		echo "${_line}"
	done
}

function message()
{
	messageCaster 'Infor'
}

function error()
{
	messageCaster 'Error' >&2
}


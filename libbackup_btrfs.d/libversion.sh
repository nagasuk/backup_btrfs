# Include guard
test -n "${__LIBVERSION_SH__:-}" && return 0
readonly -- __LIBVERSION_SH__='DEFINED'

#===== Local Parameters =====#
declare -ri majorVersion='1'
declare -ri minorVersion='0'
readonly -- revision='0'
readonly -- version="${majorVersion}.${minorVersion}_${revision}"

function printVersion()
{
	local -r toolName="${1}"

	echo -n "${toolName} Ver. ${version}"
}


#!/usr/bin/env bash

readonly -- direction="${1}"
readonly -- filepath="${2}"

case "${direction}" in
	'-r' )
		cat "${filepath}"
		;;
	'-w' )
		cat - > "${filepath}"
		;;
esac


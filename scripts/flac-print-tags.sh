#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	echo "${script_name} (audx) - Recursively print FLAC metadata tags." >&2

	echo "Usage: ${script_name} [flags] top-dir" >&2
	echo "Option flags:" >&2
	echo "  -h --help        - Show this help and exit." >&2
	echo "  -v --verbose     - Verbose execution." >&2
	echo "  -g --debug       - Extra verbose execution." >&2
	echo "Send bug reports to: Geoff Levand <geoff@infradead.org>." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="hvg"
	local long_opts="help,verbose,debug"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-h | --help)
			usage=1
			shift
			;;
		-v | --verbose)
			verbose=1
			shift
			;;
		-g | --debug)
			verbose=1
			debug=1
			set -x
			shift
			;;
		--)
			shift
			if [[ ${1} ]]; then
				top_dir="${1}"
				shift
			fi
			if [[ ${*} ]]; then
				set +o xtrace
				echo "${script_name}: ERROR: Got extra args: '${*}'" >&2
				usage
				exit 1
			fi
			break
			;;
		*)
			echo "${script_name}: ERROR: Internal opts: '${*}'" >&2
			exit 1
			;;
		esac
	done
}

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}):\[\e[0m\] '
script_name="${0##*/}"

SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}" && pwd)"}
SECONDS=0

source "${SCRIPTS_TOP}/lib.sh"

trap "on_exit 'failed'" EXIT
set -e
set -o pipefail

process_opts "${@}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

check_top_dir "${top_dir}"
top_dir="$(realpath -e "${top_dir}")"

metaflac="${metaflac:-metaflac}"

check_program "metaflac" "${metaflac}"

readarray path_array < <((cd "${top_dir}" && find . -type f) | sort)

echo "${script_name}: INFO: Processing ${#path_array[@]} files." >&2

for path in "${path_array[@]}"; do
	path="${path//[$'\r\n']}"
	path="${path:2}"

	flac_print_tags "${top_dir}/${path}"
done

trap "on_exit 'Success'" EXIT
exit 0

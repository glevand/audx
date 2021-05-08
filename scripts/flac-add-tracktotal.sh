#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	{
		echo "${script_name} - Add FLAC tracktotal metadata tags."
		echo "Usage: ${script_name} [flags] top-dir"
		echo "Option flags:"
		echo "  -d --dry-run     - Dry run, don't modify files."
		echo "  -h --help        - Show this help and exit."
		echo "  -v --verbose     - Verbose execution."
		echo "  -g --debug       - Extra verbose execution."
		echo "Info:"
		echo "  ${script_name} (@PACKAGE_NAME@) version @PACKAGE_VERSION@"
		echo "  @PACKAGE_URL@"
		echo "  Send bug reports to: Geoff Levand <geoff@infradead.org>."
	} >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="dhvg"
	local long_opts="dry-run,help,verbose,debug"

	dry_run=''
	usage=''
	verbose=''
	debug=''

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		# echo "${FUNCNAME[0]}: (${#}) '${*}'"
		case "${1}" in
		-d | --dry-run)
			dry_run=1
			shift
			;;
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
			top_dir="${1:-}"
			if [[ ${top_dir} ]]; then
				shift
			fi
			extra_args="${*}"
			break
			;;
		*)
			echo "${script_name}: ERROR: Internal opts: '${*}'" >&2
			exit 1
			;;
		esac
	done
}

flac_add_tracktotal() {
	local top=${1}
	local p_array
	local path

	readarray -t p_array < <( find "${top}" -type d | sort \
		|| { echo "${script_name}: ERROR: p_array find failed, function=${FUNCNAME[0]:-main}, line=${LINENO}, result=${?}" >&2; \
		kill -SIGUSR1 $$; } )

	echo "${script_name}: INFO: Processing ${#p_array[@]} directories." >&2

	for path in "${p_array[@]}"; do
		local f_array
		readarray -t f_array < <( find "${path}" -maxdepth 1 -type f -name '*.flac' | sort \
			|| { echo "${script_name}: ERROR: p_array find failed, function=${FUNCNAME[0]:-main}, line=${LINENO}, result=${?}" >&2; \
			kill -SIGUSR1 $$; } )

		if [[ ${#f_array[@]} -ne 0 ]]; then
			echo "${FUNCNAME[0]}: ${path}: ${#f_array[@]} tracks." >&2

			local file
			for file in "${f_array[@]}"; do
				metaflac_retag "${file}" "TRACKTOTAL" "${#f_array[@]}" 'add'
			done
		fi
	done
}

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '

script_name="${0##*/}"

SECONDS=0
start_time="$(date +%Y.%m.%d-%H.%M.%S)"

SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}" && pwd)"}

tmp_dir=''

trap "on_exit 'Failed'" EXIT
trap 'on_err ${FUNCNAME[0]:-main} ${LINENO} ${?}' ERR
trap 'on_err SIGUSR1 ? 3' SIGUSR1

set -eE
set -o pipefail
set -o nounset

source "${SCRIPTS_TOP}/audx-lib.sh"

process_opts "${@}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

if [[ ${extra_args} ]]; then
	set +o xtrace
	echo "${script_name}: ERROR: Got extra args: '${extra_args}'" >&2
	usage
	exit 1
fi

check_top_dir "${top_dir}"
top_dir="$(realpath -e "${top_dir}")"

metaflac="${metaflac:-metaflac}"

check_program "metaflac" "${metaflac}"

flac_add_tracktotal "${top_dir}"

trap "on_exit 'Success'" EXIT
exit 0

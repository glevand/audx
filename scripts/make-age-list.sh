#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	{
		echo "${script_name} - Create an age list of collection."
		echo "Usage: ${script_name} [flags] top-dir"
		echo "Option flags:"
		echo "  -o --out-file - Playlist output file. Default: '${out_file}'."
		echo "  -h --help     - Show this help and exit."
		echo "  -v --verbose  - Verbose execution."
		echo "  -g --debug    - Extra verbose execution."
		echo "Info:"
		echo "  ${script_name} (@PACKAGE_NAME@) version @PACKAGE_VERSION@"
		echo "  @PACKAGE_URL@"
		echo "  Send bug reports to: Geoff Levand <geoff@infradead.org>."
	} >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="o:hvg"
	local long_opts="out-file:,help,verbose,debug"

	out_file=''
	usage=''
	verbose=''
	debug=''

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		# echo "${FUNCNAME[0]}: (${#}) '${*}'"
		case "${1}" in
		-o | --out-file)
			out_file="${2}"
			shift 2
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

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '

script_name="${0##*/}"

SECONDS=0
start_time="$(date +%Y.%m.%d-%H.%M.%S)"

SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}" && pwd)"}

tmp_dir=''

trap "on_exit 'Failed'" EXIT
trap 'on_err ${FUNCNAME[0]:-main} ${LINENO} ${?}' ERR
set -eE
set -o pipefail
set -o nounset

source "${SCRIPTS_TOP}/audx-lib.sh"

process_opts "${@}"

out_file="${out_file:-/tmp/audx-age-${start_time}.lst}"

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

(cd "${top_dir}" && find . -type f -name '*.flac' -exec ls -l --time-style='+%Y.%m.%d' {} \;) \
	| grep -E --only-matching '[[:digit:]]{4}(\.[[:digit:]]{2}){2} .*$' \
	| sort > "${out_file}"

echo "${script_name}: INFO: Age list in '${out_file}'" >&2

trap "on_exit 'Success'" EXIT
exit 0

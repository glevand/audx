#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	{
		echo "${script_name} - Rename files based on FLAC metadata tags."
		echo "Usage: ${script_name} [flags] top-dir"
		echo "Option flags:"
		echo "  -a --various - Use 'Various Artists' logic."
		echo "  -d --dry-run - Dry run, don't rename files."
		echo "  -h --help    - Show this help and exit."
		echo "  -v --verbose - Verbose execution."
		echo "  -g --debug   - Extra verbose execution."
		echo "Info:"
		echo "  ${script_name} (@PACKAGE_NAME@) version @PACKAGE_VERSION@"
		echo "  @PACKAGE_URL@"
		echo "  Send bug reports to: Geoff Levand <geoff@infradead.org>."
	} >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="adhvg"
	local long_opts="various,dry-run,help,verbose,debug"

	various=''
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
		-a | --various)
			various=1
			shift
			;;
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
move_dir="${top_dir}.moves"

metaflac="${metaflac:-metaflac}"
check_program "metaflac" "${metaflac}"

readarray -t files_array < <(find "${top_dir}" -type f | sort \
	|| { echo "${script_name}: ERROR: files_array find failed, function=${FUNCNAME[0]:-main}, line=${LINENO}, result=${?}" >&2; \
	kill -SIGUSR1 $$; } )

echo "${script_name}: INFO: Processing ${#files_array[@]} files." >&2

for file in "${files_array[@]}"; do
	if [[ ${various} || "${file}" == *'Various Artists/'* ]]; then
		dest="$(flac_meta_path 'various' "${file}")"
	else
		dest="$(flac_meta_path 'artist' "${file}")"
	fi
	move_file "${file}" "${move_dir}/${dest}"
done

trap "on_exit 'Success'" EXIT
exit 0

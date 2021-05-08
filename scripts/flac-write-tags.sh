#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	{
		echo "${script_name} - Write new FLAC metadata tags using --tag, or --tag-name and --tag-value."
		echo "Usage: ${script_name} [flags] top-dir"
		echo "Option flags:"
		echo "  -t --tag         - Full tag 'NAME=VALUE'. Default='${tag_full}'."
		echo "  -n --tag-name    - Tag Name. Default='${tag_name}'."
		echo "  -l --tag-value   - Tag data. Default='${tag_value}'.'"
		echo "  -h --help        - Show this help and exit."
		echo "  -v --verbose     - Verbose execution."
		echo "  -d --dry-run     - Dry run, don't modify files."
		echo "  -g --debug       - Extra verbose execution."
		echo "Common TAGs:"
		echo "  ARTIST"
		echo "  ALBUM"
		echo "  TITLE"
		echo "  TRACKNUMBER"
		echo "  TRACKTOTAL"
		echo "Info:"
		echo "  ${script_name} (@PACKAGE_NAME@) version @PACKAGE_VERSION@"
		echo "  @PACKAGE_URL@"
		echo "  Send bug reports to: Geoff Levand <geoff@infradead.org>."
	} >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="t:n:l:hvdg"
	local long_opts="tag:,tag-name:,tag-value:,help,verbose,dry-run,debug"

	tag_full=''
	tag_name=''
	tag_value=''
	usage=''
	verbose=''
	debug=''

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		# echo "${FUNCNAME[0]}: (${#}) '${*}'"
		case "${1}" in
		-t | --tag)
			tag_full="${2}"
			shift 2
			;;
		-n | --tag-name)
			tag_name="${2}"
			shift 2
			;;
		-l | --tag-value)
			tag_value="${2}"
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
		-d | --dry-run)
			dry_run=1
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

if [[ ! ${top_dir} ]]; then
	echo "${script_name}: ERROR: No top-dir given." >&2
	usage
	exit 1
fi

top_dir="$(realpath -e "${top_dir}")"

if [[ ! -d "${top_dir}" && ! -f "${top_dir}" ]]; then
	echo "${script_name}: ERROR: Bad top-dir: '${top_dir}'" >&2
	usage
	exit 1
fi

metaflac="${metaflac:-metaflac}"

check_program "metaflac" "${metaflac}"

if [[ ${tag_full} ]]; then
	if [[ ${tag_name} ]]; then
		echo "${script_name}: ERROR: Use --tag-full OR --tag-name option." >&2
		usage
		exit 1
	fi
	if [[ ${tag_value} ]]; then
		echo "${script_name}: ERROR: Use --tag-full OR --tag-value option." >&2
		usage
		exit 1
	fi
	check_opt '--tag' "${tag_full}"
	
	declare -A pair

	flac_split_tag "${tag_full}" pair
	
	tag_name="${pair[name]}"
	tag_value="${pair[value]}"
else
	check_opt '--tag OR --tag-name' "${tag_name}"
	check_opt '--tag OR --tag-data' "${tag_data}"
fi

if [[ -d "${top_dir}" ]]; then
	readarray -t path_array < <((cd "${top_dir}" && find . -type f) | sort \
		|| { echo "${script_name}: ERROR: path_array find failed, function=${FUNCNAME[0]:-main}, line=${LINENO}, result=${?}" >&2; \
		kill -SIGUSR1 $$; } )

	echo "${script_name}: INFO: Processing ${#path_array[@]} files." >&2

	for path in "${path_array[@]}"; do
		path="${path:2}"

		if ! flac_check_file "${top_dir}/${path}" 'quiet'; then
			continue
		fi
		metaflac_retag "${top_dir}/${path}" "${tag_name}" "${tag_value}" 'add'
	done
else
	flac_check_file "${top_dir}" 'verbose'
	metaflac_retag "${top_dir}" "${tag_name}" "${tag_value}" 'add'
fi

trap "on_exit 'Success'" EXIT
exit 0

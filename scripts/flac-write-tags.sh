#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	echo "${script_name} (audx) - Write new FLAC metadata tags using --tag or --tag-name, --tag-value." >&2

	echo "Usage: ${script_name} [flags] top-dir" >&2
	echo "Option flags:" >&2
	echo "  -t --tag         - Full tag 'NAME=VALUE'. Default='${tag_full}'." >&2
	echo "  -n --tag-name    - Tag Name. Default='${tag_name}'." >&2
	echo "  -l --tag-value   - Tag data. Default='${tag_value}'.'" >&2
	echo "  -h --help        - Show this help and exit." >&2
	echo "  -v --verbose     - Verbose execution." >&2
	echo "  -d --dry-run     - Dry run, don't modify files." >&2
	echo "  -g --debug       - Extra verbose execution." >&2
	echo "Common TAGs:" >&2
	echo "  ARTIST" >&2
	echo "  ALBUM" >&2
	echo "  TITLE" >&2
	echo "  TRACKNUMBER" >&2
	echo "  TRACKTOTAL" >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="t:n:l:hvdg"
	local long_opts="tag:,tag-name:,tag-value:,help,verbose,dry-run,debug"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
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

source "${SCRIPTS_TOP}/audx-lib.sh"

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

readarray -t path_array < <((cd "${top_dir}" && find . -type f) | sort)

echo "${script_name}: INFO: Processing ${#path_array[@]} files." >&2

for path in "${path_array[@]}"; do
	path="${path:2}"

	if ! flac_check_file "${top_dir}/${path}"; then
		continue
	fi
	metaflac_retag "${top_dir}/${path}" "${tag_name}" "${tag_value}" 'add-tag'
done

trap "on_exit 'Success'" EXIT
exit 0

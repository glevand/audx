#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	echo "${script_name} (audx) - Add FLAC metadata tags to rip-c files." >&2

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

clean_rip_tag() {
	local tag=${1}

	tag="${tag//-/ }"

	set -- ${tag}
	tag="$(echo "${@^}")"

	tag="${tag//Un Concert/WXRT UnConcert}"
	tag="${tag//Unconcert/UnConcert}"

	echo "${tag}"
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

declare -A triple

readarray files_array < <(find "${top_dir}" -type f -name '*.flac' | sort)

echo "Processing ${#files_array[@]} files." >&2

for file in "${files_array[@]}"; do
	file="${file//[$'\r\n']}"

	path_to_artist_album_title "${file}" triple

	triple[artist]="$(clean_rip_tag ${triple[artist]})"
	triple[album]="$(clean_rip_tag ${triple[album]})"

	triple[title]="${triple[title]%.flac}"
	triple[title]="$(clean_rip_tag ${triple[title]})"
	triple[title]="${triple[title]// Side / - Side }"
	triple[title]="${triple[title]// WXRT UnConcert/}"

	track="${triple[title]##*Side }"

	echo "'${file}'"
	echo "'${triple[artist]}' || '${triple[album]}' || '${triple[title]}' || '${track}'"

	"${metaflac}" --preserve-modtime --remove-tag="Comment" "${file}"

	"${metaflac}" --preserve-modtime --remove-tag="ARTIST"      --set-tag="ARTIST=${triple[artist]}" "${file}"
	"${metaflac}" --preserve-modtime --remove-tag="ALBUM"       --set-tag="ALBUM=${triple[album]}" "${file}"
	"${metaflac}" --preserve-modtime --remove-tag="TITLE"       --set-tag="TITLE=${triple[title]}" "${file}"
	"${metaflac}" --preserve-modtime --remove-tag="TRACKNUMBER" --set-tag="TRACKNUMBER=${track}" "${file}"
	
	"${metaflac}" --list --block-type=VORBIS_COMMENT "${file}"
	echo ""
done

trap "on_exit 'Success'" EXIT
exit 0

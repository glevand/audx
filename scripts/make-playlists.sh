#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} (audx) - Recursively create m3u album playlists." >&2
	echo "Usage: ${script_name} [flags] top-dir" >&2
	echo "Option flags:" >&2
	echo "  -n --canonical   - Output full canonical paths to playlist." >&2
	echo "  -t --file-types  - File extension types {${known_file_types}}. Default: '${file_types}'." >&2
	echo "  -c --clobber     - Overwrite existing files. Default: '${clobber}'." >&2
#	echo "  -A --option-A    - option-A. Default: '${option_A}'." >&2
#	echo "  -B --option-B    - option-B. Default: '${option_B}'." >&2
	echo "  -h --help        - Show this help and exit." >&2
	echo "  -v --verbose     - Verbose execution." >&2
	echo "  -g --debug       - Extra verbose execution." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="nt:cA:B:hvg"
	local long_opts="canonical,file-types:,clobber,option-A:,option-B:,help,verbose,debug"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-n | --canonical)
			canonical=1
			shift
			;;
		-t | --file-types)
			file_types="${2}"
			shift 2
			;;
		-c | --clobber)
			clobber=1
			shift
			;;
		-A | --option-A)
			option_A="${2}"
			shift 2
			;;
		-B | --option-B)
			option_B="${2}"
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

start_time="$(date +%Y.%m.%d-%H.%M.%S)"
m3u_file="album.m3u"

process_opts "${@}"

known_file_types="flac mp3 m4a sox wav"
file_types="${file_types:-flac}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

check_top_dir "${top_dir}"
top_dir="$(realpath -e "${top_dir}")"

readarray -t dir_array < <(find "${top_dir}" -type d | sort)

for dir in "${dir_array[@]}"; do
	if [[ ${verbose} ]]; then
		echo "${script_name}: Processing: '${dir}'" >&2
	fi

	out_file="${dir}/${m3u_file}"

	if [[ -f "${out_file}" ]]; then
		if [[ ${clobber} ]]; then
			rm -f "${out_file:?}"
		else
			if [[ ${verbose} ]]; then
				echo "${script_name}: File exists: '${out_file}'" >&2
			fi
			continue
		fi
	fi

# 	TODO: Need an empty check with header.
# 	declare -A pair
# 	path_to_artist_album "${dir}" pair
# 	write_m3u_header "${out_file}" 'audx playlist' "${pair[artist]}" "${pair[album]}"

	for type in ${file_types}; do
		write_m3u_playlist "${out_file}" "${dir}" "${type}" "${canonical}"
	done
done

empty="$(find "${top_dir}" -depth -type f -name "${m3u_file}" -empty)"

if [[ ${empty} ]] ; then
	echo '' >&2
	echo "${script_name}: WARNING: Empty playlists found:" >&2
	echo "${empty}" >&2
	exit 1
fi

trap "on_exit 'Success'" EXIT
exit 0

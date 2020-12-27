#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} (audx) - Create an m3u playlist of random albums." >&2
	echo "Usage: ${script_name} [flags] top-dir" >&2
	echo "Option flags:" >&2
	echo "  -c --count       - Number of albums in playlist. Default: '${count}'." >&2
	echo "  -o --output-file - Playlist output file. Default: '${out_file}'." >&2
	echo "  -h --help        - Show this help and exit." >&2
	echo "  -v --verbose     - Verbose execution." >&2
	echo "  -g --debug       - Extra verbose execution." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="c:o:hvg"
	local long_opts="count:,output-file:,help,verbose,debug"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-c | --count)
			count="${2}"
			shift 2
			;;
		-o | --output-file)
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

run_time="$(date +%Y.%m.%d-%H.%M.%S)"
m3u_file="album.m3u"

process_opts "${@}"

count="${count:-6}"
out_file="${out_file:-/tmp/audx-shufflelist-${run_time}.m3u}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

check_top_dir "${top_dir}"
top_dir="$(realpath -e "${top_dir}")"

check_if_positive '--count' "${count}"

readarray album_array < <(find "${top_dir}" -type f -name "${m3u_file}")

album_count="${#album_array[@]}"

if (( ${album_count} < ${count} )); then
	echo "${script_name}: ERROR: Not enough albums to fill playlist: (${album_count} < ${count})." >&2
	exit 1
fi

echo "${script_name}: INFO: Selecting from ${album_count} albums." >&2

if [[ -f "${out_file}" ]]; then
	rm -f "${out_file:?}"
fi

for (( i = 0; i < ${count}; i++ )); do
	for (( j = 0; ; j++ )); do
		rand=$(( RANDOM % ${album_count} ))

		if [[ ${album_array[rand]} ]]; then
			break
		fi

		# FIXME: Need this???
		if (( j > (album_count * album_count) )); then
			echo "${script_name}: INTERNAL ERROR: random loop." >&2
			exit 1
		fi
	done

	album="${album_array[rand]//[$'\r\n']}"
	unset album_array[rand]

	declare -A triple
	path_to_artist_album_title "${album}" triple

	echo "$(( i + 1 )): ${triple[artist]} -- ${triple[album]}" >&2

	readarray -t track_array < "${album}"

	for track in "${track_array[@]}"; do
		if [[ ${verbose} ]]; then
			echo "   ${track}" >&2
		fi
		path="${album%/*}"
		echo "${path}/${track}" >> "${out_file}"
	done
done

echo "${script_name}: INFO: Playlist in '${out_file}'" >&2

trap "on_exit 'Success'" EXIT
exit 0

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
	echo "  -s --start-date  - Starting date. Default: '${start_date}'." >&2
	echo "  -e --end-date    - Ending date. Default: '${end_date}'." >&2
	echo "  -h --help        - Show this help and exit." >&2
	echo "  -v --verbose     - Verbose execution." >&2
	echo "  -g --debug       - Extra verbose execution." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="c:o:s:e:hvg"
	local long_opts="count:,output-file:,start-date:,end-date:,help,verbose,debug"

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
		-s | --start-date)
			start_date="${2}"
			shift 2
			;;
		-e | --end-date)
			end_date="${2}"
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

test_album_file() {
	local file="${1}"
	local start="${2}"
	local end="${3}"

# 	echo "" >&2
# 	echo "${FUNCNAME[0]}>------------------------" >&2
# 	echo "${FUNCNAME[0]}: file  = '${file}'" >&2
# 	echo "${FUNCNAME[0]}: start = '${start}'" >&2
# 	echo "${FUNCNAME[0]}: end   = '${end}'" >&2

	local output
	output="$(find_first_file "${file%/*}" "${start}" "${end}" '*.flac' )"

	if [[ ${output} ]]; then
# 		echo "${FUNCNAME[0]}: Add '${file}'" >&2
		echo "${file}"
	fi

# 	echo "${FUNCNAME[0]}: out = @${output}@" >&2
# 	echo "${FUNCNAME[0]}<------------------------" >&2
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

start_time="$(date +%Y.%m.%d-%H.%M.%S)"
m3u_file="album.m3u"

process_opts "${@}"

count="${count:-6}"
out_file="${out_file:-/tmp/audx-shufflelist-${start_time}.m3u}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

echo "audx ${script_name} - ${start_time}" >&2

parallel="${parallel:-parallel}"
check_program "parallel" "${parallel}"

shuf="${shuf:-shuf}"
check_program "shuf" "${shuf}"

check_top_dir "${top_dir}"
top_dir="$(realpath -e "${top_dir}")"

check_if_positive '--count' "${count}"

start_date="${start_date:-$(date --date="Jan 1 1900")}"
start_date="$(date --date="${start_date}" '+%Y-%m-%d %H:%M:%S')"

end_date="${end_date:-$(date --date="tomorrow")}"
end_date="$(date --date="${end_date}" +'%Y-%m-%d %H:%M:%S')"

if [[ "${start_date}" > "${end_date}" ]]; then
	echo "${script_name}: ERROR: Bad dates." >&2
	echo "${script_name}: ERROR: Start date = '${start_date}'." >&2
	echo "${script_name}: ERROR: End date   = '${end_date}'." >&2
	exit 1
fi

if [[ ${verbose} ]]; then
	echo "INFO: Start date = '${start_date}'." >&2
	echo "INFO: End date   = '${end_date}'." >&2
fi

readarray -t album_array < <(find "${top_dir}" -type f -name "${m3u_file}" -print)

echo "INFO: Considering ${#album_array[@]} albums." >&2

# for (( i = 0; i < ${#album_array[@]}; i++ )); do
# 	echo "${i}: '${album_array[i]}'" >&2
# done

export -f find_first_file
export -f test_album_file

readarray -t good_array < <(parallel test_album_file {} "'${start_date}'" "'${end_date}'" ::: "${album_array[@]}")
good_count="${#good_array[@]}"

unset album_array

echo "INFO: Found ${good_count} eligible albums." >&2

if [[ ${verbose} ]]; then
	for (( i = 0; i < ${good_count}; i++ )); do
		echo "${i}: '${good_array[i]}'" >&2
	done
fi

if (( ${good_count} < ${count} )); then
	echo "${script_name}: ERROR: Not enough albums to fill playlist: (${good_count} < ${count})." >&2
	exit 1
fi

if [[ -f "${out_file}" ]]; then
	rm -f "${out_file:?}"
fi


for (( i = 0; i < ${count}; i++ )); do
	for (( j = 0; ; j++ )); do
		rand="$("${shuf}" -n1 -i0-${good_count})"

		#echo "good_count = ${good_count}, j = ${j}" >&2
		if [[ ${good_array[rand]} ]]; then
			break
		fi

		if (( j > (good_count * good_count) )); then
			echo "${script_name}: INTERNAL ERROR: random loop." >&2
			exit 1
		fi
	done

	album_file="${good_array[rand]}"
	album_dir="${good_array[rand]%/*}"
	unset good_array[rand]

	declare -A triple
	path_to_artist_album_title "${album_file}" triple

	echo "$(( i + 1 )): ${triple[artist]} -- ${triple[album]}" >&2

	readarray -t track_array < "${album_file}"

	track_count="${#track_array[@]}"

	for (( k = 0; k < ${track_count}; k++ )); do
		if [[ ${verbose} ]]; then
			echo "   '${track_array[k]}'" >&2
		fi
		echo "${album_dir}/${track_array[k]}" >> "${out_file}"
	done
done

echo "INFO: Playlist in '${out_file}'" >&2

trap "on_exit 'Success'" EXIT
exit 0

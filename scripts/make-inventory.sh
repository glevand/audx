#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} (audx) - Make inventory lists of an album collection." >&2
	echo "Usage: ${script_name} [flags] src-directory [src-directory]..." >&2
	echo "Option flags:" >&2
	echo "  -o --output-dir  - Output directory. Default: '${output_dir}'." >&2
	echo "  -c --canonical   - Output full canonical paths to lists." >&2
	echo "  -t --use-tags    - Use metadata tags to generate lists. Default: '${use_tags}'." >&2
	echo "  -m --mtime       - Print file modification time. Default: '${mtime}'." >&2
	echo "  -r --tracks      - Include album tracks. Default: '${tracks}'." >&2
	echo "  -h --help        - Show this help and exit." >&2
	echo "  -v --verbose     - Verbose execution." >&2
	echo "  -g --debug       - Extra verbose execution." >&2
	echo "Send bug reports to: Geoff Levand <geoff@infradead.org>." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="o:ctmrhvg"
	local long_opts="output-dir:,canonical,use-tags,mtime,tracks,help,verbose,debug"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while : ; do
		#Secho "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-o | --output-dir)
			output_dir="${2}"
			shift 2
			;;
		-c | --canonical)
			canonical=1
			shift
			;;
		-t | --use-tags)
			use_tags=1
			shift
			;;
		-m | --mtime)
			mtime=1
			shift
			;;
		-r | --tracks)
			tracks='y'
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
			while [[ ${1} ]] ; do
				#echo "fill src_dirs: @${1}@"
				src_dirs+=("${1}")
				shift
			done
			break
			;;
		*)
			echo "${script_name}: ERROR: Internal opts: '${*}'" >&2
			exit 1
			;;
		esac
	done
}

on_exit() {
	local result=${1}
	local sec=${SECONDS}

	set +x
	echo "${script_name}: Done: ${result}, ${sec} sec ($(sec_to_min "${sec}") min)." >&2
}

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}):\[\e[0m\] '
script_name="${0##*/}"

SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}" && pwd)"}
SECONDS=0

source "${SCRIPTS_TOP}/lib.sh"

trap "on_exit 'Failed.'" EXIT
set -e
set -o pipefail

start_time="$(date +%Y.%m.%d-%H.%M.%S)"
tracks='n'

declare -a src_dirs

process_opts "${@}"

output_dir="${output_dir:-/tmp/audx-inventory-${start_time}}"
output_dir="$(realpath --canonicalize-missing "${output_dir}")"

if [[ ${use_tags} ]]; then
	echo "${script_name}: ERROR: --use-tags: TODO" >&2
	usage
	exit 1
fi

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

check_src_dirs "${src_dirs[@]}"

mkdir -p "${output_dir}"

for src_dir in "${src_dirs[@]}"; do
	if [[ "${tracks}" == 'y' ]]; then
		list_type='tracks'
	else
		list_type='albums'
	fi

	src_dir="${src_dir%/}"
	output_file="${output_dir}/${src_dir##*/}-${list_type}.lst"
	src_path="$(realpath "${src_dir}")"

	readarray -t album_array < <(find "${src_path}" -type f -name 'album.m3u' | sort)

	echo "# ${script_name} (audx) - ${start_time}" > "${output_file}"
	echo "# ${src_dir}: ${#album_array[@]} albums." >> "${output_file}"
	echo '' >> "${output_file}"

	for (( i = 0; i < ${#album_array[@]}; i++ )); do
		album_path="${album_array[i]%/album.m3u}"
		album="${album_path##*/}"
		artist_path="${album_path%/*}"
		artist="${artist_path##*/}"

		if [[ ${canonical} ]]; then
			item="'${album_path}'"
		else
			if [[ ! ${artist} || ! ${album} ]]; then
				echo "${script_name}: WARNING: No path, use --canonical" >&2
			fi
			item="'${artist}/${album}'"
		fi

		if [[ ${mtime} ]]; then
			ftime=" $(ls -l --time-style='+%Y.%m.%d' "$(realpath "${src_dir}/${album}/01-"*)" | grep -E --only-matching '[[:digit:]]{4}(\.[[:digit:]]{2}){2}')"
		fi

		echo "[$(( i + 1 ))]${ftime} ${item}" >> "${output_file}"

		if [[ "${tracks}" == 'y' ]]; then
			readarray -t track_array < <(find "${album_path}" -type f -name '*.flac' -o -name '*.m4a' | sort)

			for (( j = 0; j < ${#track_array[@]}; j++ )); do
				track="${track_array[j]##*/}"
				track="${track%.*}"
				#echo "  [$(( i + 1 )).$(( j + 1 ))] ${track}" >> "${output_file}"
				echo "  '${track}'" >> "${output_file}"
			done
		fi

	done

	if [[ ${verbose} ]]; then
		echo "# ${output_file}"
		cat "${output_file}"
		echo ''
	fi
done

echo "${script_name}: Album lists generated in '${output_dir}'."  >&2
trap $'on_exit "Success"' EXIT
exit 0

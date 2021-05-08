#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	{
		echo "${script_name} - Make inventory lists of an album collection."
		echo "Usage: ${script_name} [flags] src-directory [src-directory]..."
		echo "Option flags:"
		echo "  -o --output-dir  - Output directory. Default: '${output_dir}'."
		echo "  -c --canonical   - Output full canonical paths to lists."
		echo "  -m --mtime       - Print file modification time. Default: '${mtime}'."
		echo "  -t --tracks      - Include album tracks. Default: '${tracks}'."
		echo "  -T --use-tags    - Use metadata tags to generate lists. Default: '${use_tags}'."
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
	local short_opts="o:cmtThvg"
	local long_opts="output-dir:,canonical,mtime,tracks,use-tags,help,verbose,debug"

	output_dir=''
	canonical=''
	mtime=''
	tracks=''
	use_tags=''
	usage=''
	verbose=''
	debug=''

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while : ; do
		# echo "${FUNCNAME[0]}: (${#}) '${*}'"
		case "${1}" in
		-o | --output-dir)
			output_dir="${2}"
			shift 2
			;;
		-c | --canonical)
			canonical=1
			shift
			;;
		-m | --mtime)
			mtime=1
			shift
			;;
		-t | --tracks)
			tracks=1
			shift
			;;
		-T | --use-tags)
			use_tags=1
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
			src_dirs=("$@")
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

if [[ ${tracks} ]]; then
	list_type='tracks'
else
	list_type='albums'
fi

for src_dir in "${src_dirs[@]}"; do
	src_dir="${src_dir%/}"
	output_file="${output_dir}/${src_dir##*/}-${list_type}.lst"
	src_path="$(realpath "${src_dir}")"

	readarray -t album_array < <( \
		find "${src_path}" -type f -name 'album.m3u' | sort \
		|| { echo "${script_name}: ERROR: album_array find failed, function=${FUNCNAME[0]:-main}, line=${LINENO}, result=${?}" >&2; \
		kill -SIGUSR1 $$; } )

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
		else
			ftime=''
		fi

		echo "[$(( i + 1 ))]${ftime} ${item}" >> "${output_file}"

		if [[ ${tracks} ]]; then
			readarray -t track_array < <( \
				find "${album_path}" -type f -name '*.flac' -o -name '*.m4a' | sort \
				|| { echo "${script_name}: ERROR: track_array find failed, function=${FUNCNAME[0]:-main}, line=${LINENO}, result=${?}" >&2; \
				kill -SIGUSR1 $$; } )

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

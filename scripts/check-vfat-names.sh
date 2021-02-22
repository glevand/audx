#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} (audx) - Check vfat file names."
	echo "Usage: ${script_name} [flags] top-dir" >&2
	echo "Option flags:" >&2
	echo "  -o --output-dir  - Output directory. Default: '${output_dir}'." >&2
	echo "  -c --clean-names - Clean file names using standard rules. Default: '${clean_names}'." >&2
	echo "  -h --help        - Show this help and exit." >&2
	echo "  -v --verbose     - Verbose execution." >&2
	echo "  -g --debug       - Extra verbose execution." >&2
	echo "Send bug reports to: Geoff Levand <geoff@infradead.org>." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="o:chvg"
	local long_opts="output-dir:,clean-names,help,verbose,debug"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-o | --output-dir)
			output_dir="${2}"
			shift 2
			;;
		-c | --clean-names)
			clean_names=1
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

touch_file() {
	local in_file=${1}

	declare -A triple
	path_to_artist_album_title "${in_file}" triple

	if [[ ${clean_names} ]]; then
		triple[artist]="$(clean_vfat_name "${triple[artist]}")"
		triple[album]="$(clean_vfat_name "${triple[album]}")"
		triple[title]="$(clean_vfat_name "${triple[title]}")"
	fi

	local out_file
	out_file="${output_dir}/${triple[artist]}/${triple[album]}/${triple[title]%.flac}.m4a"

	if [[ ${verbose} ]]; then
		echo "out_file: '${out_file}'" >&2
		#echo "${FUNCNAME[0]}: '${p_script}'" >&2
	fi

	local bad
	unset bad

	mkdir -p "${out_file%/*}" || bad=1
	if [[ ! ${bad} ]]; then
		touch "${out_file}" || :
	fi
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

#run_time="$(date +%Y.%m.%d-%H.%M.%S)"
unset clean_names

process_opts "${@}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

check_top_dir "${top_dir}"
top_dir="$(realpath -e "${top_dir}")"

output_dir="$(realpath "${output_dir}")"

if [[ -d "${output_dir}" ]]; then
	rm -rf "${output_dir:?}"
fi

mkdir -p "${output_dir}"

readarray -t file_array < <(find "${top_dir}" -type f -name '*.flac' | sort)

echo "${script_name}: INFO: Processing ${#file_array[@]} files." >&2

for (( i = 0; i < ${#file_array[@]}; i++ )); do
	touch_file "${file_array[i]}"
done

echo "${script_name}: INFO: Wrote ${#file_array[@]} m4a files to '${output_dir}'" >&2

trap "on_exit 'Success'" EXIT
exit 0

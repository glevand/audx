#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	echo "${script_name} (audx) - Clean FLAC metadata tags using standard rules." >&2

	echo "Usage: ${script_name} [flags] top-dir" >&2
	echo "Option flags:" >&2
	echo "  -h --help        - Show this help and exit." >&2
	echo "  -v --verbose     - Verbose execution." >&2
	echo "  -d --dry-run     - Dry run, don't modify files." >&2
	echo "  -g --debug       - Extra verbose execution." >&2
	echo "Send bug reports to: Geoff Levand <geoff@infradead.org>." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="hvdg"
	local long_opts="help,verbose,dry-run,debug"

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

clean_tags() {
	local file="${1}"

	if ! flac_check_file "${file}"; then
		return
	fi

	declare -A tags

	flac_fill_tag_set "${file}" tags

	if [[ ${debug} ]]; then
		flac_print_tag_set "${file}" tags
	fi

	declare -A new_tags

	new_tags[artist]="$(clean_tag "${tags[artist]}")"
	new_tags[album]="$(clean_tag "${tags[album]}")"
	new_tags[title]="$(clean_tag "${tags[title]}")"

	local need_write
	unset need_write

	if [[ "${tags[artist]}" != "${new_tags[artist]}" ]]; then
		need_write=1
		if [[ ${verbose} ]]; then
			echo -e "clean artist: '${file}': '${tags[artist]}' -> '${new_tags[artist]}'" >&2
		else
			echo -e "clean artist: '${tags[artist]}' -> '${new_tags[artist]}'" >&2
		fi
	fi

	if [[ "${tags[album]}" != "${new_tags[album]}" ]]; then
		need_write=1
		if [[ ${verbose} ]]; then
			echo -e "clean album: '${file}': '${tags[album]}' -> '${new_tags[album]}'" >&2
		else
			echo -e "clean album: '${tags[album]}' -> '${new_tags[album]}'" >&2
		fi
	fi

	if [[ "${tags[title]}" != "${new_tags[title]}" ]]; then
		need_write=1
		if [[ ${verbose} ]]; then
			echo -e "clean title: '${file}': '${tags[title]}' -> '${new_tags[title]}'" >&2
		else
			echo -e "clean title: '${tags[title]}' -> '${new_tags[title]}'" >&2
		fi
	fi

	if [[ ${need_write} && ! ${dry_run} ]]; then
		metaflac_retag "${file}" "Artist"  "${new_tags[artist]}"
		metaflac_retag "${file}" "Album"  "${new_tags[album]}"
		metaflac_retag "${file}" "Title"  "${new_tags[title]}"
		[[ ! ${verbose} ]] || echo -e "${FUNCNAME[0]}: Wrote '${file}'" >&2
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

readarray -t path_array < <((cd "${top_dir}" && find . -type f) | sort)

echo "${script_name}: INFO: Processing ${#path_array[@]} files." >&2

for path in "${path_array[@]}"; do
	path="${path:2}"

	clean_tags "${top_dir}/${path}"
done

trap "on_exit 'Success'" EXIT
exit 0

#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	{
		echo "${script_name} - Clean FLAC metadata tags using standard rules."
		echo "Usage: ${script_name} [flags] top-dir"
		echo "Option flags:"
		echo "  -d --dry-run     - Dry run, don't modify files."
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
	local short_opts="dhvg"
	local long_opts="dry-run,help,verbose,debug"

	dry_run=''
	usage=''
	verbose=''
	debug=''

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		# echo "${FUNCNAME[0]}: (${#}) '${*}'"
		case "${1}" in
		-d | --dry-run)
			dry_run=1
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

clean_tags() {
	local file="${1}"

	if ! flac_check_file "${file}" 'quiet'; then
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

	local need_write=''

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
		metaflac_retag "${file}" "Artist"  "${new_tags[artist]}" 'update'
		metaflac_retag "${file}" "Album"  "${new_tags[album]}" 'update'
		metaflac_retag "${file}" "Title"  "${new_tags[title]}" 'update'

		if [[ ${verbose} ]]; then
			echo -e "${FUNCNAME[0]}: Wrote '${file}'" >&2
		fi
	fi
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

check_top_dir "${top_dir}"
top_dir="$(realpath -e "${top_dir}")"

metaflac="${metaflac:-metaflac}"

check_program "metaflac" "${metaflac}"

readarray -t path_array < <(( cd "${top_dir}" && find . -type f) | sort \
	|| { echo "${script_name}: ERROR: path_array find failed, function=${FUNCNAME[0]:-main}, line=${LINENO}, result=${?}" >&2; \
	kill -SIGUSR1 $$; } )

echo "${script_name}: INFO: Processing ${#path_array[@]} files." >&2

for path in "${path_array[@]}"; do
	path="${path:2}"

	clean_tags "${top_dir}/${path}"
done

trap "on_exit 'Success'" EXIT
exit 0

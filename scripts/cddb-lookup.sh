#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	{
		echo "${script_name} - Lookup CDDB records by ID."
		echo
		echo "*** WORK IN PROGRESS ***"
		echo
		echo "Usage: ${script_name} [flags] <input-file>"
		echo "Option flags:"
#		echo "  -0 --opt-0   - opt-0. Default:'${opt_0}'."
# 		echo "  -1 --opt-1   - opt-1. Default='${opt_1}'."
# 		echo "  -2 --opt-2   - opt-2. Default='${opt_2}'."
#		echo "  -3 --opt-3   - opt-3. Default='${opt_3}'."
		echo "  -h --help    - Show this help and exit."
		echo "  -v --verbose - Verbose execution."
		echo "  -g --debug   - Extra verbose execution."
		echo "  -d --dry-run - Dry run, don't modify files."
		echo 'Input file:'
		echo "  '${input_file}'"
		echo 'Input file format:'
		echo "  /Yazoo/Upstairs at Erics/10-Winter Kills.flac' C:'' D:'8d0a210b'"
		echo "Info:"
		print_project_info
	} >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="0:1:2:3:hvgd"
	local long_opts="opt-0:,opt-1:,opt-2:,opt-3:,help,verbose,debug,dry-run"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		# echo "${FUNCNAME[0]}: (${#}) '${*}'"
		case "${1}" in
		-0 | --opt-0)
			opt_0="${2}"
			shift 2
			;;
		-1 | --opt-1)
			opt_1="${2}"
			shift 2
			;;
		-2 | --opt-2)
			opt_2="${2}"
			shift 2
			;;
		-3 | --opt-3)
			opt_3="${2}"
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
		-d | --dry-run)
			dry_run=1
			shift
			;;
		--)
			shift
			input_file="${1:-}"
			if [[ ${input_file} ]]; then
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

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '

script_name="${0##*/}"

SECONDS=0
start_time="$(date +%Y.%m.%d-%H.%M.%S)"

real_source="$(realpath "${BASH_SOURCE}")"
SCRIPT_TOP="$(realpath "${SCRIPT_TOP:-${real_source%/*}}")"

trap "on_exit 'Failed'" EXIT
trap 'on_err ${FUNCNAME[0]:-main} ${LINENO} ${?}' ERR
trap 'on_err SIGUSR1 ? 3' SIGUSR1

set -eE
set -o pipefail
set -o nounset

source "${SCRIPT_TOP}/audx-lib.sh"

opt_0=''
opt_1=''
opt_2=''
opt_3=''
usage=''
verbose=''
debug=''
dry_run=''
input_file=''

process_opts "${@}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

print_project_banner >&2

if [[ ${extra_args} ]]; then
	set +o xtrace
	echo "${script_name}: ERROR: Got extra args: '${extra_args}'" >&2
	usage
	exit 1
fi

if [[ ! ${input_file} ]]; then
	echo "${script_name}: ERROR: No source file given." >&2
	usage
	exit 1
fi

input_file="$(realpath -e "${input_file}")"

if [[ ! -d "${input_file}" && ! -f "${input_file}" ]]; then
	echo "${script_name}: ERROR: Bad input-file: '${input_file}'" >&2
	usage
	exit 1
fi

readarray -t input_array < "${input_file}"

if [[ ${dry_run} ]]; then
	echo "${script_name}: INFO: Processing ${#input_array[@]} ids (DRY RUN)."
else
	echo "${script_name}: INFO: Processing ${#input_array[@]} ids."
fi

# 'collection/rock/Yazoo/Upstairs at Erics/10-Winter Kills.flac' C:'' D:'8d0a210b'
line_regex="/([^/]*)/([^/]*)/[^/]*\.flac' C:'([[[:xdigit:]]*)' D:'([[[:xdigit:]]*)'"

declare -A tags

for line in "${input_array[@]}"; do
	# echo "input = '${line}'"

	if [[ ! "${line}" =~ ${line_regex} ]]; then
		echo "ERROR: No match '${line}'" >&2
		exit 1
	fi

	artist="${BASH_REMATCH[1]}"
	album="${BASH_REMATCH[2]}"
	cddb="${BASH_REMATCH[3]}"
	discid="${BASH_REMATCH[4]}"

	if [[ ! ${tags[${discid}]:-} ]]; then
		tags[${discid}]="${artist}/${album}"
		# echo "set ${discid}: '${artist}/${album}'"
	fi
done

genre_types='rock country jazz blues classical folk pop reggae soul'

for discid in "${!tags[@]}"; do
	echo '=========================='
	echo "discid = ${discid}"
	echo "${tags[${discid}]}"
	echo '=========================='

	for genre in ${genre_types}; do
		if [[ ! ${dry_run} ]]; then
			echo '-------------'
			echo "lookup: ${genre}/${discid}"
			curl -s "https://gnudb.org/gnudb/${genre}/${discid}" || :
			echo
		fi
	done
	echo '-------------'
done

trap "on_exit 'Success'" EXIT
exit 0

#================================================================================
# dev tests

do_lookup() {
	local genre=${1}
	local id=${2}

#	echo "genre = '${genre}' id = '${id}'"

	if curl -s https://gnudb.org/gnudb/${genre}/${id}; then
		echo "Good ID: ${genre}/${id}"
		return 0
	else
		echo "Bad ID: ${genre}/${id}"
		return 1
	fi
}

lookup_id() {
	local id=${1}

	for genre in ${g_types}; do
		#do_lookup "${genre}" "${id}"
		curl -s https://gnudb.org/gnudb/${genre}/${id}
		echo '-------------'
	done
}

g_types='blues classical country folk jazz pop reggae rock soul'

readarray -t path_array < <( (cd "${input_file}" && find . -type f) | sort \
	|| { echo "${script_name}: ERROR: path_array find failed, function=${FUNCNAME[0]:-main}, line=${LINENO}, result=${?}" >&2; \
	kill -SIGUSR1 $$; } )


for id in ${ids}; do
	echo '=========================='

	for genre in ${g_types}; do
		curl -s https://gnudb.org/gnudb/${genre}/${id}
		echo
		echo '-------------'
	done
done
echo '=========================='

#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} (audx) - Rip audio cassettes." >&2
	echo "Usage: ${script_name} [flags]" >&2
	echo "Option flags:" >&2
	echo "  -h --help         - Show this help and exit." >&2
	echo "  -v --verbose      - Verbose execution." >&2
	echo "  --base-name       - Output file base name. Default: '${base_name}'." >&2
	echo "  --start-duration  - Silence start duration. Default: '${start_duration}'." >&2
	echo "  --start-threshold - Silence start threshold. Default: '${start_threshold}'." >&2
	echo "  --end-duration    - Silence end duration. Default: '${end_duration}'." >&2
	echo "  --end-threshold   - Silence end threshold. Default: '${end_threshold}'." >&2
#	echo "  --split-time      - Split time . Default: '${split_time}'." >&2
	echo "  -f --force        - Force overwrite if exisitng output file." >&2
	echo "  -c --config-file  - Configuration file. Default: '${config_file}'." >&2
	echo "Option steps:" >&2
	echo "  -1 --rip-sox      - Rip to sox file." >&2
	echo "  -2 --split-sox    - Split sox file." >&2
	echo "  -3 --encode-flac  - Encode to flac." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="hv123fc:"
	local long_opts="help,verbose,\
base-name:,\
start-duration:,start-threshold:,\
end-duration:,end-threshold:,\
split-time:,\
rip-sox,split-sox,encode-flac,\
config-file:,force"

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
			set -x
			#verbose=1
			shift
			;;
		--start-duration)
			start_duration="${2}"
			shift 2
			;;
		--start-threshold)
			start_threshold="${2}"
			shift 2
			;;
		--end-duration)
			end_duration="${2}"
			shift 2
			;;
		--end-threshold)
			end_threshold="${2}"
			shift 2
			;;
		--base-name)
			base_name="${2}"
			shift 2
			;;
		--split-time)
			split_time="${2}"
			shift 2
			;;
		-f | --force)
			force=1
			shift
			;;
		-c | --config-file)
			config_file="${2}"
			shift 2
			;;
		-1 | --rip-sox)
			#step_rip_sox=1
			shift
			;;
		-2 | --split-sox)
			#step_split_sox=1
			shift
			;;
		-3 | --encode-flac)
			#step_encode_flac=1
			shift
			;;
		--)
			shift
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
SECONDS=0

trap "on_exit 'failed'" EXIT
set -e

process_opts "${@}"

base_name="${base_name:-$(pwd)/rip--$(date +%Y.%m.%d-%H.%M.%S)}"

start_duration="${start_duration:-0.2}"
start_threshold="${start_threshold:-0.6%}"

end_duration="${end_duration:-2.0}"
end_threshold="${end_threshold:-0.6%}"

split_time="${split_time:-2.0}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

SECONDS=0

if ! test -x "$(command -v rec)"; then
	echo "${script_name}: ERROR: Please install 'sox'." >&2
	exit 1
fi

#cmd_silence="silence \
#	1 ${start_duration} ${start_threshold} \
#	1 ${end_duration} ${end_threshold}"

outfile="${base_name}.sox"

if [[ -f ${outfile} && ! ${force} ]]; then
	echo "${script_name}: WARNING: Output file '${outfile}' exists.  Use --force to overwrite." >&2
	exit 1
fi

cmd="rec ${outfile}"

eval "${cmd}"

trap "on_exit 'Success'" EXIT
exit 0

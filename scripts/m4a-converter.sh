#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${script_name} (audx) - Convert FLAC files to m4a AAC encoded files suitable for download to Walkman type devices."
	echo "Usage: ${script_name} [flags] top-dir" >&2
	echo "Option flags:" >&2
	echo "  -b --bitrate     - Encoding bitrate. Default: '${bitrate}'." >&2
	echo "  -o --output-dir  - Output directory. Default: '${output_dir}'." >&2
	echo "  -h --help        - Show this help and exit." >&2
	echo "  -v --verbose     - Verbose execution." >&2
	echo "  -g --debug       - Extra verbose execution." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="b:o:dhvg"
	local long_opts="bitrate:,output-dir:,dry-run,help,verbose,debug"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-b | --bitrate)
			bitrate="${2}"
			shift 2
			;;
		-o | --output-dir)
			output_dir="${2}"
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

setup_p_script() {
	local id=${1}
	local in_file=${2}
	local p_script=${3}

	declare -A triple
	path_to_artist_album_title "${in_file}" triple

	triple[artist]="$(clean_vfat_name "${triple[artist]}")"
	triple[album]="$(clean_vfat_name "${triple[album]}")"
	triple[title]="$(clean_vfat_name "${triple[title]}")"

	local out_file
	out_file="${output_dir}/${triple[artist]}/${triple[album]}/${triple[title]%.flac}.m4a"

	if [[ ${verbose} ]]; then
		echo "${id}: Setup '${in_file}'" >&2
		# echo "${id}: Setup '${in_file}' @ '${p_script}'" >&2
	fi

	declare -A tags
	flac_fill_tag_set "${in_file}" tags

	mkdir -p "${p_script%/*}"

	cat << EOF > "${p_script}"
#!/usr/bin/env bash

id='${id}'
in_file='${in_file}'
out_file='${out_file}'

artist='${tags[artist]}'
album='${tags[album]}'
title='${tags[title]}'
tracknumber='${tags[tracknumber]}'
tracktotal='${tags[tracktotal]}'

sox='${sox}'
fdkaac='${fdkaac}'

bitrate='${bitrate}'

EOF

	cat << 'EOF' >> "${p_script}"
echo "${id}: Processing '${in_file}'" >&2

mkdir -p "${out_file%/*}"

sox_cmd="${sox} '${in_file}' -t wav -"

fdkaac_cmd="${fdkaac} \
  --silent \
  --ignorelength \
  --profile 2 \
  --bitrate-mode=0 --bitrate=${bitrate} \
  --artist='${artist}' \
  --album='${album}' \
  --title='${title}' \
  --track='${tracknumber}/${tracktotal}' \
  -o '${out_file}' -"

eval "${sox_cmd} | ${fdkaac_cmd}"
EOF

	chmod +x "${p_script}"
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

process_opts "${@}"

bitrate="${bitrate:-328k}"
output_dir="${output_dir:-/tmp/audx-m4a-${run_time}}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

check_top_dir "${top_dir}"
top_dir="$(realpath -e "${top_dir}")"

fdkaac="${fdkaac:-fdkaac}"
check_program "fdkaac" "${fdkaac}"

metaflac="${metaflac:-metaflac}"
check_program "metaflac" "${metaflac}"

parallel="${parallel:-parallel}"
check_program "parallel" "${parallel}"

sox="${sox:-sox}"
check_program "sox" "${sox}"

readarray file_array < <(find "${top_dir}" -type f -name '*.flac' | sort)

file_count="${#file_array[@]}"

echo "${script_name}: INFO: Processing ${file_count} files." >&2

tmp_dir="$(mktemp --tmpdir --directory ${script_name}.XXXX)"

if [[ ${debug} ]]; then
	p_script_dir="${output_dir}/p-scripts"
else
	p_script_dir="${tmp_dir}/p-scripts"
fi

bucket_size=100
bucket_count=$(( file_count / bucket_size ))
bucket=1

for (( id = 1; id <= ${file_count}; id++ )); do
	file="${file_array[$(( id - 1 ))]//[$'\r\n']}"
	p_script="${p_script_dir}/${bucket}/${id}.sh"

	setup_p_script "${id}" "${file}" "${p_script}"

	if (( (id % bucket_size) == 0 )); then
		echo "Processing bucket ${bucket} of ${bucket_count}." >&2
		parallel -- $(find "${p_script_dir}/${bucket}" -type f -name '*.sh')
		bucket=$(( bucket + 1 ))
	fi
done

# FIXME: Use xargs???

parallel -- $(find "${p_script_dir}/${bucket}" -type f -name '*.sh')

echo "${script_name}: INFO: Wrote ${file_count} m4a files to '${output_dir}'" >&2

trap "on_exit 'Success'" EXIT
exit 0

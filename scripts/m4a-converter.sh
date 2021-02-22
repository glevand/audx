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
	echo "  -c --clobber     - Overwrite existing files. Default: '${clobber}'." >&2
	echo "  -h --help        - Show this help and exit." >&2
	echo "  -v --verbose     - Verbose execution. Default: '${verbose}'." >&2
	echo "  -g --debug       - Extra verbose execution. Default: '${debug}'." >&2
	echo "Send bug reports to: Geoff Levand <geoff@infradead.org>." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="b:o:chvg"
	local long_opts="bitrate:,output-dir:,clobber,help,verbose,debug"

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
		-c | --clobber)
			clobber=1
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
			keep_tmp_dir=1
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
	local -n _setup_p_script__out_counter="${4}"

	declare -A triple
	path_to_artist_album_title "${in_file}" triple

	triple[artist]="$(clean_vfat_name "${triple[artist]}")"
	triple[album]="$(clean_vfat_name "${triple[album]}")"
	triple[title]="$(clean_vfat_name "${triple[title]}")"

	local out_file
	out_file="${output_dir}/${triple[artist]}/${triple[album]}/${triple[title]%.flac}.m4a"

	if [[ ! ${clobber} && -e "${out_file}" ]]; then
		if [[ ${verbose} ]]; then
			echo "${id}: File exists '${out_file}'" >&2
		fi
		return
	fi

	if [[ ${verbose} ]]; then
		echo "${id}: Setup '${out_file}'" >&2
		#echo "${id}: Setup '${out_file}' @ '${p_script}'" >&2
	fi

	_setup_p_script__out_counter=$(( _setup_p_script__out_counter + 1 ))

	declare -A tags
	flac_fill_tag_set "${in_file}" tags

	cat << EOF > "${p_script}"
#!/usr/bin/env bash

# set -x

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
echo "${id}: Creating '${out_file}'" >&2

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

gnu_parallel() {
	local bucket_dir=${1}

# 	echo -n "Bucket files:" >&2
# 	ls "${bucket_dir}"/*.sh >&2
	"${parallel}" ::: "${bucket_dir}"/*.sh
}

moreutils_parallel() {
	local bucket_dir=${1}

# 	echo -n "Bucket files:" >&2
# 	ls "${bucket_dir}"/*.sh >&2
# 	"${parallel}" -- $(find "${bucket_dir}" -type f -name '*.sh')
	"${parallel}" -- "${bucket_dir}"/*.sh
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

start_time="$(date +%Y.%m.%d-%H.%M.%S)"

process_opts "${@}"

bitrate="${bitrate:-328k}"
output_dir="${output_dir:-/tmp/audx-m4a-${start_time}}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

echo "audx ${script_name} - ${start_time}" >&2

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

in_count="${#file_array[@]}"

echo "${script_name}: INFO: Processing ${in_count} input files." >&2

tmp_dir="$(mktemp --tmpdir --directory ${script_name}.XXXX)"

p_script_dir="${tmp_dir}/p-scripts"

bucket_size=100
bucket_count=$(( in_count / bucket_size ))
bucket=1

if [[ -e "${p_script_dir}" ]]; then
	rm -rf "${p_script_dir:?}"
fi

out_counter=0
loop_counter=0

for (( id = 1; id <= ${in_count}; id++ )); do
	file="${file_array[$(( id - 1 ))]//[$'\r\n']}"
	p_script="${p_script_dir}/${bucket}/${id}.sh"

	mkdir -p "${p_script_dir}/${bucket}"

	setup_p_script "${id}" "${file}" "${p_script}" loop_counter

	if (( (id % bucket_size) == 0 )); then
		if (( loop_counter == 0 )); then
			echo "Bucket ${bucket} of ${bucket_count}: No new files." >&2
			bucket=$(( bucket + 1 ))
			continue
		fi

		echo "Bucket ${bucket} of ${bucket_count}: Processing ${loop_counter} files." >&2
		out_counter=$(( out_counter + loop_counter ))
		loop_counter=0

		gnu_parallel "${p_script_dir}/${bucket}"
# 		moreutils_parallel "${p_script_dir}/${bucket}"

		bucket=$(( bucket + 1 ))
	fi
done

if (( loop_counter != 0 )); then
	echo "Bucket ${bucket} of ${bucket_count}: Processing ${loop_counter} files." >&2
	out_counter=$(( out_counter + loop_counter ))
	loop_counter=0

	gnu_parallel "${p_script_dir}/${bucket}"
# 	moreutils_parallel "${p_script_dir}/${bucket}"
fi

echo "${script_name}: INFO: Wrote ${out_counter} m4a files to '${output_dir}'" >&2

trap "on_exit 'Success'" EXIT
exit 0

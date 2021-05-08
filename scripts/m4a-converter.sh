#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	{
		echo "${script_name} - Convert FLAC files to m4a AAC encoded files suitable for download to Walkman type devices."
		echo "Usage: ${script_name} [flags] top-dir"
		echo "Option flags:"
		echo "  -b --bitrate     - Encoding bitrate. Default: '${bitrate}'."
		echo "  -o --output-dir  - Output directory. Default: '${output_dir}'."
		echo "  -c --clobber     - Overwrite existing files. Default: '${clobber}'."
		echo "  -h --help        - Show this help and exit."
		echo "  -v --verbose     - Verbose execution. Default: '${verbose}'."
		echo "  -g --debug       - Extra verbose execution. Default: '${debug}'."
		echo "Info:"
		echo "  ${script_name} (@PACKAGE_NAME@) version @PACKAGE_VERSION@"
		echo "  @PACKAGE_URL@"
		echo "  Send bug reports to: Geoff Levand <geoff@infradead.org>."
	} >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="b:o:chvg"
	local long_opts="bitrate:,output-dir:,clobber,help,verbose,debug"

	bitrate=''
	output_dir=''
	clobber=''
	usage=''
	verbose=''
	debug=''
	keep_tmp_dir=''

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		# echo "${FUNCNAME[0]}: (${#}) '${*}'"
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

setup_p_script() {
	local id=${1}
	local in_file=${2}
	local p_script=${3}
	local -n _setup_p_script__out_counter="${4}"

	declare -A triple
	path_to_artist_album_title "${in_file}" triple

	triple[artist]="$(clean_vfat_name "${triple[artist]}")"
	triple[album]="$(clean_vfat_name "${triple[album]}")"
	triple[title]="$(clean_vfat_name "${triple[title]%.flac}")"

	local out_file
	out_file="${output_dir}/${triple[artist]}/${triple[album]}/${triple[title]}.m4a"

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

bitrate="${bitrate:-328k}"
output_dir="${output_dir:-/tmp/audx-m4a-${start_time}}"

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

readarray -t files_array < <(find "${top_dir}" -type f -name '*.flac' | sort \
	|| { echo "${script_name}: ERROR: files_array find failed, function=${FUNCNAME[0]:-main}, line=${LINENO}, result=${?}" >&2; \
	kill -SIGUSR1 $$; } )

in_count="${#files_array[@]}"

echo "${script_name}: INFO: Processing ${in_count} input files." >&2

tmp_dir="$(mktemp --tmpdir --directory ${script_name}.XXXX)"

p_script_dir="${tmp_dir}/p-scripts"

bucket_size=100
bucket_count=$(( 1 + in_count / bucket_size ))
bucket=1

if [[ -e "${p_script_dir}" ]]; then
	rm -rf "${p_script_dir:?}"
fi

out_counter=0
loop_counter=0

for (( id = 1; id <= ${in_count}; id++ )); do
	file="${files_array[$(( id - 1 ))]}"
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

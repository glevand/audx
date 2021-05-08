#!/usr/bin/env bash

usage() {
	echo "Usage: ${script_name} build-dir" >&2
}

on_exit() {
	local result=${1}

	local sec="${SECONDS}"

	set +x
	echo "${script_name}: Done: ${result}, ${sec} sec." >&2
}

on_err() {
	local f_name=${1}
	local line_no=${2}
	local err_no=${3}

	echo "${script_name}: ERROR: (${err_no}) at ${f_name}:${line_no}." >&2
	exit "${err_no}"
}

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '

script_name="${0##*/}"

SECONDS=0
start_time="$(date +%Y.%m.%d-%H.%M.%S)"

trap "on_exit 'Failed'" EXIT
trap 'on_err ${FUNCNAME[0]:-main} ${LINENO} ${?}' ERR

set -eE
set -o pipefail
set -o nounset

# TESTS_TOP="$(realpath "${BASH_SOURCE%/*}")"

build_dir="${1:-}"
flag="${2:-}"

if [[ "${build_dir}" == '-h' || "${build_dir}" == '--help' \
	|| "${flag}" == '-h' || "${flag}" == '--help' ]]; then
        usage
        exit 0
fi

if [[ ! -d "${build_dir}" ]]; then
        echo "${script_name}: ERROR: Bad build-dir: '${build_dir}'" >&2
        exit 1
fi

build_dir="$(realpath "${build_dir}")"
cd "${build_dir}"

test_out_dir="${build_dir}/test-out"
mkdir -p "${test_out_dir}"

{
	echo ''
	echo '==========================================='
	echo "${script_name} (audx) - ${start_time}"
	echo '==========================================='
	echo ''
}

test_files=(
	'01-America Is Not The World.flac'
	'02-Irish Blood, English Heart.flac'
	'03-I Have Forgiven Jesus.flac'
	'04-Come Back To Camden.flac'
	'05-Im Not Sorry.flac'
	'06-The World Is Full Of Crashing Bores.flac'
	'07-How Can Anybody Possibly Know How I Feel.flac'
	'08-First Of The Gang To Die.flac'
	'09-Let Me Kiss You.flac'
	'10-All The Lazy Dykes.flac'
	'11-I Like You.flac'
	'12-You Know I Couldnt Last.flac'
)

music_dir="${test_out_dir}/music"
mkdir -p "${music_dir}"

for f in "${test_files[@]}"; do
	touch "${music_dir}/${f}"
done

echo '--- make-playlists ---'

"${build_dir}/scripts/make-playlists.sh" --verbose "${music_dir}"
echo ''
cat "${music_dir}/album.m3u"
echo ''

echo '--- make-age-list ---'

"${build_dir}/scripts/make-age-list.sh" --verbose \
	--out-file="${test_out_dir}/age.lst" "${music_dir}"
echo ''
cat "${test_out_dir}/age.lst"
echo ''

echo '--- make-inventory ---'

"${build_dir}/scripts/make-inventory.sh" --verbose \
	 --tracks --output-dir="${test_out_dir}/inventory" "${music_dir}"
echo ''

echo '--- make-shufflelist ---'

"${build_dir}/scripts/make-shufflelist.sh" --verbose \
	--count=1 --output-file="${test_out_dir}/shufflelist" "${music_dir}"
echo ''
cat "${test_out_dir}/shufflelist"
echo ''


echo '--- Done ---'

trap "on_exit 'Success'" EXIT
exit 0

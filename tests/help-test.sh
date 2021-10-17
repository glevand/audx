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
trap 'on_err SIGUSR1 ? 3' SIGUSR1

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

{
	echo ''
	echo '==========================================='
	echo "${script_name} (AUDX) - ${start_time}"
	echo '==========================================='
	echo ''
}

echo '--- show help ---'
readarray -t files_array < <(find "${build_dir}/install/bin" -type f -name '*.sh' | sort \
	|| { echo "${script_name}: ERROR: files_array find failed, function=${FUNCNAME[0]:-main}, line=${LINENO}, result=${?}" >&2; \
	kill -SIGUSR1 $$; } )

{
	for file in "${files_array[@]}"; do
		if [[ "${file}" == "${build_dir}/install/bin/audx-lib.sh" ]]; then
			continue
		elif [[ "${file}" == "${build_dir}/install/bin/audx-str-lib.sh" ]]; then
			continue
		fi

		echo '-------------------------'
		echo "Testing '${file}'"
		echo '-------------------------'
		$("${file}" --help)
	done
	echo '-------------------------'
}

echo '--- Done ---'

trap "on_exit 'Success'" EXIT
exit 0

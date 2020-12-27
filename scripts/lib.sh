#!/usr/bin/env bash

on_exit() {
	local result=${1}
	local sec="${SECONDS}"

	if [[ -d "${tmp_dir}" ]]; then
		rm -rf "${tmp_dir}"
	fi

	set +x
	echo "${script_name}: Done: ${result}, ${sec} sec ($(sec_to_min "${sec}") min)." >&2
}

sec_to_min() {
	local sec=${1}
	local min=$(( sec / 60 ))
	local frac_10=$(( (sec - min * 60) * 10 / 60 ))
	local frac_100=$(( (sec - min * 60) * 100 / 60 ))

	if (( frac_10 != 0 )); then
		unset frac_10
	fi

	echo "${min}.${frac_10}${frac_100}"
}

cpu_count() {
	local result

	if result="$(getconf _NPROCESSORS_ONLN)"; then
		echo "${result}"
	else
		echo "1"
	fi
}

check_dir_exists() {
	local msg="${1}"
	local dir="${2}"

	if [[ ! -d "${dir}" ]]; then
		echo "${script_name}: ERROR: ${msg} not found: '${dir}'" >&2
		exit 1
	fi
}

check_does_not_exist() {
	local msg="${1}"
	local dir="${2}"

	if [[ -f ${dir} ]]; then
		echo "${script_name}: ERROR: ${msg} file exists: '${dir}'." >&2
		exit 1
	fi
	if [[ -d ${dir} ]]; then
		echo "${script_name}: ERROR: ${msg} directory exists: '${dir}'." >&2
		exit 1
	fi
	if [[ -e ${dir} ]]; then
		echo "${script_name}: ERROR: ${msg} exists: '${dir}'." >&2
		exit 1
	fi
}

check_file() {
	local msg="${1}"
	local file="${2}"

	if [[ ! -f "${file}" ]]; then
		echo "${script_name}: ERROR: ${msg} not found: '${file}'" >&2
		exit 1
	fi
}

move_file() {
	local src=${1}
	local dest=${2}

	check_file 'source file' "${src}"

	if [[ ${verbose} ]]; then
		echo -e "${FUNCNAME[0]}: '${src}' -> '${dest}'" >&2
	else
		echo "${FUNCNAME[0]}: -> '${dest}'" >&2
	fi

	if [[ ! ${dry_run} ]]; then
		mkdir -p "${dest%/*}"
		mv --no-clobber "${src}" "${dest}"
	fi
}

check_program() {
	local prog="${1}"
	local path="${2}"

	if ! test -x "$(command -v "${path}")"; then
		echo "${script_name}: ERROR: Please install '${prog}'." >&2
		exit 1
	fi
}

check_opt() {
	option=${1}
	value="${2}"

	if [[ ! ${value} ]]; then
		echo "${script_name}: ERROR (${FUNCNAME[0]}): Must provide ${option} option." >&2
		usage
		exit 1
	fi
}

check_if_positive() {
	local name=${1}
	local val=${2}

	if [[ ! ${val##*[![:digit:]]*} || "${val}" -lt 1 ]]; then
		echo "${script_name}: ERROR: ${name} must be a positive integer.  Got '${val}'." >&2
		usage
		exit 1
	fi
}

check_top_dir() {
	local top_dir="${1}"

	if [[ ! ${top_dir} ]]; then
		echo "${script_name}: ERROR: No top-dir given." >&2
		usage
		exit 1
	fi

	if [[ ! -d ${top_dir} ]]; then
		echo "${script_name}: ERROR: Bad top-dir: '${top_dir}'" >&2
		usage
		exit 1
	fi
}

check_src_dirs() {
	local sd=("${@}")

	#echo "${FUNCNAME[0]}: src dirs: @${@}@" >&2
	#echo "${FUNCNAME[0]}: count: @${#sd[@]}@" >&2

	if [[ ${#sd[@]} -eq 0 ]]; then
		echo "${script_name}: ERROR: No source directories given." >&2
		usage
		exit 1
	fi

	for ((i = 0; i < ${#sd[@]}; i++)); do
		if [[ -d "${sd[i]}" ]]; then
			[[ ${debug} ]] && echo "${FUNCNAME[0]}: [$((i + 1))] '${sd[i]}' OK." >&2
		else
			echo "${script_name}: ERROR: Bad source directory: [$((i + 1))] '${sd[i]}'." >&2
			usage
			exit 1
		fi
	done
	[[ ${debug} ]] && echo "" >&2
	return 0
}

delete_empty_paths() {
	local dir=${1}
	local dry_run=${2}

	if [[ ${dry_run} ]]; then
		echo "${script_name}: INFO: Empty directories:" >&2
		find "${dir}" -depth -type d -empty
		echo "${script_name}: INFO: Empty files:" >&2
		find "${dir}" -depth -type f -empty
	else
		echo "${script_name}: INFO: Removing empty directories:" >&2
		find "${dir}" -depth -type d -empty -print -delete
		echo "${script_name}: INFO: Removing empty files:" >&2
		find "${dir}" -depth -type f -empty -print -delete
	fi
}

slash_count() {
	local path=${1}
	local count

	count="${path//[^\/]/}"
	echo "${#count}"
}

path_to_artist_album() {
	local path=${1}
	local -n _path_to_artist_album__pair="${2}"

	local regex="^.*/([^/]*)/([^/]*)$"

	if [[ ! "${path}" =~ ${regex} ]]; then
		echo "${FUNCNAME[0]}: ERROR: No match '${path}'" >&2
		exit 1
	fi

	_path_to_artist_album__pair[artist]="${BASH_REMATCH[1]}"
	_path_to_artist_album__pair[album]="${BASH_REMATCH[2]}"

	if [[ ${debug} ]]; then
		echo "${FUNCNAME[0]}: artist:  '${_path_to_artist_album__pair[artist]}'" >&2
		echo "${FUNCNAME[0]}: album: '${_path_to_artist_album__pair[album]}'" >&2
	fi
}

path_to_artist_album_title() {
	local path=${1}
	local -n _path_to_artist_album_title__triple="${2}"

	local regex="^.*/([^/]*)/([^/]*)/([^/]*)$"

	if [[ ! "${path}" =~ ${regex} ]]; then
		echo "${FUNCNAME[0]}: ERROR: No match '${path}'" >&2
		exit 1
	fi

	_path_to_artist_album_title__triple[artist]="${BASH_REMATCH[1]}"
	_path_to_artist_album_title__triple[album]="${BASH_REMATCH[2]}"
	_path_to_artist_album_title__triple[title]="${BASH_REMATCH[3]}"

	if [[ ${debug} ]]; then
		echo "${FUNCNAME[0]}: artist:  '${_path_to_artist_album_title__triple[artist]}'" >&2
		echo "${FUNCNAME[0]}: album: '${_path_to_artist_album_title__triple[album]}'" >&2
		echo "${FUNCNAME[0]}: title: '${_path_to_artist_album_title__triple[title]}'" >&2
	fi
}

clean_vfat_name() {
	local name=${1}

	#name="${name//[|\\<\":,]/}"
	name="${name//[:]/}"

	echo "${name}"
}

clean_tag() {
	local tag="${1}"

	tag="${tag//AC-DC/ACDC}"

	tag="${tag//U S A /USA}"
	tag="${tag//W M A /WMA}"

	tag="${tag//The Times They Are A‐Changin/The times They are a Changin}"
	tag="${tag//I Dont Want Your Love (Shep Pettibone 7″ mix)/I Dont Want Your Love (Shep Pettibone)}"

	tag="${tag//Disk/Disc}"
	tag="${tag//[Dd]isc 1/- Disc1}"
	tag="${tag//[Dd]isc 2/- Disc2}"
	tag="${tag//[Dd]isc 3/- Disc3}"
	tag="${tag//[Dd]isc 4/- Disc4}"
	tag="${tag//-- Disc/- Disc}"
	tag="${tag//- - Disc/- Disc}"

	# Album Disc1 -> Album - Disc1
	local regex="^(.*[^-]) (Disc[[:digit:]])"
	if [[ "${tag}" =~ ${regex} ]]; then
		tag="${BASH_REMATCH[1]} - ${BASH_REMATCH[2]}"
	fi

	tag="${tag//[\/\\]/-}"
	tag="${tag//_/ }"
	tag="${tag//;/,}"
	#tag="${tag//[()]/}"
	tag="${tag//\[/(}"
	tag="${tag//\]/)}"
	tag="${tag//[’\'\’\`\"!?]/}"
	tag="${tag//[èéé]/e}"
	tag="${tag//[à]/a}"
	tag="${tag//[~*<>|]/-}"

	tag="${tag//[@]/A}"
	tag="${tag//[+&]/and}"
	tag="${tag/ And The / and The }"
	tag="${tag//#/No. }"
	tag="${tag//  / }"
	tag="${tag//   / }"

	# trim leading space.
	tag="${tag#"${tag%%[![:space:]]*}"}"

	# trim trailing space.
	tag="${tag%"${tag##*[![:space:]]}"}"

	echo "${tag}"
}

flac_check_file() {
	local file=${1}
	local verbose=${2}

	if [[ "$(file "${file}")" != *'FLAC audio'* ]]; then
		if [[ ${verbose} ]]; then
			echo "${FUNCNAME[0]}: Not a flac file: '${file}'" >&2
		fi
		return 1
	fi
	return 0
}

flac_split_tag() {
	local tag=${1}
	local -n _flac_split_tag__pair="${2}"

	local regex_tag="([^=]+)=([^=]+)"

	if [[ ! "${tag}" =~ ${regex_tag} ]]; then
		echo "${FUNCNAME[0]}: ERROR: No match '${tag}'" >&2
		return 1
	fi

	_flac_split_tag__pair[name]="${BASH_REMATCH[1]}"
	_flac_split_tag__pair[value]="${BASH_REMATCH[2]}"

	if [[ ${debug} ]]; then
		echo "${FUNCNAME[0]}: name:  '${_flac_split_tag__pair[name]}'" >&2
		echo "${FUNCNAME[0]}: value: '${_flac_split_tag__pair[value]}'" >&2
	fi

	return 0
}

flac_get_tag() {
	local t_name=${1}
	local file=${2}
	local optional=${3}

	if [[ ${optional} && ${optional} != 'optional' ]]; then
		echo "${FUNCNAME[0]}: ERROR: Bad optional '${optional}'" >&2
		exit 1
	fi

	local tag

	tag="$(${metaflac} --show-tag="${t_name}" "${file}")"

	local regex_tag="[^=]+=([^=]+)"

	if [[ ! "${tag}" =~ ${regex_tag} ]]; then
		if [[ ${optional} == 'optional' ]]; then
			return
		fi
		echo "${FUNCNAME[0]}: ERROR: '${t_name}' not found in '${tag}'" >&2
		exit 1
	fi

	if [[ ${debug} ]]; then
		echo "${FUNCNAME[0]}: INFO: '${tag}' => '${BASH_REMATCH[1]}'." >&2
	fi

	echo "${BASH_REMATCH[1]}"
}

flac_print_tag_set() {
	local file="${1}"
	local -n _flac_print_tag_set__tags="${2}"

	echo "${FUNCNAME[0]}: file: '${file}'" >&2
	echo "${FUNCNAME[0]}:   artist:      '${_flac_print_tag_set__tags[artist]}'" >&2
	echo "${FUNCNAME[0]}:   album:       '${_flac_print_tag_set__tags[album]}'" >&2
	echo "${FUNCNAME[0]}:   title:       '${_flac_print_tag_set__tags[title]}'" >&2
	echo "${FUNCNAME[0]}:   tracknumber: '${_flac_print_tag_set__tags[tracknumber]}'" >&2
	echo "${FUNCNAME[0]}:   tracktotal:  '${_flac_print_tag_set__tags[tracktotal]}'" >&2
}

flac_fill_tag_set() {
	local file="${1}"
	local -n _flac_fill_tag_set__tags="${2}"

	if ! flac_check_file "${file}"; then
		return
	fi

	_flac_fill_tag_set__tags[artist]="$(flac_get_tag "artist" "${file}")"
	_flac_fill_tag_set__tags[album]="$(flac_get_tag "album" "${file}")"
	_flac_fill_tag_set__tags[title]="$(flac_get_tag "title" "${file}")"
	_flac_fill_tag_set__tags[tracknumber]="$(flac_get_tag "tracknumber" "${file}")"
	_flac_fill_tag_set__tags[tracktotal]="$(flac_get_tag "tracktotal" "${file}" 'optional')"

	_flac_fill_tag_set__tags[tracknumber]="${_flac_fill_tag_set__tags[tracknumber]#0}"
	if ((_flac_fill_tag_set__tags[tracknumber] < 10)); then
		_flac_fill_tag_set__tags[tracknumber]="0${_flac_fill_tag_set__tags[tracknumber]}"
	fi

	if [[ ${debug} ]]; then
		flac_print_tag_set "${file}" _flac_fill_tag_set__tags
	fi
}

flac_print_tags() {
	local file=${1}

	if ! flac_check_file "${file}"; then
		return
	fi

	declare -A tags

	flac_fill_tag_set "${file}" tags
	flac_print_tag_set "${file}" tags
}

metaflac_retag() {
	local file=${1}
	local tag_name=${2}
	local tag_data=${3}
	local add_tag=${4}

	if ! flac_check_file "${file}" 'verbose'; then
		return
	fi

	local old_tag

	if [[ ${add_tag} ]]; then
		old_tag="$(flac_get_tag "${tag_name}" "${file}" 'optional')"
	else
		old_tag="$(flac_get_tag "${tag_name}" "${file}")"
	fi

	echo "${FUNCNAME[0]}: file: '${file}'" >&2
	echo "${FUNCNAME[0]}:   ${tag_name}: '${old_tag}' => '${tag_data}'" >&2

	if [[ ! ${dry_run} ]]; then
		${metaflac} --preserve-modtime --remove-tag="${tag_name}" --set-tag="${tag_name}=${tag_data}" "${file}"
	fi
}

flac_meta_path() {
	local type=${1} # artist, various
	local src=${2}

	if ! flac_check_file "${src}" 'verbose'; then
		return
	fi

	declare -A tags

	flac_fill_tag_set "${src}" tags

	if [[ ${debug} ]]; then
		flac_print_tag_set "${src}" tags
	fi

	local dest

	case "${type}" in
	artist)
		dest="${tags[artist]}/${tags[album]}/${tags[tracknumber]}-${tags[title]}.flac"
		;;
	various)
		dest="${tags[album]}/${tags[tracknumber]}-${tags[artist]} - ${tags[title]}.flac"
		;;
	*)
		echo "${script_name}: ERROR: Internal: Bad type '${type}'" >&2
		exit 1
		;;
	esac

	echo "${dest}"
}

write_m3u_header() {
	local out_file=${1}
	local info=${2}
	local artist=${3}
	local album=${4}

	echo '#EXTM3U' >> "${out_file}"
	echo "#PLAYLIST: ${info}" >> "${out_file}"
	echo "#EXTART: ${artist}" >> "${out_file}"
	echo "#EXTALB: ${album}" >> "${out_file}"
	echo '' >> "${out_file}"
}

write_m3u_playlist() {
	local out_file=${1}
	local dir=${2}
	local type=${3}
	local canonical=${4}

	local files
	readarray files < <(find "${dir}" -maxdepth 1 -type f -name "*.${type}" | sort -n)

	if (( ${#files[@]} == 0 )); then
		if [[ ${verbose} ]]; then
			echo "No ${type} found: '${dir}'" >&2
		fi
		return
	fi

	if [[ ! ${canonical} ]]; then
		local i
		for (( i = 0; i < ${#files[@]}; i++ )); do
			files[i]="${files[i]##*/}"
		done
	fi

	printf "%s" "${files[@]}" > "${out_file}"
	echo "${script_name}: Wrote ${#files[@]} ${type} entries: '${out_file}'" >&2
}

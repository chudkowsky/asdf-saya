#!/usr/bin/env bash

set -euo pipefail

# This is the correct GitHub homepage where releases can be downloaded for saya.
GH_REPO="https://github.com/dojoengine/saya"
TOOL_NAME="saya"
TOOL_TEST="saya --help"

# Binary layout per version:
#   < 0.3.0  — single saya archive (legacy)
#   0.3.0    — persistent + ops archives (renamed on install to saya, saya-ops)
#   >= 0.3.1 — saya + saya-ops + saya-tee archives (names match, no rename needed)
declare -A SAYA_BINARIES_030=(
	["persistent"]="saya"
	["ops"]="saya-ops"
)
SAYA_BINARIES_031=("saya" "saya-ops" "saya-tee")

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//'
}

list_all_versions() {
	list_github_tags
}

# Cribbed from https://github.com/dojoengine/dojo/blob/main/dojoup/dojoup
detect_platform_arch() {
	local platform arch ext

	platform="$(uname -s)"
	arch="$(uname -m)"
	ext="tar.gz"

	case $platform in
	Linux)
		platform="linux"
		;;
	Darwin)
		platform="darwin"
		;;
	MINGW* | MSYS* | CYGWIN*)
		ext="zip"
		platform="win32"
		;;
	*)
		fail "unsupported platform: $platform"
		;;
	esac

	if [ "${arch}" = "x86_64" ]; then
		if [ "$platform" = "darwin" ] && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = "1" ]; then
			arch="arm64"
		else
			arch="amd64"
		fi
	elif [ "${arch}" = "arm64" ] || [ "${arch}" = "aarch64" ]; then
		arch="arm64"
	else
		arch="amd64"
	fi

	echo "$platform $ext $arch"
}

get_release_filename() {
	local binary_name="$1"
	local version="$2"

	read -r PLATFORM EXT ARCH <<<"$(detect_platform_arch)"

	# i.e. persistent_v0.3.1_linux_amd64.tar.gz
	echo "${binary_name}_v${version}_${PLATFORM}_${ARCH}.${EXT}"
}

version_gte() {
	local version="$1" major minor patch ref_major ref_minor ref_patch
	IFS='.' read -r major minor patch <<<"$version"
	IFS='.' read -r ref_major ref_minor ref_patch <<<"$2"
	[ "${major:-0}" -gt "${ref_major:-0}" ] ||
		{ [ "${major:-0}" -eq "${ref_major:-0}" ] && [ "${minor:-0}" -gt "${ref_minor:-0}" ]; } ||
		{ [ "${major:-0}" -eq "${ref_major:-0}" ] && [ "${minor:-0}" -eq "${ref_minor:-0}" ] && [ "${patch:-0}" -ge "${ref_patch:-0}" ]; }
}

download_archive() {
	local binary_name="$1" version="$2"
	local filename filepath url
	filename="$(get_release_filename "$binary_name" "$version")"
	filepath="$ASDF_DOWNLOAD_PATH/$filename"
	url="$GH_REPO/releases/download/v${version}/${filename}"

	echo "* Downloading $binary_name $version..."
	curl "${curl_opts[@]}" -o "$filepath" -C - "$url" || fail "Could not download $url"

	if [[ "$filename" == *.zip ]]; then
		unzip -q "$filepath" -d "$ASDF_DOWNLOAD_PATH" || fail "Could not extract $filename"
	else
		tar -xzf "$filepath" -C "$ASDF_DOWNLOAD_PATH" || fail "Could not extract $filename"
	fi

	rm "$filepath"
}

download_all_releases() {
	local version="$1"

	if version_gte "$version" "0.3.1"; then
		for binary_name in "${SAYA_BINARIES_031[@]}"; do
			download_archive "$binary_name" "$version"
		done
	elif version_gte "$version" "0.3.0"; then
		for binary_name in "${!SAYA_BINARIES_030[@]}"; do
			download_archive "$binary_name" "$version"
		done
	else
		download_archive "saya" "$version"
	fi
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"

		if version_gte "$version" "0.3.1"; then
			# Archive names match install names — copy directly
			for binary_name in "${SAYA_BINARIES_031[@]}"; do
				cp "$ASDF_DOWNLOAD_PATH/$binary_name" "$install_path/$binary_name" \
					|| fail "Could not find $binary_name in download path"
				chmod +x "$install_path/$binary_name"
			done
		elif version_gte "$version" "0.3.0"; then
			# Archive names differ — rename on install
			for binary_name in "${!SAYA_BINARIES_030[@]}"; do
				local install_name="${SAYA_BINARIES_030[$binary_name]}"
				cp "$ASDF_DOWNLOAD_PATH/$binary_name" "$install_path/$install_name" \
					|| fail "Could not find $binary_name in download path"
				chmod +x "$install_path/$install_name"
			done
		else
			cp "$ASDF_DOWNLOAD_PATH/saya" "$install_path/saya" \
				|| fail "Could not find saya binary in download path"
			chmod +x "$install_path/saya"
		fi

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}

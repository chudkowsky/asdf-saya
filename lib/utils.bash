#!/usr/bin/env bash

set -euo pipefail

# This is the correct GitHub homepage where releases can be downloaded for saya.
GH_REPO="https://github.com/dojoengine/saya"
TOOL_NAME="saya"
TOOL_TEST="saya --help"

# Maps release archive binary name → installed command name
declare -A SAYA_BINARIES=(
	["persistent"]="saya"
	["ops"]="saya-ops"
	["persistent-tee"]="saya-tee"
)

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

# Returns true if version >= 0.3.0 (split workspace releases)
is_split_release() {
	local version="$1"
	local major minor
	major="$(echo "$version" | cut -d. -f1)"
	minor="$(echo "$version" | cut -d. -f2)"
	[ "$major" -gt 0 ] || { [ "$major" -eq 0 ] && [ "$minor" -ge 3 ]; }
}

download_all_releases() {
	local version="$1"

	if is_split_release "$version"; then
		# v0.3.0+: three separate archives (persistent, ops, persistent-tee)
		for binary_name in "${!SAYA_BINARIES[@]}"; do
			local filename
			filename="$(get_release_filename "$binary_name" "$version")"
			local filepath="$ASDF_DOWNLOAD_PATH/$filename"
			local url="$GH_REPO/releases/download/v${version}/${filename}"

			echo "* Downloading $binary_name $version..."
			curl "${curl_opts[@]}" -o "$filepath" -C - "$url" || fail "Could not download $url"

			if [[ "$filename" == *.zip ]]; then
				unzip -q "$filepath" -d "$ASDF_DOWNLOAD_PATH" || fail "Could not extract $filename"
			else
				tar -xzf "$filepath" -C "$ASDF_DOWNLOAD_PATH" || fail "Could not extract $filename"
			fi

			rm "$filepath"
		done
	else
		# legacy: single saya_v* archive containing one saya binary
		local filename
		filename="$(get_release_filename "saya" "$version")"
		local filepath="$ASDF_DOWNLOAD_PATH/$filename"
		local url="$GH_REPO/releases/download/v${version}/${filename}"

		echo "* Downloading saya $version (legacy)..."
		curl "${curl_opts[@]}" -o "$filepath" -C - "$url" || fail "Could not download $url"

		if [[ "$filename" == *.zip ]]; then
			unzip -q "$filepath" -d "$ASDF_DOWNLOAD_PATH" || fail "Could not extract $filename"
		else
			tar -xzf "$filepath" -C "$ASDF_DOWNLOAD_PATH" || fail "Could not extract $filename"
		fi

		rm "$filepath"
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

		if is_split_release "$version"; then
			for binary_name in "${!SAYA_BINARIES[@]}"; do
				local install_name="${SAYA_BINARIES[$binary_name]}"
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

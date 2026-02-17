#!/usr/bin/env bash
	OS_SUFFIX=""
    ARCH_SUFFIX=""
	
	# determine the gh runner OS 
    case "$RUNNER_OS" in
      "Windows")
        OS_SUFFIX="windows"
        ARCH_SUFFIX="amd64.exe"
        ;;
      "Linux")
        OS_SUFFIX="linux"
        if [ "$RUNNER_ARCH" == "aarch64" ]; then
          ARCH_SUFFIX="arm64"
        else
          ARCH_SUFFIX="amd64"
        fi
        ;;
      "macOS")
        OS_SUFFIX="macos"
        if [ "$RUNNER_ARCH" == "arm64" ]; then
          ARCH_SUFFIX="arm64"
        else
          ARCH_SUFFIX="amd64"
        fi
        ;;
      *)
        echo "Unsupported Github runner OS: $RUNNER_OS"
        exit 1
        ;;
    esac

	# check if action version for the asset was passed
    if [ -z "$ACTION_VERSION" ]; then
          echo "Could not determine action version (ACTION_VERSION was empty)"
          exit 1
    fi

    ASSET_NAME="${STEP_NAME}-${ACTION_VERSION}-${OS_SUFFIX}-${ARCH_SUFFIX}"
    DOWNLOAD_PATH="/tmp"
    HOST_URL="https://github.com/${ACTION_REPO}/releases/download"
	# temp -- 
	echo "Host URL generated is: ${HOST_URL}" 
	# --- 
    RELEASE_URL="${HOST_URL}/${ACTION_VERSION}/${ASSET_NAME}"

    echo "Downloading asset: ${RELEASE_URL}"

    # download the asset using gh if the token is available and the asset is not downloaded
    if [ ! -f "${DOWNLOAD_PATH}/${ASSET_NAME}" ]; then
        if [ -n "${GH_TOKEN:-}" ]; then
            gh release download ${ACTION_VERSION} --pattern ${ASSET_NAME} --dir ${DOWNLOAD_PATH} --repo ${ACTION_REPO} || \
			curl -sSfL -o "${DOWNLOAD_PATH}/${ASSET_NAME}" "${RELEASE_URL}"
        else
            curl -sSfL -o "${DOWNLOAD_PATH}/${ASSET_NAME}" "${RELEASE_URL}"
        fi
    fi

	# check if the asset was downloaded
	if [ ! -f "${DOWNLOAD_PATH}/${ASSET_NAME}" ]; then
		echo "Failed to download asset: ${ASSET_NAME}"
		exit 1
	fi

	# start the execution
    chmod +x "$DOWNLOAD_PATH/${ASSET_NAME}"
    "$DOWNLOAD_PATH/${ASSET_NAME}"
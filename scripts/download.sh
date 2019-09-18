#!/bin/bash
source scripts/utils.sh echo -n

# Saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail

# This script is meant to be used with the command 'datalad run'

function delete_remote {
	echo "Deleting ${REMOTE} access token"
	rclone config delete ${REMOTE}
}

test_enhanced_getopt

PARSED=$(enhanced_getopt --options "d,h" --longoptions "directory:,client-id:,secret:,help" --name "$0" -- "$@")
eval set -- "${PARSED}"

CLIENT_ID=$(git config --file scripts/cub200_config --get google.client-id)
CLIENT_SECRET=$(git config --file scripts/cub200_config --get google.client-secret)
REMOTE=__gdrive

while [[ $# -gt 0 ]]
do
	arg="$1"; shift
	case "${arg}" in
		--client-id) CLIENT_ID="$1"; shift
		echo "client-id = [${CLIENT_ID}]"
		;;
		--secret) CLIENT_SECRET="$1"; shift
		echo "secret = [${CLIENT_SECRET}]"
		;;
		-h | --help)
		>&2 echo "Options for $(basename "$0") are:"
		>&2 echo "[-d | --directory GDRIVE_DIR_ID] Google Drive root directory id (optional)"
		>&2 echo "[--client-id CLIENT_ID] Google application client id (optional)"
		>&2 echo "[--secret CLIENT_SECRET] OAuth Client Secret (optional)"
		exit 1
		;;
		--) break ;;
		*) >&2 echo "Unknown argument [${arg}]"; exit 3 ;;
	esac
done

init_conda_env --name rclone --tmp .tmp/
conda install --yes --strict-channel-priority --use-local -c defaults -c conda-forge rclone=1.57.0

trap delete_remote EXIT

if [[ -z "$(rclone listremotes | grep -o "^${REMOTE}:")" ]]
then
	echo "Configuring the rclone remote. Use default values when asked."
	rclone config create ${REMOTE} drive client_id ${CLIENT_ID} \
		client_secret ${CLIENT_SECRET} \
		scope "drive.readonly" \
		root_folder_id "" \
		config_is_local false \
		config_refresh_token false \
		service_account_file "" \
		--all
fi

files_id=(
	"1hbzc_P1FuxMkcabkgn9ZKinBwW683j45 CUB_200_2011.tgz" \
	"1EamOKGLoTuZdtcVYbHMWNpkn3iAVj8TP segmentations.tgz" \
	"1V9K2577M5KwcKVVHAFjQQ4Z4N9_zMnf0 README.txt")

for file_id in "${files_id[@]}"
do
	rclone_copy --remote ${REMOTE} -- "${file_id}"
done

[[ -f md5sums ]] && md5sum -c md5sums
[[ -f md5sums ]] || md5sum $(git-annex list --fast | grep -o " .*") \
	CUB_200_2011.tgz \
	segmentations.tgz > md5sums

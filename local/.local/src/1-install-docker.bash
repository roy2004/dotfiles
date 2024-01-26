set -eu${DEBUG+x}o pipefail

case $(arch) in
x86_64)
	ARCH=x86_64
	;;
aarch64)
	ARCH=aarch64
	;;
*)
	echo 'unknown architecture' 1>&2
	exit 1
	;;
esac

DOWNLOAD_URL=$(curl -SsLf 'https://api.github.com/repos/docker/cli/tags' | python3 -c '
import json
import re
import sys

tags = json.loads(sys.stdin.read())
download_url = None
for tag in tags:
    if re.match(r"v\d+\.\d+\.\d+$", tag["name"]) is not None:
        download_url = "https://download.docker.com/linux/static/stable/'${ARCH}'/docker-{}.tgz".format(tag["name"][1:])
        break
if download_url is None:
    print("download url not found", file=sys.stderr)
    sys.exit(1)
print(download_url)
')
TEMP_DIR=$(mktemp --directory)
curl -SsLf "${DOWNLOAD_URL}" | tar xz --directory "${TEMP_DIR}"
install "${TEMP_DIR}/docker/docker" "${HOME}/.local/bin/docker"
rm --force --recursive "${TEMP_DIR}"

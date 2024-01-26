set -eu${DEBUG+x}o pipefail

DOWNLOAD_URL=$(curl -SsLf 'https://api.github.com/repos/hq6/ProtobufJson/tags' | python3 -c '
import json
import re
import sys

tags = json.loads(sys.stdin.read())
download_url = None
for tag in tags:
    if re.match(r"v\d+\.\d+\.\d+.*$", tag["name"]) is not None:
        download_url = "https://github.com/hq6/ProtobufJson/archive/refs/tags/{}.tar.gz".format(tag["name"])
        break
if download_url is None:
    print("download url not found", file=sys.stderr)
    sys.exit(1)
print(download_url)
')
CACHE_FILE=/gdrive/build-cache/f$(grep --perl-regexp --only-matching '(?<=Fedora release )\d+' /etc/fedora-release).$(arch)/ProtobufJson-$(grep --perl-regexp --only-matching '(?<=v)[^/]+$' <<<"${DOWNLOAD_URL}")
if [[ -f ${CACHE_FILE} ]]; then
	download() { cat "${CACHE_FILE}"; }
	USE_CACHE=1
else
	download() { curl -SsLf "${DOWNLOAD_URL}"; }
	USE_CACHE=0
fi
TEMP_DIR=$(mktemp --directory)
download | tar xz --directory "${TEMP_DIR}"
cd "${TEMP_DIR}/ProtobufJson-"*
make --silent
install ProtobufJson "${HOME}/.local/bin/ProtobufJson"
cd -
if [[ ${USE_CACHE} -eq 0 ]]; then
	mkdir --parents "$(dirname "${CACHE_FILE}")"
	tar czf "${CACHE_FILE}.tmp" -C "${TEMP_DIR}" .
	mv "${CACHE_FILE}.tmp" "${CACHE_FILE}"
fi
rm --force --recursive "${TEMP_DIR}"

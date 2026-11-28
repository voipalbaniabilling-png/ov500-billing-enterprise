#!/bin/bash
set -euo pipefail
umask 077
# No flags means the complete unattended fresh installation.
if [[ $# -eq 0 ]]; then set -- --automatic; fi
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APPLY=false
for option in "$@"; do [[ "$option" != --apply && "$option" != --automatic ]] || APPLY=true; done
if "$APPLY"; then
    if [[ $EUID -ne 0 ]]; then echo 'Run with sudo: sudo bash install.sh' >&2; exit 1; fi
    . /etc/os-release
    if [[ "$ID" != ubuntu || "$VERSION_ID" != 24.04 || "$(uname -m)" != x86_64 ]]; then echo 'A clean Ubuntu Server 24.04 amd64 host is required.' >&2; exit 1; fi
    for marker in /etc/ov500/jobs.conf /etc/systemd/system/ov500-go@.service /usr/local/libexec/ov500-fs-engine; do
        if [[ -e "$marker" ]]; then echo 'Existing OV500 installation detected; nothing was overwritten.' >&2; exit 1; fi
    done
fi
if ! command -v python3 >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1 || [[ ! -s /etc/ssl/certs/ca-certificates.crt ]] || { "$APPLY" && ! command -v ip >/dev/null 2>&1; }; then
    if ! "$APPLY"; then echo 'Python3, OpenSSL and CA certificates are required for verification.' >&2; exit 1; fi
    export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical NEEDRESTART_MODE=a UCF_FORCE_CONFFOLD=1
    apt-get update -qq
    apt-get -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold install -y python3 openssl ca-certificates iproute2
fi
if [[ -f "$SCRIPT_DIR/download-install.py" && -f "$SCRIPT_DIR/release.json" ]]; then
    exec python3 "$SCRIPT_DIR/download-install.py" "$@"
fi
# The downloaded install.sh is standalone: fetch its matching, immutable bootstrap.
BOOTSTRAP_DIR="$(mktemp -d /tmp/voipalbania-bootstrap.XXXXXXXX)"
trap 'rm -rf -- "$BOOTSTRAP_DIR"' EXIT
python3 - "$BOOTSTRAP_DIR" <<'PY'
import pathlib,sys,urllib.request,ssl
root=pathlib.Path(sys.argv[1])
base='https://raw.githubusercontent.com/voipalbaniabilling-png/ov500-billing-enterprise/v1.0.39-r57/'
for name in ['download-install.py','release.json']:
 request=urllib.request.Request(base+name,headers={'User-Agent':'VOIPALBANIA-Installer/1.0'})
 with urllib.request.urlopen(request,context=ssl.create_default_context(),timeout=120)as response:
  if not response.url.startswith('https://'):raise RuntimeError('HTTPS bootstrap required')
  data=response.read(1024*1024+1)
 if len(data)>1024*1024:raise RuntimeError('Bootstrap exceeds size allowance')
 (root/name).write_bytes(data)
PY
python3 "$BOOTSTRAP_DIR/download-install.py" "$@"

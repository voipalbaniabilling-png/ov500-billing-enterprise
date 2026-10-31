#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v python3 >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1 || [[ ! -s /etc/ssl/certs/ca-certificates.crt ]]; then
    if [[ " $* " != *" --apply "* ]]; then
        echo 'Python3, OpenSSL and CA certificates are required. On Ubuntu 24.04: sudo apt-get install python3 openssl ca-certificates' >&2
        exit 1
    fi
    if [[ $EUID -ne 0 ]]; then echo 'Run the installer with sudo.' >&2; exit 1; fi
    . /etc/os-release
    if [[ "$ID" != ubuntu || "$VERSION_ID" != 24.04 ]]; then echo 'Ubuntu 24.04 required.' >&2; exit 1; fi
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y python3 openssl ca-certificates
fi
exec python3 "$SCRIPT_DIR/download-install.py" "$@"

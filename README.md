# VOIP Albania OV500 Billing

Public project page for the VOIP Albania OV500 Billing platform and its FreeSWITCH management integrations.

This repository is the public installation entry point for approved OV500 releases. At installation time, the bootstrap installer and release metadata come from this GitHub repository; the complete protected Billing + GO setup is downloaded from its pinned, signed GitHub Release asset in the same repository. Customer data, credentials, server configuration, backups, call records, and license material are not included.

## Project

OV500 Billing is a telecommunications billing and operations platform designed to work with FreeSWITCH environments. The project focuses on preserving the platform's billing and routing workflows while providing management and operational visibility for connected FreeSWITCH servers.

## Releases and installer

The installation is delivered through GitHub end to end: clone this small bootstrap repository, then run `install.sh`. The script fetches the complete setup archive and detached Ed25519 signature from a fixed GitHub Release in this same repository. It verifies the signature with a pinned publisher key, then checks SHA-256 and the internal file manifest before running the native installer. The 186 MB product archive is a GitHub Release asset rather than a normal Git file, because Git hosting rejects ordinary repository blobs above 100 MB. The installer does not download executable code from the moving `main` branch.

The package candidate has passed isolated Ubuntu 24.04/PHP 7.4 acceptance, and its SHA-256 is recorded in `release.json`. The release metadata pins `voipalbaniabilling-png/ov500-billing-enterprise`, tag `v1.0.0`, the archive SHA-256, and the detached signature filename. Installation is available only after the matching signed Release assets are published and verified.

After a signed release is published, the expected flow is:

```bash
git clone --branch v1.0.0 --depth 1 https://github.com/voipalbaniabilling-png/ov500-billing-enterprise.git
cd ov500-billing-enterprise
sudo ./install.sh --prepare
sudo cp install-config.example.json /root/ov500-install.json
sudo chmod 600 /root/ov500-install.json
# Edit the new server's URL, timezone, company and admin email.
sudo ./install.sh --config /root/ov500-install.json --apply
sudo ./install.sh --config /root/ov500-install.json --verify
```

`--prepare` only downloads, verifies and unpacks the release in a private work directory. `--apply` is for a new Ubuntu 24.04 server only and refuses an existing OV500 installation or populated schemas. The installer creates fresh admin/database/encryption credentials; it does not import source-server customer or financial data.

## Security

Please do not publish credentials, customer information, call detail records, server addresses, private configuration, or readable protected source files in this repository. Report security issues privately to the project owner.

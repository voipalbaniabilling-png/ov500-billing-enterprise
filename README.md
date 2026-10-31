# VOIPALBANIA OV500 Billing

OV500 Billing is a telecommunications billing and operations platform for service providers using FreeSWITCH. It brings customer and reseller accounts, carrier management, rating, routing, invoices, CDR reporting, and multi-server FreeSWITCH administration together in one web panel.

The platform is designed to manage more than one remote FreeSWITCH server from the same Billing installation. Billing remains the control and financial system; FreeSWITCH handles SIP call processing. See [FEATURES.md](FEATURES.md) for the detailed feature overview.

## Key capabilities

- Manage customers, resellers, carriers, SIP users, IP-authenticated trunks, DIDs, rate plans, bundles, routes, and billing settings.
- Rate customer and carrier usage through the platform’s native billing and CDR workflows, with prepaid and postpaid account support, configurable billing increments, currencies, taxes, invoices, and statements.
- Connect and administer multiple remote FreeSWITCH servers, SIP profiles, and gateways; review connection and gateway status and deploy generated configuration through the FS Manager.
- Monitor calls, CDR outcomes, financial reports, server health, security events, scheduled jobs, and system maintenance from role-appropriate dashboards.
- Use the included GO service components for per-FreeSWITCH processing and operational integration where enabled by the installed release.

## Trial requests

To request a free trial, email [voipalbaniabilling@gmail.com](mailto:voipalbaniabilling@gmail.com?subject=OV500%20Free%20Trial%20Request&body=Contact%20name%3A%0ACompany%3A%0ABusiness%20email%3A%0ACountry%3A%0ADeployment%20URL%20or%20domain%3A%0ALicense%20request%20or%20installation%20ID%20(if%20available)%3A%0ANumber%20of%20FreeSWITCH%20servers%3A%0ARequested%20trial%20period%3A%0A). Include your contact name, organization, business email, country, intended deployment URL or domain, license request or installation ID if available, number of FreeSWITCH servers, and requested trial period. The VOIPALBANIA license administrator reviews each request and creates the trial in the administrator-owned licensing panel. If approved, the administrator sends the applicant an activation key and instructions for entering it in the applicant's own Billing license page.

Applicants do not access the VOIPALBANIA licensing panel. Do not email administrator passwords, SIP secrets, SSH credentials, API tokens, private keys, or an existing activation key. The license administrator issues the trial key; the applicant enters it in their own Billing license page.

## Installation from Git

The Git repository is intended to contain the small installer/bootstrap and documentation. During installation, the bootstrap downloads the complete protected Billing + GO package and its detached Ed25519 signature from a pinned GitHub Release asset. It checks the publisher signature, the configured SHA-256 digest, and the package manifest before handing the verified package to its native installer. OpenSSL is required for signature verification; Python 3 and trusted CA certificates are required for HTTPS downloads.

The release metadata in `release.json` must identify the actual public `OWNER/REPOSITORY`, immutable release tag, asset filename, matching SHA-256, and signature filename before the public installer can download a release. Those values must refer to the exact package and signature approved for publication. Do not replace the pinned public verification key to work around a failed signature. Never publish the signing private key. The installer is not ready for public installation until the signed release assets and this metadata have been verified together.

The native installer is designed for a clean Ubuntu 24.04 amd64 host with PHP 7.4 compatibility. It generates fresh installation credentials and application secrets; it must not copy runtime credentials, customer records, or deployment configuration from another Billing installation. SMTP, payment services, DNS/TLS, license activation, and remote FreeSWITCH access still require owner-supplied configuration and acceptance.

A separate Debian 12 installer is maintained for FreeSWITCH servers. Its script is not included in this Git repository yet; it is planned for a later publication after separate review. FreeSWITCH installation and Billing installation are separate steps, and the FreeSWITCH installer does not configure customer routes or authorize live traffic by itself.

## Release status

This repository is being prepared as the public project and installation entry point. A protected package is still a private candidate; do not treat this repository as an approved production installer until an exact release has passed its release gates, signing-key custody is established, the matching signed release assets are published, and `release.json` points to those exact assets. Third-party components remain subject to their respective licenses and notices.

## Security and privacy

Never publish customer information, CDRs, live server addresses, runtime configuration, credentials, private signing keys, or protected package contents in public issues or pull requests. Report security concerns privately using the trial/contact email above.

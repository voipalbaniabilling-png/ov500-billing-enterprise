# VOIPALBANIA OV500 — VoIP Billing for FreeSWITCH

VOIPALBANIA OV500 is a VoIP billing and telecom operations platform for service providers using FreeSWITCH. It brings real-time billing, prepaid and postpaid customer accounts, reseller billing, carrier management, SIP call routing, multi-currency billing, invoices and CDR reporting together in one web panel. Its FS Manager administers multiple remote FreeSWITCH servers with dedicated Go engines.

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

## Automatic installation — Ubuntu Server 24.04 amd64

The complete Billing + GO system installs from a single executable `install.sh`. Run it in a **root terminal** on a clean Ubuntu Server24.04amd64 machine. No JSON file, domain, email, certificate, username or password needs to be entered during installation.

If the executable script has already been downloaded:

```bash
./install.sh
```

One-line download and execution (this also sets the executable permission Linux requires for a downloaded file):

```bash
wget -q https://raw.githubusercontent.com/voipalbaniabilling-png/ov500-billing-enterprise/main/install.sh -O install.sh && chmod 700 install.sh && ./install.sh
```

The script downloads its matching immutable bootstrap, the complete protected package and signature; verifies Ed25519, SHA256 and the full manifest; installs dependencies, database, panel, GO components and scheduled services; then runs the native installation checks. It discovers the new server's network address and timezone. Existing resource planning uses the target machine's CPU/RAM/cgroup/database limits and storage budgets; it does not copy another server's capacity settings.

At completion, the terminal displays **Panel URL, Administrator username and Administrator password**. The panel initially opens by the detected local IP with HTTPS on443; port80 redirects browser traffic while preserving the native API and ACME paths. No8080 or SSH tunnel is required. The initial IP certificate is generated locally and is self-signed; a browser may require accepting it. Configure company details, domain and free public SSL later from the panel. The installer automatically prepares that Domain & SSL service.

Every installation generates new administrator/database credentials and encryption keys. No customer/carrier records, CDRs, invoices, balances, sessions, working-company settings or source-server credentials are included. Keep the final credential receipt private. License activation, company details, SMTP and remote FreeSWITCH connections are configured through the web after installation; they are not interactive installer questions.

The installer refuses existing/partial deployments instead of erasing databases or replacing another system. It needs root privileges and working access to Ubuntu/PHP/GitHub repositories. Downloaded files must have executable permission; Git clones preserve the script's executable mode. A normal OS permission or external network/package failure cannot be bypassed by the installer.

### Verification only

```bash
./install.sh --prepare
```

This downloads and verifies without installing services or databases. It is not a full installation. Manual `--config` is an optional advanced mode, not required for the normal automatic installation.

### Current release and test scope

Panel version **v1.0.39**, corrected automatic installer **r57**. Signed packages, full manifests, installer plans, native financial/CDR regressions, automatic configuration/credential handoff and isolated HTTP/HTTPS tests are verified. The matching release notes record full-installation acceptance and remaining limitations. Only the approved Latest release is recommended for installation.

FreeSWITCH is installed separately on its own Debian12server with `install-fs.sh`; Billing installation does not change an existing FreeSWITCH server or admit traffic by itself.

## Security and privacy

Never publish customer information, CDRs, live server addresses, runtime configuration, credentials, private signing keys, or protected package contents in public issues or pull requests. Report security concerns privately using the trial/contact email above.

### Ubuntu automatic updates

Fresh installation configures unattended updates for Ubuntu security repositories only (including ESM security when enabled). Regular package updates and Ubuntu release upgrades remain manual. Automatic reboot is disabled; a kernel security update may require a planned reboot. Third-party repositories are not automatically trusted as security sources.

# Connect a Debian 12 FreeSWITCH server to OV500 Billing

This guide describes the complete operator path after installing FreeSWITCH with `fs-server/install-fs.sh`. It contains no site credentials or private addresses. Replace every placeholder with values belonging to the new deployment; never publish the resulting values.

## 1. Install and verify FreeSWITCH

Clone/download the approved repository on the new Debian 12 FreeSWITCH host, then run these commands from its root directory (where `fs-server/` is present):

```sh
sudo bash fs-server/install-fs.sh --check
sudo bash fs-server/install-fs.sh --install
sudo bash fs-server/install-fs.sh --verify
```

The installer builds pinned upstream versions and creates a fresh, isolated FreeSWITCH configuration. It does not copy users, gateways, routes, Billing credentials, or customer data from another server. It deliberately leaves ESL on loopback and XML-Curl pointed to an unconfigured loopback URL. Therefore, a successful installer run means FreeSWITCH is installed and locally verified; it does **not** mean that the Billing connection or live-call path is ready.

Important paths on the FreeSWITCH host:

| Purpose | Path / service |
| --- | --- |
| FreeSWITCH XML configuration | `/etc/freeswitch/` |
| ESL listener and generated ESL secret | `/etc/freeswitch/autoload_configs/event_socket.conf.xml` |
| XML-Curl bootstrap configuration | `/etc/freeswitch/autoload_configs/xml_curl.conf.xml` |
| Runtime CDR spool and recordings | `/var/lib/freeswitch/` |
| FreeSWITCH logs | `/var/log/freeswitch/` |
| Installer state and protected pre-install backup | `/var/lib/ov500-fs-install/` |
| Service | `freeswitch.service` |

Do not copy the ESL secret into this repository, a command-line argument, a ticket, or a screenshot. Keep the generated secret private and enter it only into the protected Billing form described below.

## 2. Prepare the FreeSWITCH host before opening the Billing panel

This is the important handoff point between installation and Billing registration. Complete these server-side steps first. They establish only the secure management paths; they do not add SIP customers, carrier routes, or production traffic.

**Sequence:** install FreeSWITCH → set up a private ESL listener and ACL → prepare and verify SSH management access → confirm HTTPS reachability to Billing → register the node in Billing → let Billing generate and deploy its per-server XML/profile configuration.

### 2.1 Record the deployment-specific network values

Before changing the server, identify and record privately:

- the FreeSWITCH management-interface address that the Billing host can reach;
- the Billing host's source address as seen by FreeSWITCH;
- the Billing HTTPS hostname and its trusted TLS certificate chain;
- the SIP profile addresses/ports and RTP range that will later be configured for this node.

Use these actual values only in the server's private configuration and the protected Billing form. Do not copy values from FS41 or another deployment. Do not open SIP/RTP ports yet: the fresh install has no SIP profiles or gateways, and their exact ports are not known until the operator designs them in Billing.

### 2.2 Establish and restrict the ESL path

The installer creates `/etc/freeswitch/autoload_configs/event_socket.conf.xml` with ESL bound to `127.0.0.1`, port `8021`, a randomly generated secret, and `loopback.auto` ACL. This is deliberately local-only. The Billing panel connects to ESL directly over TCP; it does **not** tunnel ESL through SSH. Before the panel can register or deploy this node, change the ESL listener to the FreeSWITCH management-interface address and permit only the Billing host.

On the FreeSWITCH host, first make a private backup. Run this from its SSH session:

```sh
sudo install -d -o root -g root -m 0700 /var/backups/ov500-fs-before-billing
stamp=$(date -u +%Y%m%dT%H%M%SZ)
sudo cp -a /etc/freeswitch/autoload_configs/event_socket.conf.xml \
  "/var/backups/ov500-fs-before-billing/event_socket.conf.xml.$stamp"
if sudo test -f /etc/freeswitch/autoload_configs/acl.conf.xml; then
  sudo cp -a /etc/freeswitch/autoload_configs/acl.conf.xml \
    "/var/backups/ov500-fs-before-billing/acl.conf.xml.$stamp"
fi
```

If `acl.conf.xml` already exists, stop and merge the management ACL into it. Do not overwrite the existing ACLs. On the fresh install, where the file is absent, create it as follows. Replace the placeholder before running the command; do not leave a placeholder in the active file:

```xml
<configuration name="acl.conf" description="Network Lists">
  <network-lists>
    <list name="ov500_billing_management" default="deny">
      <node type="allow" cidr="127.0.0.1/32" />
      <node type="allow" cidr="::1/128" />
      <node type="allow" cidr="BILLING_SOURCE_IP/32" />
    </list>
  </network-lists>
</configuration>
```

Create the file using `sudoedit /etc/freeswitch/autoload_configs/acl.conf.xml`, paste the XML, replace `BILLING_SOURCE_IP` with the Billing server's actual source address, save, then set its owner/mode:

```sh
sudo chown root:freeswitch /etc/freeswitch/autoload_configs/acl.conf.xml
sudo chmod 0640 /etc/freeswitch/autoload_configs/acl.conf.xml
```

For a single IPv6 Billing address, use the actual IPv6 address with `/128`. This ACL preserves local loopback administration while allowing only the Billing host. In `/etc/freeswitch/autoload_configs/event_socket.conf.xml`, change only `listen-ip` to the FS management-interface address and `apply-inbound-acl` to `ov500_billing_management`. Keep `listen-port` and the generated `password` unchanged. Edit it with:

```sh
sudoedit /etc/freeswitch/autoload_configs/event_socket.conf.xml
```

Never put the ESL secret in a shell argument, Git, a log, or a screenshot. Keep the file and backups readable only by required system administrators.

After editing, verify both files are well-formed XML and owned/readable only as required by the FreeSWITCH service. With no calls on this fresh host, activate the listener/ACL change:

```sh
sudo python3 -c 'import xml.etree.ElementTree as E; E.parse("/etc/freeswitch/autoload_configs/acl.conf.xml"); E.parse("/etc/freeswitch/autoload_configs/event_socket.conf.xml"); print("XML syntax OK")'
sudo systemctl restart freeswitch
sudo systemctl is-active freeswitch
sudo ss -lntp | grep ':8021'
```

The `ss` result must show the intended management-interface address, not `0.0.0.0` or a public wildcard. From the Billing host, test TCP reachability to that address and port. This confirms only the network path; authenticated ESL status is verified after the host and password have been saved in Billing. A local `fs_cli` test alone does not verify the Billing-to-FS route. Do not repeat `--install` to change these values: the installer preserves the owned configuration on subsequent runs.

### 2.3 Prepare the separate SSH path for panel deployment

The installer installs OpenSSH server and sudo tooling, but it does not create a remote-management account, set an SSH password/key, open firewall ports, or change `sshd` authentication. Prepare the account and source restriction according to the site's access policy before entering it into Billing. If a dedicated account is approved, create it interactively so its password is not exposed in command history:

```sh
sudo adduser ov500-mgmt
```

The account name is an example; use the site's chosen name. The password is entered at the interactive prompt, never in the command itself. The current remote deployment implementation requires root-equivalent execution through `sudo -n /usr/bin/python3`. To grant that to the example account, an administrator would create a sudoers drop-in with `sudo visudo -f /etc/sudoers.d/ov500-fsmanager` containing:

```text
ov500-mgmt ALL=(root) NOPASSWD: /usr/bin/python3
```

Then validate the file and the effective policy:

```sh
sudo visudo -cf /etc/sudoers.d/ov500-fsmanager
sudo -l -U ov500-mgmt
```

This sudo rule is root-equivalent because it permits arbitrary Python code as root. If that is not acceptable, do not install this rule or deploy from Billing; the remote worker/sudo design must first be changed and security-tested. Do not add the account to the general `sudo` group as a shortcut.

The current FS Manager SSH client authenticates with an SSH username/password and pins the host's SHA-256 fingerprint; it does not currently use SSH-key authentication. Its remote deploy uploads a transaction worker and invokes it through `sudo -n /usr/bin/python3`. Allowing arbitrary arguments to that Python executable is root-equivalent, not narrow sudo. The server owner must approve this trust boundary and restrict SSH reachability to Billing. If that is not acceptable, stop before enabling deploy; the worker/sudo design needs a least-privilege redesign and tests. Never publish the username, password, key, or host-specific fingerprint.

On the FS console, list the public host-key fingerprints. These are public key fingerprints, not private keys:

```sh
sudo sh -c 'for key in /etc/ssh/ssh_host_*_key.pub; do
  [ -r "$key" ] && ssh-keygen -lf "$key" -E sha256
done'
```

From a trusted shell on the Billing host, test the two network paths with the actual private host address and account. The SSH command prompts interactively; never append the password to the command:

```sh
nc -vz -w 3 FS_MANAGEMENT_IP 8021
ssh -o StrictHostKeyChecking=ask -p 22 MANAGEMENT_USER@FS_MANAGEMENT_IP
```

At the first SSH connection, compare the displayed SHA-256 fingerprint with the one obtained on the FS console before accepting it. Once logged in, test the exact non-interactive Python privilege without providing a password on the command line:

```sh
sudo -n /usr/bin/python3 --version
```

Exit the SSH session. If any check fails, fix the route, firewall source restriction, SSH account/authentication, host-key identity, or approved privilege on the FS side before adding the node in Billing. TCP reachability alone does not prove ESL password authentication; Billing verifies ESL after the saved server details are available to it.

### 2.4 Leave Billing-generated XML integration for the panel

Do **not** manually put a Billing token or a guessed API URL in `xml_curl.conf.xml` or `xml_cdr.conf.xml`. The installer deliberately leaves XML-Curl on an invalid loopback-only placeholder and does not create SIP routes. Billing assigns this node a server ID and generates its per-server API credential only when the administrator adds the node. The panel's deploy then creates the correct XML-Curl dialplan/directory and XML-CDR settings for that server. Editing those files by hand before registration can create a stale or unauthenticated integration.

The installer does not install an active firewall policy. Do not flush or replace the host firewall. Before panel registration, allow only the restricted management paths needed from Billing: ESL and SSH to the FreeSWITCH management address, and HTTPS from FreeSWITCH to Billing. SIP and RTP are configured and opened later, from the actual Billing profile values and approved carrier/customer networks.

Run the installer's security prerequisite check before handing the host to Billing:

```sh
sudo bash fs-server/install-fs.sh --security-check
```

This checks for Python, nftables tooling, OpenSSH, and a readable nftables ruleset. It does not create a firewall policy or enable Billing-managed protection. That protection is enrolled from the Billing panel after the server has been registered with verified SSH access.

## 3. Register the FreeSWITCH server in the Billing web panel

Sign in as a Billing administrator and open **FS Manager → Servers** (`index.php/fsmanager/servers`). Use **Add FreeSWITCH Server**. Fill the fields as follows:

| Billing form field | What to enter |
| --- | --- |
| **Server Name** | A unique operator label for this FreeSWITCH server. |
| **IP Address / Hostname** | The address reachable by Billing for ESL and SSH. Use the routable management address, not an address copied from another server. |
| **ESL Port** | The port configured in `event_socket.conf.xml` (installer default `8021`). |
| **ESL Password** | The generated secret from this server's own `event_socket.conf.xml`; enter it in the password field only. |
| **SIP Domain** | The SIP domain or address used by the profiles that will be generated for this node. Leave empty only if the chosen profile design does not use one. |
| **SSH Username / SSH Port** | The approved remote-management account and its reachable SSH port (form default `22`). |
| **Billing Base URL** | The canonical Billing HTTPS origin reachable from the FreeSWITCH host, with a valid certificate. Do not include credentials, query parameters, or a trailing API path. |
| **FreeSWITCH Configuration Directory** | The actual config directory on the remote node; for the supplied installer this is `/etc/freeswitch`. |
| **Recording directory on this server** | The real recording directory only if remote recording downloads are enabled; otherwise leave it empty. |
| **Maximum recording download (MB)** | The policy limit for one recording download; choose it for the deployment. |
| **SSH Host Fingerprint (SHA256)** | Discover it with **Check fingerprint**, then compare it with the fingerprint obtained from the trusted FreeSWITCH console before saving. Discovery alone is not identity verification. |
| **SSH Password** | The approved management-account password, entered only into the protected form. Do not put it in Git or documentation. |

The panel stores ESL, SSH, and generated per-server configuration credentials in its protected server configuration. A per-server Billing API token is generated by the panel. Do not manually invent or copy that token, and do not paste the token into the public guide.

After registration, the panel creates a per-server configuration-authentication token. The generated FreeSWITCH XML-Curl and XML-CDR files point back to the configured Billing origin at the managed API endpoint:

```text
https://BILLING_HOST/api/fsmanager.php?operation=dialplan&server_id=SERVER_ID
https://BILLING_HOST/api/fsmanager.php?operation=directory&server_id=SERVER_ID
https://BILLING_HOST/api/fsmanager.php?operation=cdr&server_id=SERVER_ID
```

These are templates: `BILLING_HOST` and `SERVER_ID` are populated from that Billing installation and the newly registered node. The per-server Basic-auth credential is generated and inserted by Billing at deployment time. Do not add a token or password to these example URLs.

## 4. Add profiles, accounts, and gateways in Billing

After adding the node:

1. Confirm that it appears under **Registered FreeSWITCH Servers** with the expected name, host, Engine, and ESL port.
2. Add or select the SIP profiles for this server in FS Manager. Give each profile the correct SIP bind address, SIP port, external/NAT addresses, codecs, and RTP policy for this host and network. These are deployment-specific values; do not reuse another server's IPs or ports without validating them.
3. Associate the intended customer SIP users/IP-authenticated trunks and carrier gateways with the correct server and profile using the existing Billing forms. Keep the Billing customer, carrier, rate, and route records as the authority; the FS installer does not create those records.
4. Verify the selected profiles and gateways belong to this FreeSWITCH server and are enabled as intended.

## 5. Deploy the Billing-generated FreeSWITCH configuration

From the server row in **FS Manager → Servers**, run the panel's configuration validation/deployment action for that server. The Billing FS Manager generates and deploys the server-specific Sofia profile, directory, IP-trunk, XML-Curl and XML-CDR files. The XML-Curl/HTTP Basic credential is generated by Billing for that server; the guide and installer never contain it. For HTTPS, the generated XML enables certificate and hostname verification.

The bundle deployment checks the remote configuration and required modules, verifies an ESL connection, backs up the managed files, uses the pinned SSH connection to stage/apply them, and confirms runtime activation. It is separate from initial FreeSWITCH installation. Do not treat `Configuration installed` as sufficient unless the panel also reports activation verified and the intended profiles are confirmed.

If validation, ESL, SSH, module checks, or runtime activation fails, stop before enabling customer traffic. Read the complete response and server logs. If the panel says previous files were restored or runtime recovery needs attention, inspect/recover that transaction before retrying; repeated deploy clicks can obscure the original failure.

## 6. Verify the end-to-end path before admitting traffic

Complete these checks in order:

- On FreeSWITCH: `sudo bash fs-server/install-fs.sh --verify` passes on a fresh untouched install. After changing ESL binding, additionally verify the management listener and ACL without printing the secret.
- In Billing: the server is enabled, ESL status is reachable, the SSH fingerprint matches the trusted console, and the expected per-server Engine is running/healthy.
- On FreeSWITCH: `sofia status` shows only the intended generated profiles; inspect gateways and confirm each configured carrier is represented by the expected profile.
- On FreeSWITCH and Billing: XML-Curl dialplan/directory requests reach the correct server-specific Billing API endpoint over HTTPS and authenticate successfully; the Billing API accepts only that server's credential.
- Make one authorized controlled test call through the intended customer and carrier route. Check the SIP response path and verify the resulting CDR on both sides, including answer/bill seconds and customer/carrier charges. Do not use a load test as an installation check.
- Verify the configured RTP path with two-way audio before enabling customer traffic.
- If using Billing-managed FS Protection, complete `--security-check`, register valid pinned SSH credentials, enable the server's FS Protection in Billing, then wait for a successful fresh confirmation. A stale/attention state is not proof of protection.

Only after these checks pass should the operator enable normal traffic through the panel's existing routing controls.

## 7. Port and troubleshooting checklist

The exact firewall rules depend on the deployed addresses and chosen profiles. The usual logical paths are:

| Source → destination | Purpose | Restriction |
| --- | --- | --- |
| Billing → FreeSWITCH management address | ESL (normally TCP `8021`) | Allow only the Billing source address. |
| Billing → FreeSWITCH management address | SSH (normally TCP `22`) | Allow only Billing; verify the SHA-256 host-key pin. |
| FreeSWITCH → Billing HTTPS origin | XML-Curl and CDR API | Valid HTTPS certificate and server-specific API authentication. |
| SIP peers/carriers → configured SIP profile | SIP signaling | Only the configured protocol/ports and expected source networks. |
| FreeSWITCH ↔ media peers | RTP | Only the configured RTP range and required peers; confirm both media directions. |

Do not assume the installer defaults (including its RTP range or FreeSWITCH session/CPS settings) are measured production capacity. Confirm actual listener/profile configuration before creating firewall rules.

| Symptom | First checks |
| --- | --- |
| **ESL connection failed** | Listener bind address, network route, source-restricted ACL, port, and matching ESL secret. Do not open ESL to everyone. |
| **SSH fingerprint mismatch** | Re-check the host identity from a trusted console; do not accept a newly discovered key without comparison. |
| **SSH deployment/transaction failure** | SSH account, pinned fingerprint, remote config directory, required narrowly scoped non-interactive `sudo -n /usr/bin/python3`, and remote filesystem permissions. |
| **XML-Curl returns HTTP/auth errors** | Billing HTTPS URL/certificate, server's outbound route/DNS/time, panel's generated per-server token, and server ID association. Do not copy a token between servers. |
| **Profile activation not confirmed** | Preserve the deployment transaction/backup and inspect FreeSWITCH logs plus `sofia status`; do not assume restored files mean the runtime is healthy. |
| **CDR absent or delayed** | `mod_xml_cdr`, FreeSWITCH CDR error/spool files, outbound HTTPS reachability, and Billing's CDR/API logs. Preserve unprocessed CDR files while diagnosing. |
| **No audio / one-way audio** | SIP/SDP external addresses, NAT, RTP port range and firewall path in both directions. ESL connectivity does not prove media connectivity. |

## Security boundary

This public guide intentionally contains placeholders only. Never commit the following: actual ESL or SSH passwords, Billing API tokens, server IPs/hostnames, SSH host-key records tied to private infrastructure, customer/carrier data, private configuration files, or CDRs. Keep secrets in the existing protected Billing/FS configuration. Rotate a secret if it was exposed in a terminal transcript, screenshot, or public repository.

## Official FreeSWITCH references

- [FreeSWITCH Access Control Lists](https://developer.signalwire.com/freeswitch/integration/acls/)
- [FreeSWITCH Event Socket](https://developer.signalwire.com/freeswitch/integration/event-socket/)

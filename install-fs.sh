#!/usr/bin/env bash
# OV500 FreeSWITCH bootstrap for a NEW Debian 12 host. No Billing credentials embedded.
set -Eeuo pipefail
umask 027
FS_COMMIT=ef32e205295e29f034f1453ad245ba5efb07b94a
SOFIA_COMMIT=ad36ac8f755308e8b87f98a505e83d4e408e5cc3
SPAN_COMMIT=8f1e1646bdec99eac5fd2cd92c35563f736b9b89
PREFIX=/usr/local/freeswitch
STATE=/var/lib/ov500-fs-install
MODE=${1:---install}
usage(){ echo 'Usage: sudo bash install-fs.sh [--check|--install|--verify|--security-check|--security-prepare]'; }
[[ $MODE == --help ]] && { usage; exit 0; }
[[ $MODE == --check || $MODE == --install || $MODE == --verify || $MODE == --security-check || $MODE == --security-prepare ]] || { usage; exit 2; }
[[ $EUID == 0 ]] || { echo 'Root/sudo required'; exit 1; }
source /etc/os-release
[[ $ID == debian && $VERSION_ID == 12 ]] || { echo 'This tested installer requires Debian 12'; exit 1; }
# Security policy stays in Billing. This only prepares native SSH/nft prerequisites.
security_check(){
 command -v python3 >/dev/null || { echo 'Security prerequisite missing: python3'; return 1; }
 command -v nft >/dev/null || { echo 'Security prerequisite missing: nftables'; return 1; }
 command -v sshd >/dev/null || { echo 'Security prerequisite missing: openssh-server'; return 1; }
 python3 - <<'SECURITY_PY'
import json,subprocess,os
subprocess.run(['nft','-j','list','ruleset'],check=True,stdout=subprocess.DEVNULL)
print(json.dumps({'security_prerequisites_ready':True,'management':'Existing Billing Security over pinned SSH','agent_installed':False,'firewall_policy_created_by_installer':False,'policies_from_panel':True,'requires_root_or_existing_passwordless_sudo':True,'reboot_recovery':'Billing periodic SSH synchronization after network/SSH availability'}))
SECURITY_PY
}
security_prepare(){
 local missing=0
 for executable in python3 nft sshd; do command -v "$executable" >/dev/null || missing=1; done
 if (( missing )); then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends python3 nftables openssh-server sudo
 fi
 security_check
}
if [[ $MODE == --security-check ]]; then security_check; exit; fi
if [[ $MODE == --security-prepare ]]; then security_prepare; exit; fi
verify(){
 python3 - <<'PY'
import socket,xml.etree.ElementTree as E,json
from pathlib import Path
c=E.parse('/etc/freeswitch/autoload_configs/event_socket.conf.xml');secret=next(p.get('value') for p in c.iter('param') if p.get('name')=='password')
host=next(p.get('value') for p in c.iter('param') if p.get('name')=='listen-ip');port=int(next(p.get('value') for p in c.iter('param') if p.get('name')=='listen-port'));host='127.0.0.1' if host=='0.0.0.0' else host
s=socket.create_connection((host,port),5);s.settimeout(5);buf=b''
def frame():
 global buf
 while b'\n\n' not in buf:buf+=s.recv(65536)
 h,buf=buf.split(b'\n\n',1);headers=dict(x.split(': ',1) for x in h.decode().splitlines() if ': ' in x);n=int(headers.get('Content-Length','0'))
 while len(buf)<n:buf+=s.recv(65536)
 body,buf=buf[:n],buf[n:];return headers,body.decode(errors='replace')
h,_=frame();assert h.get('Content-Type')=='auth/request';s.sendall(('auth '+secret+'\n\n').encode());h,_=frame();assert h.get('Reply-Text','').startswith('+OK')
result={}
for cmd in ['version','status','show channels count','sofia status','module_exists mod_sofia','module_exists mod_dialplan_xml','module_exists mod_xml_curl','module_exists mod_xml_cdr','module_exists mod_event_socket','module_exists mod_dptools']:
 s.sendall(('api '+cmd+'\n\n').encode());_,body=frame();result[cmd]=body.strip()
 for key in ['module_exists mod_sofia','module_exists mod_dialplan_xml','module_exists mod_xml_curl','module_exists mod_xml_cdr','module_exists mod_event_socket','module_exists mod_dptools']:
  if cmd==key:assert body.strip()=='true',key
s.close();print(json.dumps({'passed':True,'runtime':result},indent=2))
PY
 systemctl is-active --quiet freeswitch
 security_check
}
if [[ $MODE == --verify ]]; then verify; exit; fi
if [[ ! -f $STATE/owned ]]; then
 for path in "$PREFIX" /etc/freeswitch /etc/systemd/system/freeswitch.service; do
  [[ ! -e $path ]] || { echo "Existing unmanaged installation: $path; refusing replacement"; exit 1; }
 done
 ! command -v freeswitch >/dev/null || { echo 'Existing binary detected'; exit 1; }
 ! systemctl is-active --quiet freeswitch || { echo 'Existing service active'; exit 1; }
fi
[[ $(df -Pk /usr/local | awk 'NR==2{print $4}') -ge 4194304 ]] || { echo 'Need at least4GiB free'; exit 1; }
if [[ $MODE == --check ]]; then echo 'Preflight passed: Debian12, fresh/owned installation, disk capacity'; exit; fi
install -d -m 0700 "$STATE" "$STATE/backups" "$STATE/source"
exec 9>"$STATE/install.lock"; flock -n 9 || { echo 'Installer already running'; exit 1; }
if [[ -f $STATE/complete ]]; then security_prepare; verify; echo 'Already installed; existing configuration preserved'; exit; fi
if [[ ! -f $STATE/owned ]]; then
 stamp=$(date -u +%Y%m%dT%H%M%SZ); tar -czf "$STATE/backups/os-before-$stamp.tgz" /etc/apt /etc/systemd/system /etc/passwd /etc/group /etc/shadow 2>/dev/null
 chmod 600 "$STATE/backups/os-before-$stamp.tgz"
 printf '%s\n' "$FS_COMMIT" > "$STATE/owned"
fi
[[ $(cat "$STATE/owned") == "$FS_COMMIT" ]] || { echo 'Different installer version owns this installation'; exit 1; }
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl git build-essential autoconf automake libtool libtool-bin pkg-config cmake python3 uuid-dev libssl-dev zlib1g-dev libsqlite3-dev libedit-dev libpcre2-dev libcurl4-openssl-dev libspeex-dev libspeexdsp-dev libldns-dev libopus-dev libsndfile1-dev libjpeg-dev libtiff-dev libncurses-dev libogg-dev libvorbis-dev liblua5.2-dev yasm nasm nftables openssh-server sudo logrotate
JOBS=$(nproc); ((JOBS>4)) && JOBS=4; export MAKEFLAGS="-j$JOBS"
fetch(){
 local repo=$1 commit=$2 dest=$3
 if [[ ! -d $dest/.git ]]; then
  [[ ! -e $dest ]] || { echo 'Refusing unrelated source directory'; exit 1; }
  git init "$dest"; git -C "$dest" remote add origin "https://github.com/$repo.git"
 fi
 [[ $(git -C "$dest" remote get-url origin) == "https://github.com/$repo.git" ]] || exit 1
 git -C "$dest" fetch --depth 1 origin "$commit"
 git -C "$dest" checkout --detach FETCH_HEAD
 [[ $(git -C "$dest" rev-parse HEAD) == "$commit" ]]
}
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH:-}
if [[ ! -f $STATE/sofia-complete ]]; then
 fetch freeswitch/sofia-sip "$SOFIA_COMMIT" "$STATE/source/sofia-sip"
 (cd "$STATE/source/sofia-sip"; ./bootstrap.sh; ./configure --prefix=/usr/local --disable-static; make; make install)
 ldconfig; touch "$STATE/sofia-complete"
fi
if [[ ! -f $STATE/spandsp-complete ]]; then
 fetch freeswitch/spandsp "$SPAN_COMMIT" "$STATE/source/spandsp"
 (cd "$STATE/source/spandsp"; ./bootstrap.sh; ./configure --prefix=/usr/local --disable-static; make; make install)
 ldconfig; touch "$STATE/spandsp-complete"
fi
if [[ ! -f $STATE/build-complete ]]; then
 fetch signalwire/freeswitch "$FS_COMMIT" "$STATE/source/freeswitch"
 cd "$STATE/source/freeswitch"
 ./bootstrap.sh -j
 cat > modules.conf <<'MODULES'
applications/mod_commands
applications/mod_dptools
applications/mod_db
applications/mod_hash
applications/mod_expr
applications/mod_curl
applications/mod_spandsp
applications/mod_voicemail
codecs/mod_g723_1
codecs/mod_g729
codecs/mod_amr
codecs/mod_opus
codecs/mod_b64
dialplans/mod_dialplan_xml
endpoints/mod_sofia
endpoints/mod_loopback
formats/mod_native_file
formats/mod_sndfile
formats/mod_tone_stream
formats/mod_local_stream
loggers/mod_console
loggers/mod_logfile
say/mod_say_en
xml_int/mod_xml_curl
event_handlers/mod_event_socket
xml_int/mod_xml_cdr
MODULES
 ./configure --prefix="$PREFIX" --disable-dependency-tracking
 make
 make install
 ldconfig; touch "$STATE/build-complete"
fi
getent group freeswitch >/dev/null || groupadd --system freeswitch
id freeswitch >/dev/null 2>&1 || useradd --system --gid freeswitch --home-dir /var/lib/freeswitch --shell /usr/sbin/nologin freeswitch
# Source installs inherit the private build umask; grant only the service group runtime access.
chgrp -R freeswitch "$PREFIX"
chmod -R g+rX "$PREFIX"
install -d -o freeswitch -g freeswitch -m 0750 /var/lib/freeswitch /var/lib/freeswitch/db /var/lib/freeswitch/storage /var/lib/freeswitch/recordings /var/lib/freeswitch/cdr /var/log/freeswitch /var/log/freeswitch/cdr /etc/freeswitch /etc/freeswitch/autoload_configs /etc/freeswitch/sip_profiles /etc/freeswitch/dialplan /etc/freeswitch/directory
# Fresh, deliberately isolated base: no default users, public SIP listener or PSTN routes.
if [[ ! -f /etc/freeswitch/freeswitch.xml ]]; then
 python3 - <<'PY'
from pathlib import Path
import secrets,os,grp,xml.etree.ElementTree as ET
root=Path('/etc/freeswitch');gid=grp.getgrnam('freeswitch').gr_gid
files={
'freeswitch.xml':'''<document type="freeswitch/xml"><X-PRE-PROCESS cmd="include" data="vars.xml"/><section name="configuration"><X-PRE-PROCESS cmd="include" data="autoload_configs/*.xml"/></section><section name="dialplan"><X-PRE-PROCESS cmd="include" data="dialplan/*.xml"/></section><section name="directory"><X-PRE-PROCESS cmd="include" data="directory/*.xml"/></section></document>''',
'vars.xml':'''<include><X-PRE-PROCESS cmd="set" data="sound_prefix=/usr/local/freeswitch/sounds"/><X-PRE-PROCESS cmd="set" data="recordings_dir=/var/lib/freeswitch/recordings"/><X-PRE-PROCESS cmd="set" data="storage_dir=/var/lib/freeswitch/storage"/></include>''',
'autoload_configs/modules.conf.xml':'''<configuration name="modules.conf" description="OV500 SIP Billing modules"><modules>'''+''.join('<load module="'+m+'"/>' for m in ['mod_console','mod_logfile','mod_event_socket','mod_sofia','mod_dialplan_xml','mod_commands','mod_dptools','mod_db','mod_hash','mod_expr','mod_curl','mod_spandsp','mod_voicemail','mod_g723_1','mod_g729','mod_amr','mod_opus','mod_b64','mod_loopback','mod_native_file','mod_sndfile','mod_tone_stream','mod_say_en','mod_xml_curl','mod_xml_cdr'])+'''</modules></configuration>''',
'autoload_configs/event_socket.conf.xml':'<configuration name="event_socket.conf"><settings><param name="listen-ip" value="127.0.0.1"/><param name="listen-port" value="8021"/><param name="password" value="'+secrets.token_hex(32)+'"/><param name="apply-inbound-acl" value="loopback.auto"/></settings></configuration>',
'autoload_configs/sofia.conf.xml':'<configuration name="sofia.conf"><global_settings><param name="log-level" value="0"/></global_settings><profiles><X-PRE-PROCESS cmd="include" data="../sip_profiles/*.xml"/></profiles></configuration>',
'autoload_configs/voicemail.conf.xml':'<configuration name="voicemail.conf"><settings/><profiles><profile name="default"><param name="max-login-attempts" value="3"/><param name="digit-timeout" value="10000"/><param name="max-record-len" value="300"/></profile></profiles></configuration>',
'autoload_configs/db.conf.xml':'<configuration name="db.conf"><settings/></configuration>',
'autoload_configs/curl.conf.xml':'<configuration name="curl.conf"><settings/></configuration>',
'autoload_configs/opus.conf.xml':'<configuration name="opus.conf"><settings/></configuration>',
'autoload_configs/xml_curl.conf.xml':'<configuration name="xml_curl.conf"><bindings><binding name="unconfigured-loopback-only"><param name="gateway-url" value="http://127.0.0.1:9/" bindings="dialplan"/><param name="timeout" value="1"/></binding></bindings></configuration>',
'autoload_configs/switch.conf.xml':'<configuration name="switch.conf"><settings><param name="max-sessions" value="1000"/><param name="sessions-per-second" value="30"/><param name="rtp-start-port" value="16384"/><param name="rtp-end-port" value="32768"/><param name="loglevel" value="info"/></settings></configuration>',
'autoload_configs/xml_cdr.conf.xml':'<configuration name="xml_cdr.conf"><settings><param name="log-dir" value="/var/lib/freeswitch/cdr"/><param name="log-b-leg" value="true"/></settings></configuration>',
'autoload_configs/logfile.conf.xml':'<configuration name="logfile.conf"><settings><param name="rotate-on-hup" value="true"/></settings><profiles><profile name="default"><settings><param name="logfile" value="/var/log/freeswitch/freeswitch.log"/><param name="rollover" value="10485760"/><param name="maximum-rotate" value="20"/></settings><mappings><map name="all" value="warning,err,crit,alert"/></mappings></profile></profiles></configuration>',
'autoload_configs/console.conf.xml':'<configuration name="console.conf"><mappings><map name="all" value="info,notice,warning,err,crit,alert"/></mappings></configuration>',
'dialplan/public.xml':'<include><context name="public"><X-PRE-PROCESS cmd="include" data="public/*.xml"/><extension name="deny-unmapped"><condition><action application="hangup" data="CALL_REJECTED"/></condition></extension></context></include>',
'dialplan/00-deny.xml':'<include><context name="default"><extension name="deny"><condition><action application="hangup" data="CALL_REJECTED"/></condition></extension></context></include>'}
for rel,body in files.items():
 p=root/rel;tree=ET.fromstring(body);ET.indent(tree);p.write_text(ET.tostring(tree,encoding='unicode')+'\n');os.chmod(p,0o640);os.chown(p,0,gid)
PY
fi
if [[ ! -f /etc/systemd/system/freeswitch.service ]]; then
 cat > /etc/systemd/system/freeswitch.service <<'UNIT'
[Unit]
Description=FreeSWITCH for OV500 Billing
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=freeswitch
Group=freeswitch
RuntimeDirectory=freeswitch
RuntimeDirectoryMode=0750
ExecStart=/usr/local/freeswitch/bin/freeswitch -nf -nonat -conf /etc/freeswitch -log /var/log/freeswitch -db /var/lib/freeswitch/db -run /run/freeswitch
Restart=on-failure
RestartSec=5
LimitRTPRIO=89
LimitNICE=-10
LimitNOFILE=65536
LimitCORE=0
UMask=0027
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/freeswitch /var/log/freeswitch /run/freeswitch
TimeoutStopSec=60
[Install]
WantedBy=multi-user.target
UNIT
fi
systemd-analyze verify /etc/systemd/system/freeswitch.service
systemctl daemon-reload
systemctl enable --now freeswitch
for i in {1..30}; do if verify > "$STATE/verification.json" 2> "$STATE/verification-error.log"; then touch "$STATE/complete"; echo 'Installed and verified. No traffic admitted until Billing integration.'; exit 0; fi; sleep 1; done
echo "Verification failed; inspect $STATE/verification-error.log and journalctl -u freeswitch"; exit 1

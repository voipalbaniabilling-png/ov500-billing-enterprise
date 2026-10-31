# OV500 Billing — Feature Overview

VOIPALBANIA OV500 Billing is a web-based billing and operations platform for voice service providers built around FreeSWITCH. It combines customer and reseller administration, carrier connectivity, call routing, usage rating, invoicing, reporting, security, and system operations while using the platform’s native Billing and CDR workflows.

Feature availability depends on the installed release, enabled modules, permissions, and each operator’s configuration. This document describes the product capabilities; it is not a claim that every external service or deployment has already been configured or accepted.

## Customer, reseller, and account administration

- Create and manage customer and reseller accounts with role-scoped access to the areas each role is permitted to use.
- Configure account status, billing type, currency, invoice cycle and terms, assigned rate plans, call limits, and other service attributes.
- Configure service thresholds such as simultaneous-call capacity, call-attempt rate, and maximum call duration where those controls are enabled for the account.
- Support IP-authenticated customer trunks and SIP-user authentication, including account credentials and FreeSWITCH profile association.
- View account dashboards, statements, rates, call activity, invoices, balances, and service configuration through the applicable web portal.
- Apply account notifications such as low-balance notices and account-related messages when mail delivery is configured.
- Support role-specific administration for system users, resellers, customers, and extension accounts; each portal exposes only the functions allowed by the configured role and permissions.
- Provide account statements, profile and service settings, payment entry/history, and customer self-service views where enabled for that account.
- Configure inbound-call attestation checks and A/B/C attestation levels for supported deployments; this is distinct from SIP authentication and depends on the connected FreeSWITCH setup.

## Carrier and provider management

- Maintain multiple carriers and their routing, commercial, currency, and technical settings.
- Configure carrier gateways, SIP identities, caller-ID preferences, random CLI pools, and outbound prefix/localization rules.
- Manage blocked caller IDs and Do-Not-Call number lists.
- Configure customer call-attestation checking and accepted attestation levels where the connected SIP/FreeSWITCH environment supports them.
- Associate carriers and routes with the FreeSWITCH servers and SIP profiles that should use them.
- Maintain carrier-authorized CLI values and random CLI pools, including supported list upload and selection settings.
- Configure outbound and inbound source/destination number manipulation, diversion numbers, and technical prefixes where required by the carrier.
- Maintain carrier-specific gateway and commercial settings separately from customer sales plans.
- Review configured gateway status and FreeSWITCH connection status from the management panel.

## Multi-server FreeSWITCH Manager

- Register and manage multiple FreeSWITCH servers from one Billing panel, including remote nodes reached through the configured management connections.
- Maintain server connection details and the ESL/SSH settings used by the installed integration.
- Manage SIP profiles and Sofia gateways associated with each server.
- Generate and review FreeSWITCH configuration, then deploy it through the manager’s deployment workflow with activation checks and recovery handling.
- Observe server/profile/gateway status and review server-specific operational information without requiring every node to be administered in a separate Billing panel.
- Associate the GO processing component with the configured FreeSWITCH node, allowing server-specific processing to be managed dynamically by the installed integration.

Remote management requires network reachability and valid, least-privilege credentials configured by the system administrator. Status indicators show the result of the integration’s checks; a reachable FreeSWITCH gateway does not by itself prove that a remote carrier will accept a call.

## SIP services, DIDs, and routing

- Configure SIP users and IP-based trunks for customer access.
- Manage inbound DIDs, upload/import DID data, associate numbers with carriers, and assign DIDs to customer services.
- Support DID purchase workflows, including individual or bulk selection, a purchase cart where available, assignment to an account, configuration, and release.
- Configure DID setup, rental, and channel-related charges through the rate-plan fields supported by the installation.
- Define destinations, rate prefixes, dialplans, routes, carrier selections, and permitted call behavior through the existing Billing configuration.
- Organize ratecards, customer/carrier rates, tariffs, bundles/packages, and plan items, then associate the applicable plans with accounts.
- Configure blocked caller IDs and DNC numbers at the available account, carrier, or system scope.
- Configure technical prefix handling, number localization, caller-ID behavior, and route failover conditions where supported by the selected route and FreeSWITCH configuration.
- Compare configured purchase costs across eligible carrier routes using the LCR tools and the selected estimate parameters. Cost comparison is an estimate and does not reserve customer balance or alter actual call billing.

Actual route selection and call completion depend on the customer’s assigned configuration, available destination rates, FreeSWITCH dialplan/profile state, network reachability, and carrier responses.

## Rating, balances, and financial workflows

- Maintain customer and carrier tariffs/rate plans, destinations, rate periods, billing blocks, connection charges, and DID charges supported by the native rating engine.
- Support prepaid and postpaid account workflows, including balance/credit administration and payment records.
- Apply the account’s configured currency and the platform’s stored exchange rates when presenting or calculating cross-currency amounts, while retaining the currency configured for each account and carrier.
- Select the panel’s reference/base currency and refresh stored currency rates through the configured exchange-rate sources; invoices and account views use their configured account currencies and recorded rate data.
- Configure and apply taxes where required by the account’s billing setup.
- Create and review customer invoices, statements, payments, credit changes, and related financial records.
- Support customer payment recording and payment/receipt history; external payment processing such as PayPal is available only when its credentials, callbacks, and account settings have been configured and tested.
- Provide invoice, account, reseller, call-usage, and payment-related summaries supported by the installed report set.
- Preserve CDR and financial processing in the platform’s native engines; the GO components are not a replacement for the native rating, wallet, invoice, reseller, tax, bundle, or CDR logic.

Billing results depend on the configured tariff, account currency, billing increment, tax, invoice cycle, and the FreeSWITCH call records received by the installation.

## CDRs, dashboards, and reports

- Browse call detail records with call direction, customer, carrier, destination, timestamps, duration/billable seconds, answer/result status, SIP response information, and available cost/sell values.
- Review customer and carrier traffic summaries, quality indicators such as ASR/ACD, cause summaries, and financial reporting views.
- Monitor current and recent calls from the applicable dashboards and reports.
- Show live-call and call-progress summaries, recent customer/carrier activity, and customer/carrier quality summaries where the associated data is available.
- Provide cause-summary and account/reseller summary views, plus call-usage reports and filters supported by the installed release.
- Allow authorized users to review or download call recordings when recording is enabled, the recording exists, and the user's role permits access.
- Offer call-rate/ratecard views to customers and resellers, limited to the accounts and plans in their scope.
- Present reporting timestamps using the configured reporting/time-zone settings where supported by the selected view.
- Export supported report and CDR data for operational and financial review.

The details shown in a CDR depend on the events and fields supplied by FreeSWITCH, carrier signaling, and the enabled CDR integration. A SIP response is reported as observed; it should not be interpreted as proof of which party caused a failure without the corresponding call trace.

## SystemCare and operations

- Review system resource and service indicators from the Billing dashboard and SystemCare area.
- Use adaptive configuration helpers to derive selected PHP, database, and GO service settings from the detected installation hardware rather than assuming one fixed server size.
- Configure scheduled maintenance, storage budgets, log handling, backup tasks, and retention policies through the panel where the installed release supports them.
- Track scheduled job outcomes and maintenance status, including failures that need operator attention.
- Display resource and service observations such as CPU, memory, storage, and process/worker indicators when collected by the installed monitoring components.
- Provide storage-health and maintenance status for configured FreeSWITCH recording/voicemail paths; availability depends on the remote-node integration and permissions.
- Review configured FreeSWITCH recording and voicemail storage checks and retention work where those integrations are enabled.
- Keep retention policies configurable; financial records such as invoices and CDRs require deliberate policy configuration and must not be silently deleted.

The maintenance module does not replace operating-system monitoring, external backups, capacity planning, or an operator’s review of alerts. Automatic service restarts and destructive financial retention must not be assumed unless explicitly configured and accepted for the deployment.

## Security, licensing, and appearance

- Provide security and operational views for registered addresses, blocked sources, security-feed status, and active web sessions, subject to installed integrations and permissions.
- Review security inventory and enforcement status, registered addresses, session activity, and supported feed/maintenance results in the Security Center.
- Track panel session activity and apply the configured idle-session expiry behavior.
- Support configurable security data sources and protection policies; network access and FreeSWITCH-side behavior depend on the explicitly enabled deployment configuration.
- Manage domain/SSL requests through the included domain certificate workflow where it is configured.
- Use the license recovery page to authenticate an administrator and activate or verify a license with an issued activation key.
- Provide panel appearance settings and role-appropriate navigation for administrators, resellers, and customers.
- Manage optional modules/plugins through the module area when the current license, release, and administrator permissions allow it; optional modules are not implied to be installed or active.
- Provide extension-oriented feature-code, profile/settings, and voicemail pages where those native components are installed and enabled.

Applicants do not access the VOIPALBANIA licensing panel. Do not send administrator passwords, SIP/SSH secrets, API tokens, private signing keys, or activation keys by email. Request a trial using the contact link in the [README](README.md); the VOIPALBANIA license administrator will create the trial and send an activation key with instructions for the applicant’s own Billing page.

## Deployment notes

- The prepared installation path targets a new Ubuntu 24.04 amd64 server and PHP 7.4 compatibility. The installer is designed to generate fresh installation credentials and application secrets rather than copy credentials or customer data from the source Billing system.
- The protected GO package includes a compiled GO engine for supported releases; source-protection and release-authenticity claims apply only to the exact package that passes the published release checks.
- Remote FreeSWITCH servers remain independently configured systems. OV500 manages them through the configured interfaces; installing or changing FreeSWITCH itself is a separate administrative action.
- A separate Debian 12 FreeSWITCH installation script is maintained for a future Git release. It is not part of this repository yet; installation documentation and the script will be published after separate review. Installing FreeSWITCH alone does not create Billing routes or admit traffic.
- SMTP, payment providers, DNS/TLS, license activation, and FreeSWITCH connections require installation-specific configuration and acceptance.
- Web/API access, scheduled jobs, remote ESL/SSH operations, exports, recordings, and optional integrations are permission- and configuration-dependent. Menu visibility alone does not prove that an external service is connected or that a feature has passed deployment acceptance.

## Trial request

Request a free trial by emailing [voipalbaniabilling@gmail.com](mailto:voipalbaniabilling@gmail.com?subject=OV500%20Free%20Trial%20Request&body=Contact%20name%3A%0ACompany%3A%0ABusiness%20email%3A%0ACountry%3A%0ADeployment%20URL%20or%20domain%3A%0ALicense%20request%20or%20installation%20ID%20(if%20available)%3A%0ANumber%20of%20FreeSWITCH%20servers%3A%0ARequested%20trial%20period%3A%0A). Include your contact and organization details, deployment information, and the license request/installation ID if available. The VOIPALBANIA administrator reviews the request and creates the trial in the administrator-owned licensing panel. If approved, the administrator sends the applicant an activation key and instructions for entering it in the applicant's own Billing license page. Applicants do not access the VOIPALBANIA licensing panel. Do not email administrator login details, activation keys, passwords, or other secrets.

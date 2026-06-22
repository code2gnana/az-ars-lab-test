# AD DS and DNS Setup Guide for Spoke A Domain Controllers

Use this doc when you are deploying, validating, or operating the Spoke A AD DS and DNS domain controllers.

## Purpose

This document provides a complete setup and operations guide for deploying two Windows Server domain controllers in Spoke A with Active Directory Domain Services (AD DS) and DNS using Terraform and Azure VM extensions.

## Topology and Design

- Domain: `corp.contoso.local`
- NetBIOS: `CORP`
- Site: `Default-First-Site-Name`
- DC1 VM: `vm-spoke-a-dc-1` (`spokeadc1`) at `10.3.0.10`
- DC2 VM: `vm-spoke-a-dc-2` (`spokeadc2`) at `10.3.0.11`
- Subnet: `vnet-spoke-a/Subnet-Default`

Design goals:

- Deterministic DC addresses for DNS consistency
- Automated forest creation and replica promotion
- Repeatable deployment through Terraform

## Files Involved

- `spoke-a-domain-controllers.tf`
  - Creates DC NICs and VMs
- `spoke-a-domain-services.tf`
  - Promotes DC1 to forest root
  - Promotes DC2 to replica DC
- `variables.tf`
  - Declares AD and DC sizing inputs
- `terraform.tfvars`
  - Environment-specific values

## Required Variables

Defined in `variables.tf`:

- `spoke_a_dc_vm_size`
- `spoke_a_ad_domain_name`
- `spoke_a_ad_netbios_name`
- `spoke_a_ad_dsrm_password` (sensitive)

Recommended tfvars values used in this lab:

```hcl
spoke_a_dc_vm_size       = "Standard_D2s_v3"
spoke_a_ad_domain_name   = "corp.contoso.local"
spoke_a_ad_netbios_name  = "CORP"
spoke_a_ad_dsrm_password = "<strong-password>"
```

Note:

- `Standard_B2s` hit quota in `australiaeast` during this lab.
- Use a family with available vCPU quota.

## Pre-Deployment Checklist

1. Confirm Azure authentication and subscription context.
2. Confirm compute quota in target region:

```bash
az vm list-usage -l australiaeast -o table
```

1. Ensure Spoke A subnet and NSG association already exist.
2. Ensure Terraform state is healthy and initialized:

```bash
terraform init
terraform validate
```

## Deployment Procedure

### 1) Plan

```bash
terraform plan
```

Expected outcomes include:

- Two NICs for DCs with static IPs
- Two Windows VMs
- Two CustomScriptExtension resources for promotion

### 2) Apply

```bash
terraform apply -auto-approve
```

### 3) Handle extension-state drift if needed

If apply fails with "resource already exists" for an extension, import and re-apply.

```bash
terraform import 'azurerm_virtual_machine_extension.spoke_a_dc1_promote' \
  '/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Compute/virtualMachines/vm-spoke-a-dc-1/extensions/promote-dc1-ad-dns'

terraform import 'azurerm_virtual_machine_extension.spoke_a_dc2_promote' \
  '/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Compute/virtualMachines/vm-spoke-a-dc-2/extensions/promote-dc2-ad-replica'

terraform apply -auto-approve
```

## Promotion Logic Details

### DC1 (`promote-dc1-ad-dns`)

- Installs AD DS and DNS features
- Loads Active Directory module
- Checks whether domain exists with guarded try/catch
- Creates new forest if missing
- Reboots VM

### DC2 (`promote-dc2-ad-replica`)

- Installs AD DS and DNS features
- Waits for DC1 readiness using:
  - DNS lookup
  - LDAP port 389
  - ADWS port 9389
- Promotes as replica using explicit replication source `spokeadc1.corp.contoso.local`
- Uses `-SkipPreChecks` to avoid lab-specific static-IP prereq failures
- Reboots VM

## Validation Commands

Run from your operator shell:

```bash
az vm get-instance-view -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-1 \
  --query "instanceView.extensions[?name=='promote-dc1-ad-dns'].[name,statuses[0].displayStatus,substatuses[0].displayStatus]" -o table

az vm get-instance-view -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 \
  --query "instanceView.extensions[?name=='promote-dc2-ad-replica'].[name,statuses[0].displayStatus,substatuses[0].displayStatus]" -o table
```

Expected:

- Provisioning succeeded for both status and substatus.

Run AD replication checks on DC2:

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 \
  --command-id RunPowerShellScript \
  --scripts "repadmin /replsummary" -o json

az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 \
  --command-id RunPowerShellScript \
  --scripts "repadmin /showrepl" -o json

az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 \
  --command-id RunPowerShellScript \
  --scripts "dcdiag /test:replications /v" -o json
```

Healthy indicators:

- `repadmin /replsummary`: `0` failures
- `repadmin /showrepl`: successful last attempts across all naming contexts
- `dcdiag /test:replications /v`: passed for Replications

## checks, tests, validations and results

This section consolidates the DNS and AD validation commands used in this lab, what each command verifies, and what output to expect.

### Command precheck (CLI availability)

Use when a shell returns code `127` or reports command not found.

```bash
command -v az
az version --output table | head -n 20
```

What this performs:

- Confirms Azure CLI is installed and available in the current shell PATH.

Expected output:

- `command -v az` prints a valid path such as `/opt/homebrew/bin/az`.
- `az version` returns version rows, not an error.

### Individual DNS verification commands

#### 1) DNS service status on both DCs

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-1 \
  --command-id RunPowerShellScript \
  --scripts "Get-Service DNS | Select-Object Name,Status,StartType" -o json

az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 \
  --command-id RunPowerShellScript \
  --scripts "Get-Service DNS | Select-Object Name,Status,StartType" -o json
```

What this performs:

- Verifies Windows DNS service is running on both domain controllers.

Expected output:

- `Status` equals `Running` on each VM.

#### 2) AD-integrated DNS zone presence

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-1 \
  --command-id RunPowerShellScript \
  --scripts "Get-DnsServerZone | Select-Object ZoneName,ZoneType,IsDsIntegrated" -o json
```

What this performs:

- Confirms the domain zone exists and is AD-integrated.

Expected output:

- Zone `corp.contoso.local` appears.
- `IsDsIntegrated` is `True`.

#### 3) Forward lookup from DC2 using DC1 DNS

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 \
  --command-id RunPowerShellScript \
  --scripts "Resolve-DnsName -Name corp.contoso.local -Server 10.3.0.10" -o json
```

What this performs:

- Validates DNS name resolution path from DC2 to DC1 DNS service.

Expected output:

- Returns one or more A records for `corp.contoso.local`.

#### 4) AD LDAP SRV discovery records

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 \
  --command-id RunPowerShellScript \
  --scripts "Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.corp.contoso.local -Server 10.3.0.10" -o json
```

What this performs:

- Checks domain-controller locator SRV records used by AD clients.

Expected output:

- SRV answers resolve to DC hosts such as `spokeadc1` and `spokeadc2`.

#### 5) Cross-server answer consistency

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 \
  --command-id RunPowerShellScript \
  --scripts "Resolve-DnsName -Name spokeadc1.corp.contoso.local -Server 10.3.0.10; Resolve-DnsName -Name spokeadc1.corp.contoso.local -Server 10.3.0.11" -o json
```

What this performs:

- Compares resolution results from both DNS servers.

Expected output:

- Both lookups return consistent A record values.

#### 6) DNS-focused domain controller diagnostics

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 \
  --command-id RunPowerShellScript \
  --scripts "dcdiag /test:dns /v" -o json
```

What this performs:

- Runs Microsoft DNS diagnostic checks for AD DS.

Expected output:

- DNS tests pass with no critical DNS failures.

### Combined script checks

Use these if you want one command that prints pass or fail quickly.

#### A) Strict combined DNS check (includes dcdiag)

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 \
  --command-id RunPowerShellScript \
  --scripts '
$ErrorActionPreference = "Stop"
$failed = 0

function Check([string]$name, [scriptblock]$test) {
  try {
    $ok = & $test
    if ($ok) { Write-Output ("PASS: " + $name) }
    else { Write-Output ("FAIL: " + $name); $script:failed++ }
  } catch {
    Write-Output ("FAIL: " + $name + " -> " + $_.Exception.Message)
    $script:failed++
  }
}

Check "DNS service is running on DC2" { (Get-Service DNS).Status -eq "Running" }
Check "AD-integrated zone exists (corp.contoso.local)" { $null -ne (Get-DnsServerZone -Name "corp.contoso.local" -ErrorAction Stop) }
Check "Forward lookup via DC1 DNS (10.3.0.10)" { $null -ne (Resolve-DnsName -Name "corp.contoso.local" -Server "10.3.0.10" -ErrorAction Stop) }
Check "Forward lookup via DC2 DNS (10.3.0.11)" { $null -ne (Resolve-DnsName -Name "corp.contoso.local" -Server "10.3.0.11" -ErrorAction Stop) }
Check "SRV lookup for LDAP DC locator" { $null -ne (Resolve-DnsName -Type SRV "_ldap._tcp.dc._msdcs.corp.contoso.local" -Server "10.3.0.10" -ErrorAction Stop) }
Check "Host lookup consistent across both DNS servers" {
  $a = (Resolve-DnsName -Name "spokeadc1.corp.contoso.local" -Server "10.3.0.10" -Type A -ErrorAction Stop | Select-Object -First 1).IPAddress
  $b = (Resolve-DnsName -Name "spokeadc1.corp.contoso.local" -Server "10.3.0.11" -Type A -ErrorAction Stop | Select-Object -First 1).IPAddress
  $a -eq $b
}
Check "dcdiag DNS test passes" {
  $out = dcdiag /test:dns /v 2>&1 | Out-String
  Write-Output "----- dcdiag output (truncated to 2000 chars) -----"
  Write-Output ($out.Substring(0, [Math]::Min($out.Length, 2000)))
  ($out -match "passed test DNS") -and ($out -notmatch "failed test DNS")
}

Write-Output ""
Write-Output ("TOTAL FAILURES: " + $failed)
if ($failed -eq 0) { Write-Output "OVERALL: PASS"; exit 0 } else { Write-Output "OVERALL: FAIL"; exit 1 }
' -o json
```

What this performs:

- Executes a full DNS health suite and includes `dcdiag` validation.

Expected output:

- Multiple `PASS:` lines.
- `TOTAL FAILURES: 0`
- `OVERALL: PASS`

#### B) Quick combined DNS check (no dcdiag)

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 \
  --command-id RunPowerShellScript \
  --scripts '
$ErrorActionPreference = "Stop"
$failed = 0

function Check($name, $expr) {
  try {
    if (& $expr) { Write-Output ("PASS: " + $name) }
    else { Write-Output ("FAIL: " + $name); $script:failed++ }
  } catch {
    Write-Output ("FAIL: " + $name + " -> " + $_.Exception.Message)
    $script:failed++
  }
}

Check "DNS service running" { (Get-Service DNS).Status -eq "Running" }
Check "Zone exists" { $null -ne (Get-DnsServerZone -Name "corp.contoso.local" -ErrorAction Stop) }
Check "Forward lookup via DC1 DNS" { $null -ne (Resolve-DnsName -Name "corp.contoso.local" -Server "10.3.0.10" -ErrorAction Stop) }
Check "SRV lookup for LDAP locator" { $null -ne (Resolve-DnsName -Type SRV "_ldap._tcp.dc._msdcs.corp.contoso.local" -Server "10.3.0.10" -ErrorAction Stop) }

Write-Output ("TOTAL FAILURES: " + $failed)
if ($failed -eq 0) { Write-Output "OVERALL: PASS"; exit 0 } else { Write-Output "OVERALL: FAIL"; exit 1 }
' -o json
```

What this performs:

- Runs a faster DNS health subset for routine checks.

Expected output:

- `PASS:` lines for each check.
- `TOTAL FAILURES: 0`
- `OVERALL: PASS`

#### C) Ultra-quick two-check DNS go/no-go

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 \
  --command-id RunPowerShellScript \
  --scripts "if ((Get-Service DNS).Status -eq 'Running') { Write-Output 'PASS: DNS service running' } else { Write-Output 'FAIL: DNS service not running'; exit 1 }" "Resolve-DnsName -Type SRV '_ldap._tcp.dc._msdcs.corp.contoso.local' -Server '10.3.0.10' -ErrorAction Stop | Out-Null; Write-Output 'PASS: LDAP SRV lookup works via DC1 DNS'" -o json
```

What this performs:

- Executes the fastest practical two checks for DNS service and AD SRV lookup.

Expected output:

- `PASS: DNS service running`
- `PASS: LDAP SRV lookup works via DC1 DNS`

### Result interpretation guide

- If all checks pass, DNS is healthy for AD operation in this lab.
- If service is running but SRV lookup fails, check zone health and AD replication.
- If lookups pass on one server only, investigate DNS replication and server-specific issues.
- If command execution returns `Run command extension execution is in progress`, wait and rerun.

## Common Failure Modes and Fixes

### 1) Quota failure for VM size family

Symptom:

- `Operation could not be completed as it results in exceeding approved standardBSFamily Cores quota`

Fix:

- Change `spoke_a_dc_vm_size` to an available family (for example, `Standard_D2s_v3`)
- Re-run apply

### 2) Early AD module/domain lookup failures

Symptom:

- `Unable to find a default server with Active Directory Web Services running`

Fix:

- Ensure scripts use guarded checks and readiness loops (already implemented)
- Re-apply extension

### 3) Extension resource exists but missing from Terraform state

Symptom:

- Terraform says extension already exists and must be imported

Fix:

- Import extension resource ID into state
- Re-run `terraform apply`

### 4) Run Command conflict during validation

Symptom:

- `Run command extension execution is in progress`

Fix:

- Wait for in-flight command to finish and retry

## Security and Operations Notes

1. Keep `spoke_a_ad_dsrm_password` secret and rotate it per environment.
2. Do not hardcode production secrets in `terraform.tfvars`; use secure secret management.
3. Keep DNS server order on DC NICs deterministic (`10.3.0.10`, `10.3.0.11`).
4. Prefer static private IPs for DC VMs.
5. Snapshot state before major domain-controller lifecycle changes.

## Rollback Strategy

If you need to roll back promotions:

1. Remove or disable promotion extensions in Terraform.
2. Destroy DC2 first, then DC1 if full rollback is required.
3. Verify no clients are using the domain before destructive rollback.
4. Restore from state backups if partial state corruption occurred.

## Quick Operator Runbook

```bash
terraform plan
terraform apply -auto-approve

az vm get-instance-view -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-1 --query "instanceView.extensions[?name=='promote-dc1-ad-dns'].[name,statuses[0].displayStatus]" -o table
az vm get-instance-view -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 --query "instanceView.extensions[?name=='promote-dc2-ad-replica'].[name,statuses[0].displayStatus]" -o table

az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 --command-id RunPowerShellScript --scripts "repadmin /replsummary" -o json
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 --command-id RunPowerShellScript --scripts "repadmin /showrepl" -o json
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 --command-id RunPowerShellScript --scripts "dcdiag /test:replications /v" -o json
```

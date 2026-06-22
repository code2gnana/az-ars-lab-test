# Troubleshooting On-Prem RDP Connection from Spoke A

Use this doc when diagnosing Spoke A to on-prem connectivity issues, simulation outcomes, or AD/DC deployment incidents.

## Scope

This document captures every major step taken to troubleshoot and resolve intermittent Remote Desktop (RDP) connectivity from `vm-spoke-a-win22-1` to `vm-onprem-win22-1` (`192.168.1.4`) in the Azure Route Server hub-spoke lab.

## Problem Statement

- Source VM: `vm-spoke-a-win22-1`
- Destination VM: `vm-onprem-win22-1` (`192.168.1.4`)
- Symptom: RDP client connection to `192.168.1.4` was failing intermittently.

## Environment Context

- Resource Group: `rg-ars-end-to-end-lab`
- Hub VPN Gateway: `vpngw-hub` (active-active)
- Simulated On-Prem VPN Gateway: `vpngw-onprem` (active-active)
- Hub <-> On-Prem S2S connections initially used one LNG/connection pair per direction.

---

## Step-by-Step Troubleshooting Timeline

### 1) Validate IPsec tunnel status

We first checked whether the S2S tunnels were up.

```bash
az network vpn-connection show -g rg-ars-end-to-end-lab -n conn-hub-to-onprem \
  --query '{name:name,connectionStatus:connectionStatus,ingressBytes:ingressBytesTransferred,egressBytes:egressBytesTransferred,tunnelConnectionStatus:tunnelConnectionStatus}' -o json

az network vpn-connection show -g rg-ars-end-to-end-lab -n conn-onprem-to-hub \
  --query '{name:name,connectionStatus:connectionStatus,ingressBytes:ingressBytesTransferred,egressBytes:egressBytesTransferred,tunnelConnectionStatus:tunnelConnectionStatus}' -o json
```

Observation:

- Both connection objects reported `Connected` at that time.

### 2) Validate route propagation on Spoke A NIC

We confirmed Spoke A had a route to on-prem prefix via virtual network gateway.

```bash
az network nic show-effective-route-table -g rg-ars-end-to-end-lab -n nic-spoke-a-win22-1 -o table
```

Observation:

- Route `192.168.0.0/16` existed with next hop `VirtualNetworkGateway`.

### 3) Attempt path diagnostics with Network Watcher

We attempted connectivity test from source VM to destination port 3389.

```bash
az network watcher test-connectivity \
  --resource-group rg-ars-end-to-end-lab \
  --source-resource vm-spoke-a-win22-1 \
  --dest-address 192.168.1.4 \
  --dest-port 3389 \
  --protocol Tcp -o json
```

Observation:

- Failed because NetworkWatcher agent extension was not installed on source VM.

### 4) Check effective NSG on source and destination NICs

We checked effective security rules to identify network policy blocks.

```bash
az network nic list-effective-nsg -g rg-ars-end-to-end-lab -n nic-spoke-a-win22-1 -o json
az network nic list-effective-nsg -g rg-ars-end-to-end-lab -n nic-onprem-win22-1 -o json
```

Also verified NSG inventory and explicit rules:

```bash
az network nsg list -g rg-ars-end-to-end-lab --query "[].{name:name,id:id}" -o table

az network nsg rule list -g rg-ars-end-to-end-lab --nsg-name nsg-onprem-test \
  --query "[].{name:name,priority:priority,direction:direction,access:access,protocol:protocol,src:sourceAddressPrefix,dst:destinationAddressPrefix,dstPort:destinationPortRange}" -o table
```

Observation:

- No explicit deny on TCP 3389 in NSG path.
- Destination effective NSG contained default `AllowVnetInBound`, so VNet-routed traffic was not blocked by NSG.

### 5) Validate guest OS readiness on destination VM

We validated RDP service, listener, firewall, and NLA settings inside `vm-onprem-win22-1`.

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-onprem-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "Get-Service -Name TermService | Select-Object Name,Status,StartType; \
             Get-NetTCPConnection -LocalPort 3389 -State Listen -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,State; \
             Get-NetFirewallRule -DisplayGroup 'Remote Desktop' | Select-Object DisplayName,Enabled,Direction,Action,Profile" -o json
```

Additional detailed checks used:

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-onprem-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "Get-ItemProperty 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server' | Select fDenyTSConnections; \
             Get-ItemProperty 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\\WinStations\\RDP-Tcp' | Select UserAuthentication,SecurityLayer" -o json
```

Observation:

- `TermService` running.
- Listener on `0.0.0.0:3389` and `::3389`.
- RDP firewall rules enabled.
- RDP enabled in registry.
- NLA enabled.

Conclusion: destination guest itself was RDP-ready.

### 6) Validate source-to-destination TCP 3389 from inside source VM

We used `Test-NetConnection` repeatedly.

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "Test-NetConnection -ComputerName 192.168.1.4 -Port 3389 | \
             Select-Object ComputerName,RemoteAddress,RemotePort,TcpTestSucceeded" -o json
```

Repeated sampling:

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "1..3 | ForEach-Object { Test-NetConnection 192.168.1.4 -Port 3389 | Select-Object ComputerName,RemoteAddress,RemotePort,TcpTestSucceeded };" -o json
```

Observation:

- Intermittent results (for example: `True`, `True`, `False`).

### 7) Validate return path from destination side

We verified reverse direction to rule out return-path issues.

```bash
az network nic show-effective-route-table -g rg-ars-end-to-end-lab -n nic-onprem-win22-1 -o table

az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-onprem-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "Test-NetConnection 10.3.0.4 -Port 3389 | Select-Object ComputerName,RemoteAddress,RemotePort,TcpTestSucceeded" -o json
```

Observation:

- Return route to `10.3.0.0/16` present.
- Reverse TCP test succeeded.

### 8) Re-check BGP states on hub gateway

We checked if both on-prem peers were fully established.

```bash
az network vnet-gateway list-bgp-peer-status -g rg-ars-end-to-end-lab -n vpngw-hub -o table
```

Observation during failure window:

- One on-prem peer connected while another peer was `Connecting`.
- This can create asymmetric active-active behavior with intermittent drops when only one effective instance path is carrying traffic.

### 9) Root cause

Primary issue identified:

- Active-active gateways were not modeled with deterministic per-instance LNG/connection resources.
- Traffic hashing across gateway instances could hit non-equivalent pathing during partial peering/tunnel establishment, causing intermittent RDP failure.

Secondary operator confusion source:

- Telnet is often not installed on Windows Server by default, and successful telnet to 3389 can appear as a blank screen.

---

## Final Resolution Applied

We implemented Option A (dual-instance deterministic connectivity):

- One LNG per gateway instance on each side.
- One VPN connection per instance pairing in each direction.
- Auto-discovered per-instance BGP peer mapping from gateway state.
- Added Terraform `moved` blocks to preserve existing instance-1 resources during migration.

Post-change validation commands:

```bash
terraform plan
terraform apply -auto-approve

az network vnet-gateway list-bgp-peer-status -g rg-ars-end-to-end-lab -n vpngw-hub -o table

az network vpn-connection show -g rg-ars-end-to-end-lab -n conn-hub-to-onprem-2 \
  --query '{name:name,connectionStatus:connectionStatus,ingressBytes:ingressBytesTransferred,egressBytes:egressBytesTransferred}' -o json

az network vpn-connection show -g rg-ars-end-to-end-lab -n conn-onprem-to-hub-2 \
  --query '{name:name,connectionStatus:connectionStatus,ingressBytes:ingressBytesTransferred,egressBytes:egressBytesTransferred}' -o json

az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "1..5 | ForEach-Object { Test-NetConnection 192.168.1.4 -Port 3389 | Select-Object RemoteAddress,RemotePort,TcpTestSucceeded }" -o json
```

Final outcome:

- Both on-prem BGP peers (`192.168.254.4` and `192.168.254.5`) reached `Connected` state.
- New instance-2 VPN connections reached `Connected`.
- Repeated `Test-NetConnection` checks returned consistent success.

---

## Terraform Code Changes (Applied)

### 1) `variables.tf` additions

```hcl
variable "hub_bgp_peering_address_overrides" {
  description = "Optional per-instance hub BGP peering IP overrides keyed by ip config name (vnetGatewayConfig1, vnetGatewayConfig2)."
  type        = map(string)
  default     = {}
}

variable "onprem_bgp_peering_address_overrides" {
  description = "Optional per-instance on-prem BGP peering IP overrides keyed by ip config name (vnetGatewayConfig1, vnetGatewayConfig2)."
  type        = map(string)
  default     = {}
}
```

### 2) `s2s-bgp.tf` replacement (core dual-instance logic)

```hcl
locals {
  # Build deterministic map: ip config name -> gateway BGP peer IP.
  hub_bgp_by_ipconfig = {
    for p in azurerm_virtual_network_gateway.hub_vpngw.bgp_settings[0].peering_addresses :
    p.ip_configuration_name => p.default_addresses[0]
  }

  onprem_bgp_by_ipconfig = {
    for p in azurerm_virtual_network_gateway.onprem_vpngw.bgp_settings[0].peering_addresses :
    p.ip_configuration_name => p.default_addresses[0]
  }

  # Explicit instance inventory allows one LNG+connection per gateway instance.
  gateway_instances = {
    vnetGatewayConfig1 = {
      index = 0
    }
    vnetGatewayConfig2 = {
      index = 1
    }
  }
}

# Preserve existing instance-1 resources during migration to per-instance model.
moved {
  from = azurerm_local_network_gateway.lng_hub
  to   = azurerm_local_network_gateway.lng_hub_instance["vnetGatewayConfig1"]
}

moved {
  from = azurerm_local_network_gateway.lng_onprem
  to   = azurerm_local_network_gateway.lng_onprem_instance["vnetGatewayConfig1"]
}

moved {
  from = azurerm_virtual_network_gateway_connection.hub_to_onprem
  to   = azurerm_virtual_network_gateway_connection.hub_to_onprem_instance["vnetGatewayConfig1"]
}

moved {
  from = azurerm_virtual_network_gateway_connection.onprem_to_hub
  to   = azurerm_virtual_network_gateway_connection.onprem_to_hub_instance["vnetGatewayConfig1"]
}

resource "azurerm_local_network_gateway" "lng_hub_instance" {
  for_each            = local.gateway_instances
  name                = each.key == "vnetGatewayConfig1" ? var.hub_local_network_gateway_name : "${var.hub_local_network_gateway_name}-2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  gateway_address     = azurerm_public_ip.vpngw_pip[each.value.index].ip_address

  bgp_settings {
    asn = var.vpn_gateway_bgp_asn
    # Optional explicit per-instance override; otherwise use discovered mapping.
    bgp_peering_address = coalesce(
      lookup(var.hub_bgp_peering_address_overrides, each.key, null),
      local.hub_bgp_by_ipconfig[each.key]
    )
  }
}

resource "azurerm_local_network_gateway" "lng_onprem_instance" {
  for_each            = local.gateway_instances
  name                = each.key == "vnetGatewayConfig1" ? var.onprem_local_network_gateway_name : "${var.onprem_local_network_gateway_name}-2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  gateway_address     = azurerm_public_ip.onprem_vpngw_pip[each.value.index].ip_address

  bgp_settings {
    asn = var.onprem_vpn_gateway_bgp_asn
    # Optional explicit per-instance override; otherwise use discovered mapping.
    bgp_peering_address = coalesce(
      lookup(var.onprem_bgp_peering_address_overrides, each.key, null),
      local.onprem_bgp_by_ipconfig[each.key]
    )
  }
}

resource "azurerm_virtual_network_gateway_connection" "hub_to_onprem_instance" {
  for_each                   = local.gateway_instances
  name                       = each.key == "vnetGatewayConfig1" ? var.hub_to_onprem_connection_name : "${var.hub_to_onprem_connection_name}-2"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.hub_vpngw.id
  local_network_gateway_id   = azurerm_local_network_gateway.lng_onprem_instance[each.key].id
  shared_key                 = var.vpn_shared_key
  bgp_enabled                = true

  depends_on = [
    azurerm_virtual_network_gateway.hub_vpngw,
    azurerm_virtual_network_gateway.onprem_vpngw
  ]
}

resource "azurerm_virtual_network_gateway_connection" "onprem_to_hub_instance" {
  for_each                   = local.gateway_instances
  name                       = each.key == "vnetGatewayConfig1" ? var.onprem_to_hub_connection_name : "${var.onprem_to_hub_connection_name}-2"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.onprem_vpngw.id
  local_network_gateway_id   = azurerm_local_network_gateway.lng_hub_instance[each.key].id
  shared_key                 = var.vpn_shared_key
  bgp_enabled                = true

  depends_on = [
    azurerm_virtual_network_gateway.hub_vpngw,
    azurerm_virtual_network_gateway.onprem_vpngw
  ]
}
```

### 3) `terraform.tfvars` update for Option A

```hcl
# Option A: keep empty to auto-discover current per-instance BGP mapping.
hub_bgp_peering_address_overrides    = {}
onprem_bgp_peering_address_overrides = {}
```

---

## Notes for Future Incidents

1. Re-run repeated TCP checks instead of one-off checks:
   - `Test-NetConnection` may expose intermittent behavior that single tests miss.
2. In active-active topologies, verify both peer IPs are connected:
   - `az network vnet-gateway list-bgp-peer-status ...`
3. Avoid relying on Telnet as primary evidence:
   - Prefer `Test-NetConnection -Port 3389`.
4. Keep per-instance LNG/connection model for deterministic behavior.

---

## GatewaySubnet UDR Simulation (MS Troubleshooting Scenario)

Reference scenario tested:

- <https://learn.microsoft.com/en-au/azure/route-server/troubleshoot-route-server#why-do-i-experience-on-premises-connectivity-issues-after-adding-a-user-defined-route-udr-on-the-gatewaysubnet>

Objective:

- Simulate on-prem connectivity degradation when GatewaySubnet traffic is forced through an NVA.

### A) Clean baseline capture (before simulation)

Commands executed:

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-nva-hub \
  --command-id RunShellScript \
  --scripts "for i in 1 2 3 4; do sudo iptables -D FORWARD -s 10.2.253.0/27 -d 10.2.254.0/24 -p tcp --sport 179 -j DROP 2>/dev/null || true; sudo iptables -D FORWARD -s 10.2.254.0/24 -d 10.2.253.0/27 -p tcp --dport 179 -j DROP 2>/dev/null || true; done; sudo iptables -S FORWARD" -o json

az network vnet-gateway list-bgp-peer-status -g rg-ars-end-to-end-lab -n vpngw-hub -o table

az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "1..5 | ForEach-Object { Test-NetConnection 192.168.1.4 -Port 3389 | Select-Object RemoteAddress,RemotePort,TcpTestSucceeded }" -o json
```

Before output highlights:

- NVA FORWARD chain: `-P FORWARD ACCEPT` (no BGP DROP rules).
- Hub BGP: both on-prem peers (`192.168.254.4`, `192.168.254.5`) were `Connected`.
- Spoke-A -> on-prem TCP/3389: `5/5 True`.

### B) Simulation setup

Commands executed:

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-nva-hub \
  --command-id RunShellScript \
  --scripts "sudo iptables -I FORWARD 1 -s 10.2.254.0/24 -d 10.2.253.0/27 -p tcp --dport 179 -j DROP; sudo iptables -I FORWARD 1 -s 10.2.253.0/27 -d 10.2.254.0/24 -p tcp --sport 179 -j DROP; sudo iptables -S FORWARD" -o json

az network route-table create -g rg-ars-end-to-end-lab -n rt-gateway-subnet-udr-test -o json

az network route-table route create -g rg-ars-end-to-end-lab \
  --route-table-name rt-gateway-subnet-udr-test \
  -n force-hub-vnet-via-nva \
  --address-prefix 10.2.0.0/16 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 10.2.1.10 -o json

az network route-table route create -g rg-ars-end-to-end-lab \
  --route-table-name rt-gateway-subnet-udr-test \
  -n force-routeserver-subnet-via-nva \
  --address-prefix 10.2.253.0/27 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 10.2.1.10 -o json

az network vnet subnet update -g rg-ars-end-to-end-lab --vnet-name vnet-hub -n GatewaySubnet \
  --route-table rt-gateway-subnet-udr-test -o json
```

Simulation route table entries:

- `10.2.0.0/16 -> 10.2.1.10 (VirtualAppliance)`
- `10.2.253.0/27 -> 10.2.1.10 (VirtualAppliance)`

### C) Impact capture (after simulation)

Commands executed:

```bash
az network route-table route list -g rg-ars-end-to-end-lab --route-table-name rt-gateway-subnet-udr-test -o table

az network vnet-gateway list-bgp-peer-status -g rg-ars-end-to-end-lab -n vpngw-hub -o table

az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "1..8 | ForEach-Object { Test-NetConnection 192.168.1.4 -Port 3389 | Select-Object RemoteAddress,RemotePort,TcpTestSucceeded }" -o json
```

After output highlights:

- Hub BGP still showed both on-prem peers `Connected`.
- Spoke-A -> on-prem TCP/3389 remained stable: `8/8 True`.

Result of this simulation run:

- **The expected connectivity drop was not reproduced in this lab run**, even with explicit `RouteServerSubnet` forcing and injected BGP DROP filters on the NVA.

### D) Rollback and post-rollback verification

Commands executed:

```bash
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-nva-hub \
  --command-id RunShellScript \
  --scripts "for i in 1 2 3 4; do sudo iptables -D FORWARD -s 10.2.253.0/27 -d 10.2.254.0/24 -p tcp --sport 179 -j DROP 2>/dev/null || true; sudo iptables -D FORWARD -s 10.2.254.0/24 -d 10.2.253.0/27 -p tcp --dport 179 -j DROP 2>/dev/null || true; done; sudo iptables -S FORWARD" -o json

az network vnet subnet update -g rg-ars-end-to-end-lab --vnet-name vnet-hub -n GatewaySubnet --remove routeTable -o json

az network route-table delete -g rg-ars-end-to-end-lab -n rt-gateway-subnet-udr-test

az network route-table show -g rg-ars-end-to-end-lab -n rt-gateway-subnet-udr-test --query id -o tsv

az network vnet-gateway list-bgp-peer-status -g rg-ars-end-to-end-lab -n vpngw-hub -o table

az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "1..5 | ForEach-Object { Test-NetConnection 192.168.1.4 -Port 3389 | Select-Object RemoteAddress,RemotePort,TcpTestSucceeded }" -o json
```

Rollback output highlights:

- NVA FORWARD chain returned to `-P FORWARD ACCEPT` with no injected DROP rules.
- `rt-gateway-subnet-udr-test` no longer exists (`ResourceNotFound` on show).
- Hub BGP healthy.
- Spoke-A -> on-prem TCP/3389: `5/5 True`.

### E) Interpretation

In this specific lab state (dual-instance deterministic S2S model already in place), the MS guide scenario did not manifest as a visible outage during this run. This can happen when the intermediary path still forwards required control-plane flows despite UDR forcing. The simulation artifacts were fully removed after testing.

---

## AD DS and DNS Controller Bring-Up Troubleshooting (Spoke A)

This section documents the complete remediation sequence used to deploy two domain controllers in Spoke A and stabilize AD replication.

### Objective

- Deploy `vm-spoke-a-dc-1` and `vm-spoke-a-dc-2`
- Promote DC1 as forest root for `corp.contoso.local`
- Promote DC2 as replica domain controller
- Validate AD replication health

### Initial failure: compute quota exhaustion

Symptom during `terraform apply`:

- DC1 creation failed with `standardBSFamily` quota error in `australiaeast`

Quota verification:

```bash
az vm list-usage -l australiaeast -o table
```

Key finding:

- `Standard BS Family vCPUs`: `10/10` (fully consumed)

Remediation applied:

- Changed DC VM size from `Standard_B2s` to `Standard_D2s_v3` in `terraform.tfvars`

### Secondary failure: DC1 promotion script exited non-zero

Symptom:

- Extension `promote-dc1-ad-dns` failed with `VMExtensionProvisioningError`

Root cause:

- Script called `Get-ADDomain` too early with strict error handling before ADWS context was ready.

Remediation applied in `spoke-a-domain-services.tf`:

- Added `Import-Module ActiveDirectory`
- Replaced direct `Get-ADDomain` condition with safe `try/catch`-based domain-exists logic

### Terraform state drift handling for failed VM extensions

When extension creation fails, Azure can still retain the extension resource while Terraform state does not.

Observed symptoms:

- Terraform error: resource already exists and must be imported.

Remediation commands used:

```bash
terraform import 'azurerm_virtual_machine_extension.spoke_a_dc1_promote' \
  '/subscriptions/51876dac-fb04-456e-a204-5e8fbc440c15/resourceGroups/rg-ars-end-to-end-lab/providers/Microsoft.Compute/virtualMachines/vm-spoke-a-dc-1/extensions/promote-dc1-ad-dns'

terraform import 'azurerm_virtual_machine_extension.spoke_a_dc2_promote' \
  '/subscriptions/51876dac-fb04-456e-a204-5e8fbc440c15/resourceGroups/rg-ars-end-to-end-lab/providers/Microsoft.Compute/virtualMachines/vm-spoke-a-dc-2/extensions/promote-dc2-ad-replica'
```

### DC2 replica promotion failures and fixes

Observed failures:

1. `An Active Directory domain controller for the domain ... could not be contacted`
2. Timeout waiting for domain readiness from DC2
3. Prereq path warning around static IP checks causing non-zero return in extension flow

Remediation applied in `spoke-a-domain-services.tf`:

- Added explicit readiness loop for primary DC using:
  - DNS resolution against `10.3.0.10`
  - LDAP port `389`
  - ADWS port `9389`
- Set explicit replication source to `spokeadc1.corp.contoso.local`
- Added `-SkipPreChecks` on `Install-ADDSDomainController` for this lab VM context

### Final deployment status

Final Terraform result:

- `Apply complete! Resources: 0 added, 1 changed, 0 destroyed.`

Final extension status check:

```bash
az vm get-instance-view -g rg-ars-end-to-end-lab -n vm-spoke-a-dc-2 \
  --query "instanceView.extensions[?name=='promote-dc2-ad-replica'].[name,statuses[0].displayStatus,substatuses[0].displayStatus]" -o tsv
```

Observed output:

- `promote-dc2-ad-replica  Provisioning succeeded  Provisioning succeeded`

### Replication validation commands and outcome

Commands executed on DC2:

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

Observed outcome:

- `repadmin /replsummary`: `0` failures
- `repadmin /showrepl`: inbound neighbors from `spokeadc1` successful for all naming contexts
- `dcdiag /test:replications /v`: `spokeadc2 passed test Replications`

### Operational notes

1. If `az vm run-command invoke` returns `Conflict`, wait and retry after current run-command execution completes.
2. For this lab, DC promotion through CustomScriptExtension is reliable after readiness gating and extension-state imports.
3. Keep the D-series size in this region unless BS-family quota is increased.

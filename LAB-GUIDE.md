# Azure Route Server (ARS) End-to-End Test Lab Guide

A comprehensive lab to validate Azure Route Server (ARS) behavior, hub-spoke route propagation, NVA-injected synthetic routes, branch-to-branch traffic isolation, and spoke-to-spoke transit through a Linux NVA.

---

## 1. Purpose

This lab demonstrates and validates the following Azure networking behaviors:

1. **Azure Route Server (ARS) BGP integration** with a Linux NVA running FRR.
2. **Route propagation between hub VPN gateway, ARS, and connected spokes** when gateway transit is enabled.
3. **Route isolation** when gateway transit is disabled on a spoke (validates whether ARS or peering leaks routes inappropriately).
4. **Branch-to-branch traffic control** with ARS `branch_to_branch_traffic_enabled = false`.
5. **Synthetic route advertisement from an NVA** (`172.16.0.0/24`) using FRR BGP and blackhole route injection.
6. **Spoke-to-spoke transit via NVA** using user-defined routes (UDRs).
7. **End-to-end IPsec + BGP** connectivity between hub and simulated on-prem environment using two Azure VPN gateways.

---

## 2. Architecture

### 2.1 Network Topology

```
                 ┌────────────────────────────────────────────────┐
                 │              vnet-hub  10.2.0.0/16             │
                 │                                                │
                 │  GatewaySubnet    RouteServerSubnet   NvaSubnet│
                 │   10.2.254.0/24    10.2.253.0/27    10.2.1.0/24│
                 │   ┌─────────┐    ┌──────────────┐  ┌─────────┐ │
                 │   │ vpngw-  │    │  ars-hub     │  │ vm-nva- │ │
                 │   │  hub    │◄──►│ ASN 65515    │◄►│  hub    │ │
                 │   │ ASN     │BGP │ 10.2.253.4/5 │BGP│ FRR     │ │
                 │   │ 65010   │    │              │  │ ASN     │ │
                 │   │ A/A     │    └──────────────┘  │ 65002   │ │
                 │   └────┬────┘                      └─────────┘ │
                 │        │ S2S IPsec + BGP                       │
                 └────────┼────────────────────────────────────────┘
                          │              │                     │
                  Peering │              │ Peering             │ Peering
                          │              │ (transit ON)        │ (transit OFF)
                          ▼              ▼                     ▼
        ┌────────────────────────┐  ┌─────────────────┐  ┌─────────────────┐
        │ vnet-onprem            │  │ vnet-spoke-a    │  │ vnet-spoke-b    │
        │ 192.168.0.0/16         │  │ 10.3.0.0/16     │  │ 10.4.0.0/16     │
        │                        │  │                 │  │                 │
        │ GatewaySubnet          │  │ Subnet-Default  │  │ Subnet-Default  │
        │ 192.168.254.0/24       │  │ 10.3.0.0/24     │  │ 10.4.0.0/24     │
        │ vpngw-onprem           │  │ vm-spoke-a-     │  │ vm-spoke-b-     │
        │ ASN 65001, A/A         │  │   win22-1       │  │   win22-1       │
        │                        │  │                 │  │                 │
        │ Subnet-Default         │  │ UDR -> NVA      │  │ UDR -> NVA      │
        │ 192.168.1.0/24         │  │ for 10.4.0.0/16 │  │ for 10.3.0.0/16 │
        │ vm-onprem-win22-1      │  │                 │  │                 │
        └────────────────────────┘  └─────────────────┘  └─────────────────┘
```

### 2.2 BGP/ASN Map

| Component             | ASN     | Notes                                          |
|-----------------------|---------|------------------------------------------------|
| Hub VPN Gateway       | 65010   | Active-active                                  |
| Simulated On-Prem VGW | 65001   | Active-active                                  |
| Azure Route Server    | 65515   | Microsoft-managed, fixed value                 |
| Linux NVA (FRR)       | 65002   | eBGP-multihop to both ARS instances            |

### 2.3 Peering Matrix

| Source → Remote              | allow_gateway_transit | use_remote_gateways |
|------------------------------|-----------------------|---------------------|
| hub → spoke-a                | true                  | n/a                 |
| spoke-a → hub                | n/a                   | true                |
| hub → spoke-b                | false                 | n/a                 |
| spoke-b → hub                | n/a                   | false               |

### 2.4 Address Plan

| Resource                 | CIDR              |
|--------------------------|-------------------|
| Hub VNet                 | 10.2.0.0/16       |
| Hub GatewaySubnet        | 10.2.254.0/24     |
| Hub RouteServerSubnet    | 10.2.253.0/27     |
| Hub NvaSubnet            | 10.2.1.0/24       |
| Hub Default              | 10.2.0.0/24       |
| Spoke A                  | 10.3.0.0/16       |
| Spoke B                  | 10.4.0.0/16       |
| On-Prem VNet             | 192.168.0.0/16    |
| On-Prem GatewaySubnet    | 192.168.254.0/24  |
| On-Prem Default          | 192.168.1.0/24    |
| NVA Synthetic Route      | 172.16.0.0/24     |

---

## 3. Components Reference

### 3.1 Terraform Files

| File                    | Purpose                                                                  |
|-------------------------|--------------------------------------------------------------------------|
| [main.tf](main.tf)      | Resource group                                                           |
| [providers.tf](providers.tf) / [terraform.tf](terraform.tf) | Provider, backend                  |
| [variables.tf](variables.tf) | All input variables (network, BGP ASNs, VM sizes, names)            |
| [terraform.tfvars](terraform.tfvars) | Active lab values                                            |
| [networking.tf](networking.tf) | Hub, on-prem, and spoke VNets/subnets                              |
| [gateway-routeserver.tf](gateway-routeserver.tf) | Hub + on-prem VPN gateways and ARS                |
| [s2s-bgp.tf](s2s-bgp.tf) | Local network gateways and S2S BGP-enabled connections                  |
| [nva.tf](nva.tf)        | Linux NVA VM, FRR cloud-init, ARS BGP peering                            |
| [peering.tf](peering.tf) | Hub↔Spoke A (transit on), Hub↔Spoke B (transit off)                     |
| [transit-udr.tf](transit-udr.tf) | UDRs sending spoke-to-spoke traffic via the NVA                 |
| [compute.tf](compute.tf) | Windows test VMs in Spoke A, Spoke B, and On-Prem + NSGs                |
| [outputs.tf](outputs.tf) | Convenience outputs                                                     |

### 3.2 Key Resources

- **`vpngw-hub`** — Active-active hub VPN gateway, ASN 65010.
- **`vpngw-onprem`** — Active-active simulated on-prem VPN gateway, ASN 65001.
- **`ars-hub`** — Azure Route Server, ASN 65515, branch-to-branch traffic disabled.
- **`vm-nva-hub`** — Ubuntu 22.04 with FRR, ASN 65002, advertises `172.16.0.0/24`.
- **`lng-hub-representation`** / **`lng-onprem-representation`** — Local network gateways with BGP peering addresses (`10.2.254.x` for hub, `192.168.254.4` for on-prem after override fix).
- **`conn-hub-to-onprem`** / **`conn-onprem-to-hub`** — IPsec connections with `bgp_enabled = true`.
- **`rt-spoke-a-transit`** / **`rt-spoke-b-transit`** — Route tables sending opposite-spoke traffic through NVA at `10.2.1.10`.
- **`vm-spoke-a-win22-1`** / **`vm-spoke-b-win22-1`** / **`vm-onprem-win22-1`** — Windows Server 2022 test VMs.

---

## 4. Deployment

### 4.1 Quick Start

```bash
# 1. Configure your subscription
cd /Users/gnaneshwara.babu/Projects/git/local/az-ars-lab-test
cp terraform.tfvars.example terraform.tfvars   # if not already present
# Edit terraform.tfvars and set subscription_id

# 2. Initialize and validate
terraform init
terraform fmt -recursive
terraform validate

# 3. Plan and apply
terraform plan -out tfplan
terraform apply tfplan
```

### 4.2 Important Configuration Notes

- **`onprem_bgp_peering_address_override = "192.168.254.4"`** — required because the active-active on-prem gateway exposes two BGP peering addresses (`192.168.254.4` and `192.168.254.5`); the hub's `lng-onprem-representation` must point at the **first** one (`.4`) to establish BGP. Using `.5` leaves the peer stuck in `Connecting`.
- **ASN decoupling** — `vpn_gateway_bgp_asn` (65010) must NOT equal `ars_bgp_asn` (65515). Using 65515 on the LNG fails with `InvalidAsn`.
- **NVA blackhole route** — cloud-init runs `ip route replace blackhole 172.16.0.0/24` before FRR starts so the FRR `network 172.16.0.0/24` statement has a route to originate.

### 4.3 Teardown

```bash
terraform destroy
```

---

## 5. Test Scenarios

### 5.1 Test Matrix Overview

| #   | Scenario                                                  | Expected Result                                |
|-----|-----------------------------------------------------------|------------------------------------------------|
| T1  | Hub↔On-prem S2S tunnel up                                 | `ConnectionStatus = Connected`                 |
| T2  | Hub gateway BGP peers established                         | All 4 ARS/on-prem peers `Connected`            |
| T3  | Hub gateway learns on-prem prefix                         | `192.168.0.0/16` learned via EBgp 65001        |
| T4  | NVA BGP peers with ARS                                    | Both ARS peers `Connected` for the NVA         |
| T5  | NVA synthetic route reaches ARS                           | ARS learns `172.16.0.0/24` from NVA            |
| T6  | Spoke A learns on-prem route via gateway transit          | Effective route `192.168.0.0/16` → VNG         |
| T7  | Spoke B does NOT have usable on-prem route                | `192.168.0.0/16` → Next Hop `None`             |
| T8  | Spoke B sees NO `VirtualNetworkGateway` source routes     | No VNG-sourced routes in Spoke B               |
| T9  | Spoke-to-spoke transit via NVA UDRs                       | UDR `10.x.0.0/16` → VirtualAppliance 10.2.1.10 |
| T10 | Branch-to-branch isolation (ARS setting)                  | Off-spoke prefixes not learned cross-branch    |
| T11 | End-to-end host reachability Spoke A → On-prem VM         | Reachable (TCP probe to listening port)        |
| T12 | End-to-end isolation Spoke B → On-prem VM                 | Not reachable                                  |

### 5.2 Detailed Test Procedures

#### T1. Verify S2S IPsec Tunnel

**Goal:** Confirm IPsec tunnel between hub and on-prem is up.

```bash
az network vpn-connection show \
  --resource-group rg-ars-end-to-end-lab \
  --name conn-hub-to-onprem \
  --query '{ConnectionStatus: connectionStatus, ConnectionProtocol: connectionProtocol, Egress: egressBytesTransferred, Ingress: ingressBytesTransferred}' \
  -o table
```

**Pass criteria:** `ConnectionStatus = Connected` and non-zero ingress/egress bytes after generating traffic.

---

#### T2. Verify Hub BGP Peer States

**Goal:** Confirm all expected BGP neighbors on the hub VPN gateway are `Connected`.

```bash
az network vnet-gateway list-bgp-peer-status \
  --resource-group rg-ars-end-to-end-lab \
  --name vpngw-hub \
  -o table
```

**Pass criteria:**

- `192.168.254.4` (ASN 65001) → `Connected`, RoutesReceived ≥ 1
- `10.2.253.4` and `10.2.253.5` (ASN 65515) → `Connected`
- Internal IBGP peers (10.2.254.x ASN 65010) `Connected` cross-instance

**If `192.168.254.5` is stuck in `Connecting`:** that is the *second* on-prem peering address; the override is set to `.4` and only one needs to come up for routing to work.

---

#### T3. Verify Hub-Learned Routes

**Goal:** Confirm hub gateway has learned `192.168.0.0/16` from on-prem.

```bash
az network vnet-gateway list-learned-routes \
  --resource-group rg-ars-end-to-end-lab \
  --name vpngw-hub \
  -o table
```

**Pass criteria:** Row exists for `192.168.0.0/16` with `Origin = EBgp`, `SourcePeer = 192.168.254.4`, `AsPath = 65001`.

---

#### T4. Verify NVA ↔ ARS BGP

**Goal:** Confirm NVA peers with both ARS instances.

```bash
az network routeserver peering list \
  --resource-group rg-ars-end-to-end-lab \
  --routeserver ars-hub \
  -o table
```

Inside the NVA (SSH via NVA public IP if exposed, or via serial console):

```bash
sudo vtysh -c "show bgp summary"
sudo vtysh -c "show ip bgp"
```

**Pass criteria:** `Established` BGP sessions to both `10.2.253.4` and `10.2.253.5`.

---

#### T5. Verify NVA Synthetic Route Reaches ARS

**Goal:** ARS should learn `172.16.0.0/24` from NVA and re-advertise to hub VPN gateway.

```bash
az network routeserver peering list-learned-routes \
  --resource-group rg-ars-end-to-end-lab \
  --routeserver ars-hub \
  --name <nva-peer-name> \
  -o table
```

And on the hub gateway:

```bash
az network vnet-gateway list-learned-routes \
  --resource-group rg-ars-end-to-end-lab \
  --name vpngw-hub \
  -o table | grep 172.16
```

**Pass criteria:** `172.16.0.0/24` appears in both outputs.

---

#### T6. Verify Spoke A Learns On-Prem Route

**Goal:** Spoke A NIC effective routes should include `192.168.0.0/16` via `VirtualNetworkGateway`.

```bash
az network nic show-effective-route-table \
  --resource-group rg-ars-end-to-end-lab \
  --name nic-spoke-a-win22-1 \
  -o table
```

**Pass criteria:**

```
Source                 State    Address Prefix    Next Hop Type          Next Hop IP
VirtualNetworkGateway  Active   192.168.0.0/16    VirtualNetworkGateway  10.2.254.5 10.2.254.4
```

---

#### T7. Verify Spoke B Does NOT Have Usable On-Prem Path

**Goal:** Spoke B should NOT have a forwardable route to on-prem.

```bash
az network nic show-effective-route-table \
  --resource-group rg-ars-end-to-end-lab \
  --name nic-spoke-b-win22-1 \
  -o table
```

**Pass criteria:**

```
Source    State    Address Prefix    Next Hop Type     Next Hop IP
Default   Active   192.168.0.0/16    None
```

The prefix appears (it's a system-known prefix) but **Next Hop Type = None** means traffic is dropped. This proves route isolation works at the data plane.

---

#### T8. Verify No VirtualNetworkGateway-Sourced Routes on Spoke B

**Goal:** Confirm gateway transit is not leaking BGP routes into Spoke B.

```bash
az network nic show-effective-route-table \
  --resource-group rg-ars-end-to-end-lab \
  --name nic-spoke-b-win22-1 \
  -o table | grep -i virtualnetworkgateway
```

**Pass criteria:** Empty output (no rows). Spoke B shows only `Default` and `User` sources.

---

#### T9. Verify Spoke-to-Spoke Transit UDR

**Goal:** UDR forces spoke-to-spoke traffic through the NVA.

```bash
az network route-table show \
  --resource-group rg-ars-end-to-end-lab \
  --name rt-spoke-a-transit \
  --query 'routes[].{name:name,prefix:addressPrefix,nextHop:nextHopType,ip:nextHopIpAddress}' \
  -o table

az network route-table show \
  --resource-group rg-ars-end-to-end-lab \
  --name rt-spoke-b-transit \
  --query 'routes[].{name:name,prefix:addressPrefix,nextHop:nextHopType,ip:nextHopIpAddress}' \
  -o table
```

**Pass criteria:**

- Spoke A RT: `10.4.0.0/16 → VirtualAppliance → 10.2.1.10`
- Spoke B RT: `10.3.0.0/16 → VirtualAppliance → 10.2.1.10`

And the User-sourced rows appear on each spoke NIC's effective route table:

```
User   Active   10.4.0.0/16   VirtualAppliance   10.2.1.10   (on Spoke A)
User   Active   10.3.0.0/16   VirtualAppliance   10.2.1.10   (on Spoke B)
```

---

#### T10. Branch-to-Branch Isolation

**Goal:** With `route_server_branch_to_branch_traffic_enabled = false`, the on-prem branch should not learn NVA-injected routes (and vice versa), preventing routes learned through one branch from being advertised to another.

```bash
az network vnet-gateway list-advertised-routes \
  --resource-group rg-ars-end-to-end-lab \
  --name vpngw-hub \
  --peer 192.168.254.4 \
  -o table
```

**Pass criteria:** `172.16.0.0/24` (the NVA synthetic route) is NOT advertised toward on-prem peer.

---

#### T11. End-to-End Host Reachability — Spoke A → On-Prem VM

**Goal:** Validate data-plane reachability through hub gateway.

```bash
# Get on-prem VM IP
az vm show -g rg-ars-end-to-end-lab -n vm-onprem-win22-1 -d --query privateIps -o tsv

# TCP probe (more reliable than ICMP through Run Command):
az vm run-command invoke \
  -g rg-ars-end-to-end-lab \
  -n vm-spoke-a-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "Test-NetConnection -ComputerName 192.168.1.4 -Port 3389 -InformationLevel Quiet" \
  -o json
```

**Pass criteria:** Returns `True`. Note: ICMP via `Test-Connection` under Run Command may fail due to raw socket restrictions — prefer `Test-NetConnection -Port 3389` (RDP listens by default on Windows VMs).

---

#### T12. End-to-End Isolation — Spoke B → On-Prem VM

**Goal:** Validate Spoke B cannot reach on-prem.

```bash
az vm run-command invoke \
  -g rg-ars-end-to-end-lab \
  -n vm-spoke-b-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "Test-NetConnection -ComputerName 192.168.1.4 -Port 3389 -InformationLevel Quiet" \
  -o json
```

**Pass criteria:** Returns `False`. The on-prem prefix has `Next Hop Type = None` in Spoke B effective routes, so packets are dropped at the platform.

---

## 6. Command Reference

All commands run from the lab repository root unless noted.

### 6.1 Terraform Lifecycle

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -no-color
terraform plan -out tfplan
terraform apply tfplan
terraform apply           # interactive
terraform destroy
terraform state list
terraform state show <resource_address>
```

### 6.2 Resource Inventory

```bash
# All VMs with private IPs
az vm list -g rg-ars-end-to-end-lab -d -o table

# Specific VM private IP
az vm show -g rg-ars-end-to-end-lab -n vm-onprem-win22-1 -d --query privateIps -o tsv

# All NSGs
az network nsg list -g rg-ars-end-to-end-lab -o table

# Route tables
az network route-table list -g rg-ars-end-to-end-lab -o table
```

### 6.3 VPN / Gateway Diagnostics

```bash
# Connection status
az network vpn-connection show \
  --resource-group rg-ars-end-to-end-lab \
  --name conn-hub-to-onprem \
  --query '{ConnectionStatus: connectionStatus, Ingress: ingressBytesTransferred, Egress: egressBytesTransferred}' \
  -o table

# BGP peer status
az network vnet-gateway list-bgp-peer-status \
  --resource-group rg-ars-end-to-end-lab \
  --name vpngw-hub \
  -o table

az network vnet-gateway list-bgp-peer-status \
  --resource-group rg-ars-end-to-end-lab \
  --name vpngw-onprem \
  -o table

# Learned routes
az network vnet-gateway list-learned-routes \
  --resource-group rg-ars-end-to-end-lab \
  --name vpngw-hub \
  -o table

az network vnet-gateway list-learned-routes \
  --resource-group rg-ars-end-to-end-lab \
  --name vpngw-onprem \
  -o table

# Routes advertised to a specific peer
az network vnet-gateway list-advertised-routes \
  --resource-group rg-ars-end-to-end-lab \
  --name vpngw-hub \
  --peer 192.168.254.4 \
  -o table

# Gateway BGP peering addresses
az network vnet-gateway show \
  --resource-group rg-ars-end-to-end-lab \
  --name vpngw-onprem \
  --query 'bgpSettings.bgpPeeringAddresses' \
  -o json

az network vnet-gateway show \
  --resource-group rg-ars-end-to-end-lab \
  --name vpngw-hub \
  --query 'bgpSettings.bgpPeeringAddresses[].defaultBgpIpAddresses[0]' \
  -o json
```

### 6.4 Azure Route Server

```bash
# List ARS peerings
az network routeserver peering list \
  --resource-group rg-ars-end-to-end-lab \
  --routeserver ars-hub \
  -o table

# Learned routes from a peer (replace <peer-name>)
az network routeserver peering list-learned-routes \
  --resource-group rg-ars-end-to-end-lab \
  --routeserver ars-hub \
  --name <peer-name> \
  -o table

# Routes advertised to a peer
az network routeserver peering list-advertised-routes \
  --resource-group rg-ars-end-to-end-lab \
  --routeserver ars-hub \
  --name <peer-name> \
  -o table

# Show ARS
az network routeserver show \
  --resource-group rg-ars-end-to-end-lab \
  --name ars-hub \
  -o json
```

### 6.5 Effective Routes & NSG

```bash
# Effective route table for a NIC
az network nic show-effective-route-table \
  --resource-group rg-ars-end-to-end-lab \
  --name nic-spoke-a-win22-1 \
  -o table

az network nic show-effective-route-table \
  --resource-group rg-ars-end-to-end-lab \
  --name nic-spoke-b-win22-1 \
  -o table

az network nic show-effective-route-table \
  --resource-group rg-ars-end-to-end-lab \
  --name nic-onprem-win22-1 \
  -o table

# Effective NSG rules
az network nic list-effective-nsg \
  --resource-group rg-ars-end-to-end-lab \
  --name nic-onprem-win22-1 \
  -o json

# NSG details
az network nsg show -g rg-ars-end-to-end-lab -n nsg-onprem-test -o json

# Subnet NSG association
az network vnet subnet show \
  --resource-group rg-ars-end-to-end-lab \
  --vnet-name vnet-onprem \
  --name Subnet-Default \
  --query '{nsg:networkSecurityGroup.id,addressPrefix:addressPrefix}' \
  -o json

# Add a temporary diagnostic NSG rule
az network nsg rule create \
  -g rg-ars-end-to-end-lab \
  --nsg-name nsg-onprem-test \
  -n allow-icmp-any-temp \
  --priority 130 \
  --direction Inbound \
  --access Allow \
  --protocol Icmp \
  --source-address-prefixes '*' \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges '*'

# Remove the temp rule
az network nsg rule delete \
  -g rg-ars-end-to-end-lab \
  --nsg-name nsg-onprem-test \
  -n allow-icmp-any-temp
```

### 6.6 In-Guest Diagnostics via Run Command

```bash
# Enable inbound ICMP on a Windows VM
az vm run-command invoke \
  -g rg-ars-end-to-end-lab \
  -n vm-onprem-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "Enable-NetFirewallRule -DisplayName 'File and Printer Sharing (Echo Request - ICMPv4-In)'; Write-Output 'ICMP_RULE=ENABLED'" \
  -o json

# TCP reachability (preferred under Run Command)
az vm run-command invoke \
  -g rg-ars-end-to-end-lab \
  -n vm-spoke-a-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "Test-NetConnection -ComputerName 192.168.1.4 -Port 3389 -InformationLevel Quiet" \
  -o json

# Boolean ICMP probe (less reliable due raw socket constraints)
az vm run-command invoke \
  -g rg-ars-end-to-end-lab \
  -n vm-spoke-a-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "if (Test-Connection -ComputerName 192.168.1.4 -Count 2 -Quiet) { 'SUCCESS' } else { 'FAIL' }" \
  -o json

# Tracert
az vm run-command invoke \
  -g rg-ars-end-to-end-lab \
  -n vm-spoke-a-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "tracert -d 192.168.1.4" \
  -o json

# Temporarily disable Windows Firewall for isolation testing
az vm run-command invoke \
  -g rg-ars-end-to-end-lab \
  -n vm-onprem-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False; 'FW_DISABLED'" \
  -o json
```

### 6.7 NVA Diagnostics (inside the Linux VM)

```bash
# FRR BGP summary
sudo vtysh -c "show bgp summary"

# All routes learned
sudo vtysh -c "show ip bgp"

# Specific neighbor
sudo vtysh -c "show ip bgp neighbors 10.2.253.4"

# Routes advertised
sudo vtysh -c "show ip bgp neighbors 10.2.253.4 advertised-routes"

# OS routing table (should include the blackhole)
ip route show
ip route show 172.16.0.0/24
```

---

## 7. Troubleshooting Playbook

### 7.1 `InvalidAsn` on Local Network Gateway

**Symptom:** `lng-hub-representation` fails to create with `InvalidAsn`.
**Cause:** ASN value matched ARS (65515), which is reserved.
**Fix:** Use distinct ASN for hub VPN gateway (e.g. 65010). The lab pins this in `terraform.tfvars`:

```
vpn_gateway_bgp_asn = 65010
ars_bgp_asn         = 65515
```

### 7.2 On-Prem BGP Peer Stuck in `Connecting`

**Symptom:** On-prem BGP peer (`192.168.254.4` or `192.168.254.5`) shows `Connecting` indefinitely.
**Cause:** An active-active VPN gateway has two instances (`ipconfig1`, `ipconfig2`), each with its own BGP peering address inside the gateway subnet (`192.168.254.4` and `192.168.254.5`). The S2S connection's IPsec tunnel terminates on the gateway instance whose **public IP matches the LNG's `gateway_address`** — and the LNG's `bgp_peering_address` must equal the BGP address bound to *that same* instance. If LNG points to the BGP address on the *other* instance, the BGP session can never establish because no IPsec tunnel exists to carry it.
**Fix:** Read the live mapping and align the override.

```bash
az network vnet-gateway show \
  --resource-group rg-ars-end-to-end-lab --name vpngw-onprem \
  --query 'bgpSettings.bgpPeeringAddresses[].{ip:ipconfigurationId,addrs:defaultBgpIpAddresses}' -o json

az network vnet-gateway show \
  --resource-group rg-ars-end-to-end-lab --name vpngw-onprem \
  --query 'ipConfigurations[].{name:name,pip:publicIpAddress.id}' -o json
```

Identify which `ipconfig` is bound to `pip-vpngw-onprem-1` (the public IP referenced by the hub's LNG `gateway_address`), then set:

```hcl
onprem_bgp_peering_address_override = "<bgp address of that ipconfig>"
```

`terraform apply`, then `az network vnet-gateway list-bgp-peer-status -g rg-ars-end-to-end-lab -n vpngw-hub -o table` until `Connected`.

**Pitfall — addresses flip after gateway reset:** Resetting either VPN gateway (or Azure-side maintenance) can swap which BGP peering address is bound to `ipconfig1` vs `ipconfig2`. The override that worked yesterday may be wrong today. This lab uses a hardcoded override for simplicity; for production, prefer one of:

- **Dual LNGs / dual connections**, one per instance public IP, each with its matching BGP address.
- **APIPA BGP IPs** (`169.254.21.x` custom BGP IPs on the gateway), which decouple BGP peering from the dynamic instance-level `192.168.254.x` mapping.
- **Single-instance (non-active-active) gateway** for lab/test scenarios where redundancy is not required.

### 7.3 NVA Synthetic Route Not Advertised

**Symptom:** ARS doesn't learn `172.16.0.0/24` from NVA.
**Cause:** FRR `network 172.16.0.0/24` requires the prefix to already exist in the kernel routing table.
**Fix:** Cloud-init injects a blackhole route before starting FRR:

```bash
ip route replace blackhole 172.16.0.0/24
```

Verify on the NVA: `ip route show 172.16.0.0/24` should show `blackhole`.

### 7.4 Spoke B Shows On-Prem Prefix in Effective Routes

**Symptom:** `192.168.0.0/16` appears in `nic-spoke-b-win22-1` effective routes.
**Diagnosis:** Look at the `Next Hop Type`.

- `None` → expected, prefix is system-known but non-forwardable. Isolation OK.
- `VirtualNetworkGateway` → unexpected, gateway transit leaked. Re-check `peering.tf` settings.

### 7.5 Ping Fails via `Test-Connection` Under Run Command

**Symptom:** `Test-Connection -Quiet` returns `False` even though routes look correct.
**Cause:** Azure Run Command sandbox restricts raw ICMP sockets on some Windows images.
**Workaround:** Use `Test-NetConnection -Port 3389` (TCP) which works reliably.

### 7.6 Subnet NSG Association Missing

**Symptom:** Test VM NIC `effective NSG` returns null.
**Cause:** NSG associated to subnet, not NIC — this is by design here. Confirm with:

```bash
az network vnet subnet show \
  --resource-group rg-ars-end-to-end-lab \
  --vnet-name vnet-onprem --name Subnet-Default \
  --query networkSecurityGroup.id -o tsv
```

---

## 8. Validation Walkthrough (Recommended Order)

Run these in sequence after `terraform apply`:

```bash
# 1. Tunnel up
az network vpn-connection show -g rg-ars-end-to-end-lab -n conn-hub-to-onprem --query connectionStatus -o tsv

# 2. BGP peers
az network vnet-gateway list-bgp-peer-status -g rg-ars-end-to-end-lab -n vpngw-hub -o table

# 3. Hub learned routes
az network vnet-gateway list-learned-routes -g rg-ars-end-to-end-lab -n vpngw-hub -o table

# 4. Spoke A effective routes (should see VirtualNetworkGateway -> 192.168.0.0/16)
az network nic show-effective-route-table -g rg-ars-end-to-end-lab -n nic-spoke-a-win22-1 -o table

# 5. Spoke B effective routes (should NOT see VirtualNetworkGateway source)
az network nic show-effective-route-table -g rg-ars-end-to-end-lab -n nic-spoke-b-win22-1 -o table

# 6. On-prem reachability from Spoke A (TCP probe)
ONPREM_IP=$(az vm show -g rg-ars-end-to-end-lab -n vm-onprem-win22-1 -d --query privateIps -o tsv)
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-a-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "Test-NetConnection -ComputerName $ONPREM_IP -Port 3389 -InformationLevel Quiet" -o json

# 7. Isolation from Spoke B
az vm run-command invoke -g rg-ars-end-to-end-lab -n vm-spoke-b-win22-1 \
  --command-id RunPowerShellScript \
  --scripts "Test-NetConnection -ComputerName $ONPREM_IP -Port 3389 -InformationLevel Quiet" -o json
```

---

## 9. Lessons Learned / Key Findings

1. **ASN reuse causes silent platform errors** — Always decouple ARS ASN (65515) from VPN gateway and LNG ASNs.
2. **Active-active gateways have multiple BGP peering addresses** — Only one needs to be wired into the LNG (the one bound to the same instance whose public IP the LNG's `gateway_address` references). The second peer may remain in `Connecting`; this is benign.
2a. **Active-active BGP peering addresses can flip across `ipconfig1`/`ipconfig2` after a gateway reset.** A hardcoded `bgp_peering_address` on the LNG is fragile: if the bound BGP address moves to the other instance, the BGP session fails over IPsec because the LNG/IPsec endpoint pairing no longer matches. Mitigations: dual LNG/connection per instance, APIPA custom BGP IPs, or non-active-active for lab use. See §7.2.
3. **`Next Hop Type = None` is the marker of route isolation** — A prefix being visible in effective routes does not mean it is reachable. Always inspect the next hop type.
4. **`branch_to_branch_traffic_enabled = false` on ARS** prevents cross-branch propagation but does NOT block VNet peering data-plane behavior. Peering transit flags (`allow_gateway_transit`, `use_remote_gateways`) control spoke-to-gateway route flow.
5. **FRR `network` directive needs an existing route** — use blackhole injection to advertise synthetic prefixes.
6. **`Test-Connection` under Run Command is unreliable** — TCP-based `Test-NetConnection` is the dependable in-guest probe in this sandbox.
7. **Spoke-to-spoke through NVA requires UDRs** — VNet peering alone does not transit between spokes; explicit user routes pointing at the NVA private IP are required, with `bgp_route_propagation_enabled` controlled per design.

---

## 10. File Map

| Path                                                         | Description                                  |
|--------------------------------------------------------------|----------------------------------------------|
| [README.md](README.md)                                       | High-level overview                          |
| [LAB-GUIDE.md](LAB-GUIDE.md)                                 | This document                                |
| [design.md](design.md)                                       | Original design notes                        |
| [main.tf](main.tf)                                           | Resource group                               |
| [providers.tf](providers.tf)                                 | AzureRM provider                             |
| [terraform.tf](terraform.tf)                                 | Backend & version pins                       |
| [variables.tf](variables.tf)                                 | All input variables                          |
| [terraform.tfvars](terraform.tfvars)                         | Active values                                |
| [terraform.tfvars.example](terraform.tfvars.example)         | Template                                     |
| [networking.tf](networking.tf)                               | VNets and subnets                            |
| [gateway-routeserver.tf](gateway-routeserver.tf)             | VPN gateways and ARS                         |
| [s2s-bgp.tf](s2s-bgp.tf)                                     | Local network gateways and S2S connections   |
| [nva.tf](nva.tf)                                             | Linux NVA + FRR + ARS peering                |
| [peering.tf](peering.tf)                                     | VNet peerings                                |
| [transit-udr.tf](transit-udr.tf)                             | Spoke-to-spoke UDRs                          |
| [compute.tf](compute.tf)                                     | Windows test VMs and NSGs                    |
| [outputs.tf](outputs.tf)                                     | Useful outputs                               |

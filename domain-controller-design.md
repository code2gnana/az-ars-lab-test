# Domain Controller Architecture Design

## Purpose
This design summarizes how domain controllers are implemented in the lab codebase, where AD DS and DNS are installed, and how the promotion flow is orchestrated.

## Where Domain Controllers Are Implemented

### Terraform implementation locations
- VM and NIC provisioning: [spoke-a-domain-controllers.tf](spoke-a-domain-controllers.tf)
- AD DS and DNS promotion scripts + VM extensions: [spoke-a-domain-services.tf](spoke-a-domain-services.tf)
- Spoke A subnet hosting DCs: [networking.tf](networking.tf)
- AD/DC input variables: [variables.tf](variables.tf)
- Active environment values (domain name, VM size, subnet CIDR): [terraform.tfvars](terraform.tfvars)

### Documentation locations reviewed
- Setup and operations runbook: [docs/addc_dns.md](docs/addc_dns.md)
- Troubleshooting and remediation history: [docs/troubleshooting_onprem_rdp_connection.md](docs/troubleshooting_onprem_rdp_connection.md)

## Key Design Findings From Code

1. Two dedicated Windows Server domain controller VMs are created in Spoke A:
- DC1: vm-spoke-a-dc-1 / spokeadc1 / 10.3.0.10
- DC2: vm-spoke-a-dc-2 / spokeadc2 / 10.3.0.11

2. Both NICs use static IPs and explicitly point DNS to both DC addresses:
- 10.3.0.10
- 10.3.0.11

3. AD DS deployment is extension-driven:
- DC1 extension (promote-dc1-ad-dns) creates forest/domain and DNS.
- DC2 extension (promote-dc2-ad-replica) waits for DNS/LDAP/ADWS readiness and then promotes as replica.

4. Domain and AD settings are parameterized:
- Domain: corp.contoso.local
- NetBIOS: CORP
- DSRM password: provided via variable

## Architecture Diagram

```mermaid
flowchart LR
  subgraph TF[Terraform Inputs and Modules]
    TV[terraform.tfvars\nspoke_a_dc_vm_size=Standard_D2s_v3\ndomain=corp.contoso.local]
    V[variables.tf\nAD/DC variables]
    C[spoke-a-domain-controllers.tf\nNIC + VM resources]
    S[spoke-a-domain-services.tf\nAD DS/DNS promotion extensions]
  end

  subgraph AZ[Azure Resource Group: rg-ars-end-to-end-lab]
    subgraph VNET[VNet: vnet-spoke-a 10.3.0.0/16]
      SUB[Subnet-Default\n10.3.0.0/24]
      NIC1[nic-spoke-a-dc-1\nIP 10.3.0.10\nDNS: 10.3.0.10,10.3.0.11]
      NIC2[nic-spoke-a-dc-2\nIP 10.3.0.11\nDNS: 10.3.0.10,10.3.0.11]
      DC1[VM: vm-spoke-a-dc-1\nComputer: spokeadc1]
      DC2[VM: vm-spoke-a-dc-2\nComputer: spokeadc2]
      EXT1[Extension: promote-dc1-ad-dns]
      EXT2[Extension: promote-dc2-ad-replica]
    end

    AD[AD Forest/Domain\ncorp.contoso.local]
    DNS[AD-integrated DNS Zone\ncorp.contoso.local]
  end

  TV --> C
  TV --> S
  V --> C
  V --> S

  C --> SUB
  SUB --> NIC1 --> DC1
  SUB --> NIC2 --> DC2

  S --> EXT1 --> DC1
  S --> EXT2 --> DC2
  EXT2 -.depends_on.-> EXT1

  EXT1 --> AD
  EXT1 --> DNS
  EXT2 --> AD
  EXT2 --> DNS
```

## Promotion Sequence

```mermaid
sequenceDiagram
  participant TF as Terraform Apply
  participant DC1 as vm-spoke-a-dc-1 (spokeadc1)
  participant DC2 as vm-spoke-a-dc-2 (spokeadc2)
  participant AD as AD DS / DNS (corp.contoso.local)

  TF->>DC1: Create VM + run promote-dc1-ad-dns
  DC1->>AD: Install AD DS + DNS, create forest/domain
  DC1-->>TF: Reboot and complete extension

  TF->>DC2: Run promote-dc2-ad-replica
  DC2->>DC1: Check DNS (53), LDAP (389), ADWS (9389) readiness
  DC2->>AD: Promote as replica domain controller
  DC2-->>TF: Reboot and complete extension
```

## Validation Traceability

The docs confirm this architecture and operational behavior:
- [docs/addc_dns.md](docs/addc_dns.md): setup procedure, validation commands, and expected outcomes.
- [docs/troubleshooting_onprem_rdp_connection.md](docs/troubleshooting_onprem_rdp_connection.md): quota remediation, extension state import handling, and final replication success.

## Notes

- The implementation intentionally uses static IP assignment for both DCs to keep DNS and AD service discovery deterministic.
- Extension ordering is deterministic: DC2 promotion waits for DC1 promotion completion and readiness checks.

## Active directory design

This view focuses only on Active Directory domain controllers and DNS service relationships.

```mermaid
flowchart TB
  DNSZone[(AD-integrated DNS Zone\ncorp.contoso.local)]
  Domain[(AD Domain\ncorp.contoso.local)]

  DC1[DC1\nvm-spoke-a-dc-1 / spokeadc1\n10.3.0.10\nRoles: AD DS + DNS]
  DC2[DC2\nvm-spoke-a-dc-2 / spokeadc2\n10.3.0.11\nRoles: AD DS + DNS]

  DC1 -->|Hosts| DNSZone
  DC2 -->|Hosts| DNSZone

  DC1 -->|Authoritative for| Domain
  DC2 -->|Replica DC for| Domain

  DC2 -->|AD replication| DC1
  DC2 -->|DNS queries and DC locator\n53, 389, 9389 readiness checks| DC1
```

### Active directory design (left-to-right variant)

```mermaid
flowchart LR
  DC1[DC1\nvm-spoke-a-dc-1 / spokeadc1\n10.3.0.10\nRoles: AD DS + DNS]
  DC2[DC2\nvm-spoke-a-dc-2 / spokeadc2\n10.3.0.11\nRoles: AD DS + DNS]

  Domain[(AD Domain\ncorp.contoso.local)]
  DNSZone[(AD-integrated DNS Zone\ncorp.contoso.local)]

  DC1 -->|Authoritative for| Domain
  DC2 -->|Replica DC for| Domain

  DC1 -->|Hosts| DNSZone
  DC2 -->|Hosts| DNSZone

  DC2 -->|AD replication| DC1
  DC2 -->|DNS + DC locator readiness checks| DC1
```

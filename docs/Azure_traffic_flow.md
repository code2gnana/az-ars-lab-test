## Azure Traffic Flow in This Lab

Use this doc when you need to understand control-plane versus data-plane behavior and route propagation outcomes.

This document explains traffic behavior in the Azure Route Server lab using two lenses:

- Control plane: how routes are learned, selected, and programmed.
- Data plane: how actual packets move after routes exist.

Both are required for successful connectivity. A healthy control plane does not always guarantee a healthy data plane.

## 1. Why This Matters

In this hub-and-spoke design, route visibility and route forwarding are intentionally different for Spoke A and Spoke B. The lab validates:

- Spoke A can consume intended remote routes.
- Spoke B stays isolated from usable remote transit routes.
- NVA-injected routes can be learned and propagated under policy controls.

Understanding control plane vs data plane is the key to interpreting test results correctly.

## 2. Topology Context

- Hub VNet hosts:
	- Hub VPN Gateway (ASN 65010)
	- Azure Route Server (ASN 65515)
	- Linux NVA with FRR (ASN 65002)
- Simulated on-prem VNet has VPN Gateway (ASN 65001)
- Spoke A uses remote gateway or route server path from hub
- Spoke B does not use remote gateway path

Important prefixes in this lab:

- 192.168.0.0/16 from on-prem branch
- 172.16.0.0/24 synthetic prefix advertised by NVA

## 3. Control Plane Explained

Control plane is route intelligence and decision making. It includes:

- BGP session establishment
- Prefix advertisement and learning
- Route selection and precedence
- Effective route programming on NICs and subnets

In this lab, control plane events include:

1. VPN BGP adjacency between hub and on-prem gateways.
2. BGP adjacency between NVA and both Route Server instances.
3. Route Server learning NVA and branch routes.
4. Route programming into effective routes according to peering and transit settings.

If control plane is wrong, forwarding is usually wrong even before traffic tests begin.

## 4. Data Plane Explained

Data plane is packet forwarding. It includes:

- Real VM-to-VM or VM-to-on-prem packet movement
- Next-hop forwarding through VPN gateway, virtual appliance, or platform routes
- Packet allow or drop behavior from NSG and guest firewall rules

In this lab, data plane validation includes:

- Spoke A TCP reachability to on-prem VM
- Spoke B expected inability to reach on-prem VM
- Spoke-to-spoke traffic through NVA based on UDRs

If data plane fails while control plane looks healthy, check NSGs, host firewall, asymmetric path, and next-hop realization.

## 5. Route Lifecycle in This Lab

### 5.1 On-prem Prefix 192.168.0.0/16

Control plane path:

1. On-prem VPN gateway advertises 192.168.0.0/16 over BGP.
2. Hub VPN gateway learns it.
3. Spoke route visibility depends on peering and gateway transit settings.
4. Spoke A gets usable path; Spoke B remains non-usable by design.

Data plane implication:

- Spoke A packets can be forwarded toward on-prem.
- Spoke B packets should not have a usable forward path.

### 5.2 NVA Prefix 172.16.0.0/24

Control plane path:

1. NVA advertises 172.16.0.0/24 to Route Server.
2. Route Server learns and propagates according to topology and policy.
3. Spokes can receive effective-route entries based on peering settings and route precedence interactions.

Data plane implication:

- Packets only flow if the final selected route points to a usable next hop and security policy allows traffic.

## 6. Spoke A vs Spoke B Behavior

### Spoke A (Transit Enabled)

Expected control plane:

- Receives intended remote routes through hub remote gateway or route server path.
- Effective route table shows active usable next hops for intended prefixes.

Expected data plane:

- Can complete connectivity tests to intended destinations, subject to NSG and guest firewall policy.

### Spoke B (Transit Disabled)

Expected control plane:

- Does not receive usable remote gateway transit path for branch prefixes.
- Effective route may show non-forwardable entries for certain prefixes.

Expected data plane:

- Fails connectivity tests to on-prem in the intended isolation scenario.

## 7. Route Precedence and Interpretation

When multiple routes exist, Azure route selection and precedence determine the final forwarding entry. In mixed gateway and Route Server scenarios:

- More specific prefixes generally win over less specific prefixes.
- Gateway-learned routes can take precedence in hybrid designs.
- Disabling propagate gateway routes at route table level changes route visibility behavior.

Interpretation rule:

- Do not infer forwarding from a learned-route list alone.
- Always verify effective routes on the destination NIC or subnet.

## 8. Troubleshooting Model: Control Plane First, Then Data Plane

Use this order for fast root-cause isolation.

### Step A: Verify control plane

Check:

- BGP peer state is Connected where expected.
- Expected prefixes are learned at gateway or Route Server.
- Effective route table on the VM NIC shows expected source, prefix, and next hop type.

If any of these fail, fix control plane first.

### Step B: Verify data plane

Check:

- NSG allows source and destination flows.
- Guest firewall allows the test protocol and port.
- Test with TCP reachability where ICMP is unreliable in command-run contexts.
- Confirm no asymmetric return path.

## 9. Quick Decision Matrix

| Observation | Plane | Typical Meaning | Next Action |
| --- | --- | --- | --- |
| BGP peer not connected | Control | Route exchange not established | Fix ASN, peer IP, tunnel binding |
| Prefix missing from learned routes | Control | Advertisement not reaching receiver | Validate advertisement source and policy |
| Prefix present but next hop non-usable | Control | Deliberate isolation or precedence outcome | Verify peering and transit flags |
| Effective route looks correct but connectivity fails | Data | Security or path realization issue | Check NSG, guest firewall, return path |
| Spoke A works, Spoke B fails to on-prem | Both | Expected policy outcome in this lab | Mark isolation test as pass |

## 10. Practical Takeaway

- Control plane answers: Should this traffic be possible?
- Data plane answers: Is this traffic actually flowing?

For this lab, success means both statements hold simultaneously:

1. Route propagation follows intended policy boundaries.
2. Packet forwarding outcomes match those boundaries.

Only when both are true can route leakage and isolation claims be trusted.

```bash
Step 0: Create Submission File
On your PC/host:

bash
echo "Lab 09 - bouw0026" > 09-bouw0026.txt
Step 1: Basic Device Setup
Apply base configurations to all devices (EDGE, CORE, ALS, VM, PC, TFTP Server).
(Use the provided basic.cfg or the commands below.)

EDGE Router
bash
enable
configure terminal
hostname bouw0026-EDGE
enable secret class
no ip domain-lookup
ip domain-name cnap.cst
username cisco privilege 15 secret cisco
crypto key generate rsa modulus 1024
ip ssh version 2
line vty 0 4
  transport input telnet ssh
  login local
exit
CORE Router
(Same as EDGE but hostname bouw0026-CORE)

ALS Switch
bash
enable
configure terminal
hostname bouw0026-ALS
enable secret class
no ip domain-lookup
ip domain-name lab.local
crypto key generate rsa modulus 1024
username admin privilege 15 secret cisco
line vty 0 4
  login local
  transport input ssh
exit
Step 2: Addressing Configuration
Follow the topology and addressing table:

EDGE: First usable IP in each subnet.

CORE: Last usable IP in transit links.

VM: Last usable in /28 subnet.

PC: First usable in /26 subnet.

ALS: Second-last usable in PC subnet.

EDGE Router Interfaces
bash
interface Gi0/0/0
  description EDGE-to-CORE
  ip address 198.18.14.1 255.255.255.252  # /30: 198.18.14.0/30
  no shutdown

interface Gi0/0/1
  description EDGE-to-REMOTE
  ip address 203.0.113.14 255.255.255.0   # /24: 203.0.113.0/24
  no shutdown

interface Gi0/0/2
  description EDGE-to-VM
  ip address 198.18.14.33 255.255.255.240 # /28: 198.18.14.32/28
  no shutdown
CORE Router Interfaces
bash
interface Gi0/0/0
  description CORE-to-EDGE
  ip address 198.18.14.2 255.255.255.252  # /30: 198.18.14.0/30
  ip ospf priority 14                      # Force CORE as DR
  no shutdown

interface Gi0/0/1
  description CORE-to-ALS
  ip address 198.18.14.190 255.255.255.192 # /26: 198.18.14.128/26
  no shutdown
ALS Switch Management
bash
interface Vlan1
  description Management SVI
  ip address 198.18.14.189 255.255.255.192 # /26: 198.18.14.128/26
  no shutdown
ip default-gateway 198.18.14.190           # CORE's Gi0/0/1
VM Host
bash
interface Gi0/0
  ip address 198.18.14.46 255.255.255.240  # /28: Last usable (46)
  no shutdown
ip default-gateway 198.18.14.33            # EDGE's Gi0/0/2
PC Host
bash
interface Gi0/0
  ip address 198.18.14.129 255.255.255.192 # /26: First usable (129)
  no shutdown
ip default-gateway 198.18.14.189           # ALS SVI
TFTP Server
bash
interface Gi0/0
  ip address 192.0.2.69 255.255.255.0       # Static IP
  no shutdown
ip default-gateway 203.0.113.1              # REMOTE gateway
Step 3: OSPF Routing Configuration
Process ID = 14

EDGE Router
bash
router ospf 14
  router-id 14.0.0.0
  network 198.18.14.0 0.0.0.3 area 0       # Transit link
  network 198.18.14.32 0.0.0.15 area 0      # VM subnet
  network 203.0.113.14 0.0.0.255 area 0     # REMOTE subnet
  passive-interface default                 # Only enable on active OSPF links
  no passive-interface Gi0/0/0
  no passive-interface Gi0/0/2
  default-information originate             # Advertise default route
CORE Router
bash
router ospf 14
  router-id 0.0.0.14
  network 198.18.14.0 0.0.0.3 area 0        # Transit link
  network 198.18.14.128 0.0.0.63 area 0      # PC subnet
  passive-interface default
  no passive-interface Gi0/0/0
  no passive-interface Gi0/0/1
Step 4: Pre-ACL Verification
Ensure OSPF and connectivity work BEFORE applying ACLs.

Check OSPF Neighbors (on EDGE & CORE):
bash
show ip ospf neighbor
Expected: EDGE sees CORE as FULL/DR, CORE sees EDGE as FULL/BDR.

Verify Router IDs
bash
show ip ospf
EDGE: Router ID 14.0.0.0

CORE: Router ID 0.0.0.14

Test End-to-End Reachability
From EDGE, CORE, and ALS:

bash
ping 198.18.14.129  # PC Host (should succeed)
ping 198.18.14.46   # VM Host (should succeed)
ping 203.0.113.254  # REMOTE Gateway (should succeed)
Fix issues NOW if pings fail!

Step 5: Implement ACL Policies
Policy 1: PROTECT-VM (EDGE Router)
Goal: Only PCs (198.18.14.128/26) can reach VMs.

bash
ip access-list standard PROTECT-VM
  permit 198.18.14.128 0.0.0.63 log  # PC subnet (wildcard 0.0.0.63 = /26)
  deny any log                        # Block all others & log
exit
interface Gi0/0/2
  ip access-group PROTECT-VM out      # Apply OUTBOUND to VM interface
  logging access-list                 # Enable logging for this ACL
Policy 2: PROTECT-PC (CORE Router)
Goal: Prevent IP spoofing of PC addresses.

bash
ip access-list standard PROTECT-PC
  deny 198.18.14.128 0.0.0.63 log    # Block spoofed PC-source IPs
  permit any log                      # Allow all others
exit
interface Gi0/0/0
  ip access-group PROTECT-PC in       # Apply INBOUND from EDGE
  logging access-list
Create spoof IP for testing:

bash
interface Loopback130
  ip address 198.18.14.130 255.255.255.255
Policy 3: PROTECT-ALS (ALS Switch)
Goal: Restrict SSH to PCs and TFTP server.

bash
ip access-list standard PROTECT-ALS
  permit 198.18.14.128 0.0.0.63      # PC subnet
  permit host 192.0.2.69              # TFTP server
  deny any log                        # Block all others & log
exit
interface Vlan1
  ip access-group PROTECT-ALS in      # Apply INBOUND to SVI
line vty 0 4
  access-class PROTECT-ALS in         # Apply to VTY lines
Step 6: Verification & Testing
Test PROTECT-VM (Policy 1)
Allowed: PC (198.18.14.129) → VM (198.18.14.46)

bash
PC> ping 198.18.14.46  # Should succeed
Blocked: CORE → VM

bash
CORE> ping 198.18.14.46              # Should fail
CORE> ping 198.18.14.46 source 198.18.14.190  # Should succeed (source IP in PC subnet)
Check Counters on EDGE:

bash
show ip access-lists PROTECT-VM  # Look for hits on permit/deny
show logging | include PROTECT-VM  # Check logs
Test PROTECT-PC (Policy 2)
Allowed: REMOTE (203.0.113.14) → PC (198.18.14.129)

bash
EDGE> ping 198.18.14.129 source 203.0.113.14  # Should succeed
Blocked: Spoofed IP (198.18.14.130) → PC

bash
EDGE> ping 198.18.14.129 source 198.18.14.130  # Should fail
Check Counters on CORE:

bash
show ip access-lists PROTECT-PC
Test PROTECT-ALS (Policy 3)
Allowed:

bash
PC> ssh admin@198.18.14.189        # Should succeed
TFTP> ssh admin@198.18.14.189      # Should succeed
Blocked:

bash
VM> ssh admin@198.18.14.189        # Should fail
Check Counters on ALS:

bash
show ip access-lists PROTECT-ALS
show running-config | section line vty  # Verify VTY binding
Step 7: Final Verification & Submission
Collect Outputs for 09-bouw0026.txt
CO1 (PROTECT-VM):

bash
EDGE# show ip access-lists PROTECT-VM
EDGE# show ip interface Gi0/0/2 | include PROTECT-VM
EDGE# show logging | include PROTECT-VM
CO2 (PROTECT-PC):

bash
CORE# show ip access-lists PROTECT-PC
CORE# show ip interface Gi0/0/0 | include PROTECT-PC
CO3 (PROTECT-ALS):

bash
ALS# show ip access-lists PROTECT-ALS
ALS# show ip interface Vlan1 | include PROTECT-ALS
ALS# show running-config | section line vty
Submit to TFTP Server
bash
# From PC or EDGE:
copy 09-bouw0026.txt tftp://192.0.2.69
copy running-config tftp://192.0.2.69/bouw0026-EDGE.cfg
copy running-config tftp://192.0.2.69/bouw0026-CORE.cfg
copy running-config tftp://192.0.2.69/bouw0026-ALS.cfg
Verify Submission
bash
ssh cisco@192.0.2.69
ls -l /var/tftp/*bouw0026*
Key Takeaways
ACL Placement:

Standard ACLs go close to destination (e.g., PROTECT-VM on EDGE’s outbound interface).

Anti-spoof ACLs go close to source (e.g., PROTECT-PC on CORE’s inbound interface).

Wildcard Masks:

/26 = 0.0.0.63

/28 = 0.0.0.15

Logging: Use log keyword + logging access-list for troubleshooting.

Testing:

Use source in ping for spoof tests.

Check ACL hits with show ip access-lists.

💡 Pro Tip: Always verify OSPF and basic connectivity BEFORE applying ACLs!
```

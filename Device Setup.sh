```bash
# =============================================
# Lab 09 - Network Setup & ACL Implementation
# Magic Number U = 14
# =============================================

# --- Initial Setup ---
# Create submission file
echo "Lab 09 - bouw0026" > 09-bouw0026.txt

# --- Configure EDGE Router ---
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

! Interfaces
interface Gi0/0/0
 description EDGE-to-CORE
 ip address 198.18.14.1 255.255.255.252
 no shutdown

interface Gi0/0/1
 description EDGE-to-REMOTE
 ip address 203.0.113.14 255.255.255.0
 no shutdown

interface Gi0/0/2
 description EDGE-to-VM
 ip address 198.18.14.33 255.255.255.240
 no shutdown

! OSPF Configuration
router ospf 14
 router-id 14.0.0.0
 network 198.18.14.0 0.0.0.3 area 0
 network 198.18.14.32 0.0.0.15 area 0
 network 203.0.113.14 0.0.0.255 area 0
 passive-interface default
 no passive-interface Gi0/0/0
 no passive-interface Gi0/0/2
 default-information originate
exit

! Policy 1: PROTECT-VM
ip access-list standard PROTECT-VM
 permit 198.18.14.128 0.0.0.63 log
 deny any log
exit
interface Gi0/0/2
 ip access-group PROTECT-VM out
 logging access-list
exit
write memory

# --- Configure CORE Router ---
enable
configure terminal
hostname bouw0026-CORE
enable secret class
no ip domain-lookup

! Interfaces
interface Gi0/0/0
 description CORE-to-EDGE
 ip address 198.18.14.2 255.255.255.252
 ip ospf priority 14
 no shutdown

interface Gi0/0/1
 description CORE-to-ALS
 ip address 198.18.14.190 255.255.255.192
 no shutdown

! OSPF Configuration
router ospf 14
 router-id 0.0.0.14
 network 198.18.14.0 0.0.0.3 area 0
 network 198.18.14.128 0.0.0.63 area 0
 passive-interface default
 no passive-interface Gi0/0/0
 no passive-interface Gi0/0/1
exit

! Policy 2: PROTECT-PC
ip access-list standard PROTECT-PC
 deny 198.18.14.128 0.0.0.63 log
 permit any log
exit
interface Gi0/0/0
 ip access-group PROTECT-PC in
 logging access-list
exit
interface Loopback130
 ip address 198.18.14.130 255.255.255.255
exit
write memory

# --- Configure ALS Switch ---
enable
configure terminal
hostname bouw0026-ALS
enable secret class
no ip domain-lookup

! Management Interface
interface Vlan1
 description Management SVI
 ip address 198.18.14.189 255.255.255.192
 no shutdown
exit
ip default-gateway 198.18.14.190

! SSH Configuration
ip domain-name lab.local
crypto key generate rsa modulus 1024
username admin privilege 15 secret cisco
line vty 0 4
 login local
 transport input ssh
exit

! Policy 3: PROTECT-ALS
ip access-list standard PROTECT-ALS
 permit 198.18.14.128 0.0.0.63
 permit host 192.0.2.69
 deny any log
exit
interface Vlan1
 ip access-group PROTECT-ALS in
exit
line vty 0 4
 access-class PROTECT-ALS in
exit
write memory

# --- Configure VM Host ---
enable
configure terminal
hostname VM
interface Gi0/0
 ip address 198.18.14.46 255.255.255.240
 no shutdown
ip default-gateway 198.18.14.33
exit
write memory

# --- Configure PC Host ---
enable
configure terminal
hostname PC
interface Gi0/0
 ip address 198.18.14.129 255.255.255.192
 no shutdown
ip default-gateway 198.18.14.189
exit
write memory

# --- Configure TFTP Server ---
enable
configure terminal
hostname TFTP-Server
interface Gi0/0
 ip address 192.0.2.69 255.255.255.0
 no shutdown
ip default-gateway 203.0.113.1
exit
write memory

# =============================================
# Verification Commands
# =============================================

# --- OSPF Verification ---
# On EDGE and CORE:
show ip ospf neighbor
show ip ospf
show ip ospf interface Gi0/0/0

# --- ACL Testing ---
# Clear counters
EDGE# clear access-list counters PROTECT-VM
CORE# clear access-list counters PROTECT-PC
ALS# clear access-list counters PROTECT-ALS

# Test PROTECT-VM (Policy 1)
PC# ping 198.18.14.46
CORE# ping 198.18.14.46
CORE# ping 198.18.14.46 source 198.18.14.190

# Test PROTECT-PC (Policy 2)
PC# ping 198.18.14.190
EDGE# ping 198.18.14.129 source 198.18.14.130
EDGE# ping 198.18.14.129 source 203.0.113.14

# Test PROTECT-ALS (Policy 3)
PC# ssh -l admin 198.18.14.189
VM# ssh -l admin 198.18.14.189

# --- Verification Output Collection ---
# On EDGE:
show ip access-lists PROTECT-VM >> tftp://192.0.2.69/09-bouw0026.txt
show ip interface Gi0/0/2 | include PROTECT-VM >> tftp://192.0.2.69/09-bouw0026.txt

# On CORE:
show ip access-lists PROTECT-PC >> tftp://192.0.2.69/09-bouw0026.txt
show ip interface Gi0/0/0 | include PROTECT-PC >> tftp://192.0.2.69/09-bouw0026.txt

# On ALS:
show ip access-lists PROTECT-ALS >> tftp://192.0.2.69/09-bouw0026.txt
show ip interface Vlan1 | include PROTECT-ALS >> tftp://192.0.2.69/09-bouw0026.txt
show running-config | section line vty >> tftp://192.0.2.69/09-bouw0026.txt

# --- Final Submission ---
copy running-config tftp://192.0.2.69/bouw0026-EDGE.cfg
copy running-config tftp://192.0.2.69/bouw0026-CORE.cfg
copy running-config tftp://192.0.2.69/bouw0026-ALS.cfg
copy 09-bouw0026.txt tftp://192.0.2.69
```

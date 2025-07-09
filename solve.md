# Lab 09 - Securing Networks with Standard ACLs: Step-by-Step Guide

## 🔭 Lab Overview & Learning Framework

This lab implements **three defense-in-depth security policies** using standard ACLs. We use a **Concept-Configuration-Verification (CCV)** framework for each policy:

1. **Concept** – Security principle & theory (with Chapter 7 references)
2. **Configuration** – Practical implementation commands
3. **Verification** – Validation techniques & screenshot rationale

> **Magic Number**: U=14  
> **Username**: bouw0026

---

## 🚀 Initial Network Setup

### 📚 Concept Foundation (Chapter 7 Reference)
> *"Editing ACLs requires careful planning. Cisco recommends disabling ACLs from interfaces before editing."*  
> — Chapter 7: ACL Implementation Considerations

### ⚙️ Configuration

```bash
# Create submission file
echo "Lab 09 - bouw0026" > 09-bouw0026.txt

# Basic device setup (EDGE Router example)
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
```

#### 🔍 Verification & Checkpoint

```bash
show running-config | include hostname|username|crypto
```

**Screenshot Importance:**
- Confirms device identity and secure access setup
- Validates SSH/Telnet availability for later ACL testing
- Shows compliance with baseline security standards

---

### 🌐 Addressing & OSPF Configuration

#### 📚 Concept Foundation (Chapter 7 Reference)
> *"Place standard ACLs as close as possible to the packet's destination."*  
> — Chapter 7: ACL Implementation Considerations

#### ⚙️ Configuration

```bash
# EDGE Addressing
interface Gi0/0/0
 ip address 198.18.14.1 255.255.255.252
 description EDGE-to-CORE
!
interface Gi0/0/2
 ip address 198.18.14.33 255.255.255.240
 description EDGE-to-VM

# OSPF Configuration (EDGE)
router ospf 14
 router-id 14.0.0.0
 passive-interface default
 no passive-interface Gi0/0/0
 default-information originate
```

#### 🔍 Verification & Checkpoint

```bash
show ip interface brief
show ip ospf neighbor
```

**Screenshot Importance:**
- Verifies layer 3 connectivity exists before ACL implementation
- Confirms OSPF adjacency forms (essential for later testing)
- Documents baseline network state for troubleshooting

---

## 🔒 Policy 1: PROTECT-VM Implementation

### 📚 Concept Foundation
> *"Standard ACLs filter only on source address. By placing them near the destination, you ensure only traffic headed for the protected subnet is tested."*  
> — Chapter 7: ACL Implementation Considerations

### ⚙️ Configuration

```bash
ip access-list standard PROTECT-VM
 permit 198.18.14.128 0.0.0.63 log   # PC subnet
 deny any log
!
interface Gi0/0/2
 ip access-group PROTECT-VM out
 logging access-list
```

#### 🔍 Verification & Checkpoint

```bash
show ip access-lists PROTECT-VM
show logging | include PROTECT-VM
```

**Screenshot Importance:**
- Hit Counters prove ACL is actively filtering traffic
- Log Entries show real-time policy enforcement
- Interface Binding confirms correct ACL placement

**💡 Knowledge Retention Boosters**
- **ACL Placement Diagram:** Sketch traffic flow showing why outbound on VM interface
- **Wildcard Calculator:** Quick-reference for `/26 = 0.0.0.63`
- **Scenario Testing:**
    - Why does `CORE# ping 198.18.14.46` fail?
    - Why does `CORE# ping 198.18.14.46 source 198.18.14.190` succeed?

---

## 🔒 Policy 2: PROTECT-PC Implementation

### 📚 Concept Foundation
> *"Extended ACLs allow you to match various header fields making them more powerful, but standard ACLs are sufficient for source-based filtering."*  
> — Chapter 7: Named and Extended IP ACLs introduction

### ⚙️ Configuration

```bash
# Create spoof-test interface
interface Loopback130
 ip address 198.18.14.130 255.255.255.255

# Anti-spoofing ACL
ip access-list standard PROTECT-PC
 deny 198.18.14.128 0.0.0.63 log
 permit any log
!
interface Gi0/0/0
 ip access-group PROTECT-PC in
```

#### 🔍 Verification & Checkpoint

```bash
ping 198.18.14.129 source 198.18.14.130  # Should FAIL
ping 198.18.14.129 source 203.0.113.14   # Should PASS
show access-lists PROTECT-PC
```

**Screenshot Importance:**
- Failed Ping demonstrates spoof protection working
- ACL Counters show deny/permit distribution
- Source Ping proves legitimate traffic flows

**💡 Knowledge Retention Boosters**
- **Spoofing Demonstration:**
    - Enable ACL logging
    - Attempt telnet from spoofed address
    - Analyze logs
- **ACL Editing Practice:**
    ```bash
    ip access-list standard PROTECT-PC
    no 10  # Remove first deny
    show access-lists  # Observe behavior change
    ```

---

## 🔒 Policy 3: PROTECT-ALS Implementation

### 📚 Concept Foundation
> *"Named ACLs used ACL configuration mode, making configuration clearer and easier to change over time."*  
> — Chapter 7: Named IP Access Lists

### ⚙️ Configuration

```bash
ip access-list standard PROTECT-ALS
 permit 198.18.14.128 0.0.0.63
 permit host 192.0.2.69
 deny any log
!
interface Vlan1
 ip access-group PROTECT-ALS in
line vty 0 4
 access-class PROTECT-ALS in
```

#### 🔍 Verification & Checkpoint

```bash
show run | section access-list PROTECT-ALS
show ip access-lists PROTECT-ALS
telnet 198.18.14.189  # From unauthorized host
```

**Screenshot Importance:**
- VTY Configuration shows management plane protection
- ACL Structure demonstrates permit/deny ordering
- Failed Telnet proves access control enforcement

**💡 Knowledge Retention Boosters**
- **ACL Editing Challenge:** Add new TFTP server `192.0.2.70`, verify with `show access-lists`
- **Troubleshooting Scenario:**  
    "Why can PC access switch but VM cannot?"  
    Trace path and verify ACL counters

---

## 📤 Final Verification & Submission

### 📚 Concept Foundation
> *"You can easily remove and add single ACEs using ACL mode."*  
> — Chapter 7: Editing Named ACLs

### ⚙️ Configuration

```bash
# Collect verification outputs
show access-lists >> tftp://192.0.2.69/09-bouw0026.txt

# Backup configurations
copy running-config tftp://192.0.2.69/bouw0026-EDGE.cfg
```

#### 🔍 Verification & Checkpoint

```bash
show file info tftp://192.0.2.69/09-bouw0026.txt
```

**Screenshot Importance:**
- Documents complete policy implementation
- Provides audit trail for all ACL configurations
- Shows successful integration with TFTP infrastructure

**💡 Knowledge Retention Boosters**
- **ACL Migration Exercise:** Convert PROTECT-VM to numbered ACL, compare configuration differences
- **Policy Expansion Scenario:**  
    "Add DHCP server to permitted ALS sources"  
    Implement and verify

---

## 📝 Key Instructional Enhancements

1. **CCV Framework** – Clearly separates theory, practice, and validation
2. **Screenshot Rationale** – Explains WHY each verification matters
3. **Retention Boosters** – Includes:
     - Diagramming exercises
     - Troubleshooting scenarios
     - Configuration challenges
     - Real-world simulation tasks
4. **Chapter 7 Integration** – Direct references to foundational concepts
5. **Progressive Complexity** – Starts with basic implementation, advances to editing/migration

---

### The lab emphasizes three crucial ACL principles from Chapter 7:

1. **Standard ACL placement near destination**
2. **Named ACL configuration benefits**
3. **The importance of verification through logging and counters**

Each section reinforces these through practical implementation followed by validation exercises that require analyzing ACL behavior.

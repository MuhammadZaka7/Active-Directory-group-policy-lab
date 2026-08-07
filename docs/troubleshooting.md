# Troubleshooting Notes

## 1. CLIENT01 received an APIPA address

### Symptom

`CLIENT01` received an address in the `169.254.x.x` range and could not contact the libvirt DHCP server.

### Investigation

The libvirt network was active and `dnsmasq` was listening on:

- `192.168.122.1:53` for DNS
- `virbr0:67` for DHCP

UFW was active on the Arch Linux host and was blocking traffic from the virtual bridge.

### Fix

Allowed DNS and DHCP inbound on `virbr0`:

```bash
sudo ufw allow in on virbr0 to any port 53 proto udp
sudo ufw allow in on virbr0 to any port 53 proto tcp
sudo ufw allow in on virbr0 to any port 67 proto udp
sudo ufw reload
```

Afterward, `CLIENT01` successfully received a DHCP lease from the libvirt network.

---

## 2. HTTPS traffic timed out from CLIENT01

### Symptom

ICMP and DNS worked, but:

```powershell
curl.exe -4 -I https://example.com
```

timed out.

### Cause

The UFW forward rule had been created against an invalid interface name:

```text
SWAN_IF
```

instead of the Arch host's real Wi-Fi interface:

```text
wlp0s20f3
```

### Fix

Removed the incorrect rule and created the proper forwarding rule:

```bash
sudo ufw route allow in on virbr0 out on wlp0s20f3 from 192.168.122.0/24
sudo ufw reload
```

HTTPS then returned a successful HTTP response.

---

## 3. Cross-host VM connectivity

`DC01` ran in VirtualBox on a MacBook Air while `CLIENT01` ran under KVM/libvirt on Arch Linux.

Because both VMs were behind separate NAT networks, Tailscale was installed on both machines to provide private routed connectivity.

The lab used:

```text
DC01      -> 100.73.177.5
CLIENT01  -> 100.110.139.5
```

Tailscale successfully carried traffic between the two hosts, including DNS, LDAP, SMB, and domain authentication.

---

## 4. Active Directory DNS lookup failures

### Symptom

The domain was created successfully, but the SRV lookup initially failed:

```powershell
Resolve-DnsName -Type SRV _ldap._tcp.dc._msdcs.zakalab.test
```

### Investigation

The AD-integrated zones existed, but DNS registration and client DNS configuration required adjustment.

### Fix

The Tailscale interface was configured to register in DNS while the unwanted adapter registration was disabled. The domain controller was configured to use itself for DNS, and Netlogon registration was forced.

```powershell
Restart-Service Netlogon
nltest /dsregdns
ipconfig /registerdns
```

The SRV query then returned the domain controller successfully.

---

## 5. CLIENT01 domain join issues

### Symptoms

Initial join attempts produced:

```text
The specified domain either does not exist or could not be contacted.
```

and later:

```text
The user name or password is incorrect.
```

### Resolution

DNS and AD service reachability were verified first. The join was then retried using explicit domain credentials:

```powershell
$cred = Get-Credential -UserName 'ZAKALAB\Administrator'
Add-Computer -DomainName 'zakalab.test' -Credential $cred -Restart -Verbose
```

After restart, `CLIENT01` successfully authenticated as a domain member.

---

## 6. Department drive mapping did not appear

### Initial design

A single GPO contained IT, HR, and Sales mappings using the same `S:` drive letter with item-level targeting.

The mappings used `Replace`, which complicated processing and troubleshooting.

### Final design

The configuration was simplified:

- One drive-mapping GPO per department OU
- `Action: Update`
- `S:` as the mapped drive
- GPO linked directly to the corresponding department OU
- Run in the logged-on user's security context
- No item-level targeting required

Example:

```text
ZakaLab - IT Drive Mapping
S: -> \\dc01.zakalab.test\Departments$\IT
```

The mapping then applied successfully.

---

## 7. Access-Based Enumeration behavior

When `it.user` attempted to access the HR department path, PowerShell returned that part of the path could not be found rather than a traditional Access Denied message.

This was expected because Access-Based Enumeration was enabled on the SMB share. Unauthorized folders were hidden from users who did not have access.

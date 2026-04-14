# Hypervisor Assault

Hypervisor discovery and hypervisor-specific enumeration for educational use and authorized security testing only.

## Legal Disclaimer
Educational purposes and authorized testing only. Scan only systems you own or where you have explicit written permission.

## What It Does (High Level)
- Interactive menu to scan a single target or a target list file, view results, or quit
- For each target:
  - Discovery phase: port reachability checks, HTTP(S) header/banner checks, SSL certificate inspection, web path probing, basic version fingerprinting (when possible)
  - If a hypervisor is detected with sufficient confidence: runs hypervisor-family-specific enumeration using targeted `nmap` + `curl` checks
  - Otherwise: runs a generic hypervisor-port `nmap` scan + OS detection hints
- Writes a human-readable report with:
  - What scans were performed
  - What was found (hypervisor type, confidence, evidence)

## Important: VMware Guest vs VMware Hypervisor
- A normal VM running inside VMware Workstation/Fusion usually looks like a regular Windows/Linux host on the network.
- This project primarily detects exposed hypervisor or management services such as ESXi, vCenter, Proxmox, Hyper-V, and similar platforms.
- If you scan a guest VM that only exposes ports like `22`, `80`, or `3389`, the tool may show little or no hypervisor-specific evidence because the guest is not itself the hypervisor.
- To get results, make sure the VM is reachable on the network and that you are scanning the guest's actual IP address or an ESXi/vCenter management IP, depending on what you want to test.

## Quick Start
```bash
cd hypervisor-assault
chmod +x hypervisor-assault.sh
sudo ./hypervisor-assault.sh
```

Menu options:
1. Scan Single IP
2. Scan IP File
3. View Results
4. Quit

## Target File Format
One target per line. Comments are allowed with `#`.

Example:
```text
192.168.1.10
10.10.10.0/24
example.com
192.168.1.1-50
```

## Output
- Main report (created in the current directory): `hypervisor_scan_YYYYMMDD_HHMMSS.txt`
- Temporary artifacts (created in the current directory, per target): `<target>_headers.txt`, `<target>_cert.txt`

## Scripts In This Repo
- `hypervisor-assault.sh`: main interactive scanner (menu + report)
- `scripts/hypervisor-assault.sh`: lightweight discovery/fingerprinting variant

## Dependencies (For `hypervisor-assault.sh`)
- Core: `nmap`, `curl`, `dig`, `nc`, `openssl`, `timeout` (coreutils)
- Optional (used by some checks): `jq`

## License
MIT (see `LICENSE`).

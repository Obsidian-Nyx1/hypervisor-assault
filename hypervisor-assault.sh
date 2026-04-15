#!/bin/bash

# =============================================================================
# HYPERVISOR ASSAULT - HYPERVISOR-SPECIFIC ULTIMATE SCANNER
# "Find ANY hypervisor, then DESTROY it with targeted scans"
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# =============================================================================
# HYPERVISOR SIGNATURES DATABASE
# =============================================================================

declare -A HYPERVISOR_PORTS=(
    # VMware
    ["VMware ESXi"]="443,902,903,548,5989,80,427,8307"
    ["VMware vCenter"]="443,548,8080,8443,9443,8090"
    ["VMware Horizon"]="443,8443,4172,3389"
    
    # Microsoft
    ["Hyper-V"]="80,443,5985,5986,2179,3389,445,139"
    ["SCVMM"]="443,5986,8100"
    ["Azure Stack"]="443,8443,13007"
    
    # KVM Family
    ["KVM/QEMU"]="22,16509,5900,5901,49152,16514"
    ["Proxmox VE"]="8006,22,111,3128,85,86,5900-5999"
    ["oVirt/RHEV"]="443,8443,5432,8080,8700"
    ["OpenStack"]="8774,8776,8778,9292,9696,5000"
    
    # Xen Family
    ["XenServer/XCP-ng"]="22,80,443,5900,5901"
    ["Citrix XenApp"]="80,443,1494,2598,8080"
    
    # Others
    ["Nutanix"]="443,9440,2020,2030,111,2049"
    ["Oracle VM"]="443,5432,8080,8899"
    ["VirtualBox"]="18083,3389,22"
    ["Docker"]="2375,2376,3375"
    ["Kubernetes"]="6443,10250,10251,10252,10255"
    ["Red Hat Virtualization"]="443,8443,9090"
    ["HPE OneView"]="443,8443"
    ["Cisco UCS"]="443,8080,8443"
)

declare -A HYPERVISOR_PATHS=(
    # VMware
    ["VMware ESXi"]="/ui /host /folder /screen /vmfs"
    ["VMware vCenter"]="/ui /vsphere-client /vcenter /appliance"
    
    # Microsoft
    ["Hyper-V"]="/wsman /cimom /wmiv2 /rdweb"
    
    # Proxmox
    ["Proxmox VE"]="/pve /proxmox /api2/json /novnc"
    
    # oVirt/RHEV
    ["oVirt"]="/ovirt-engine /webadmin /api"
    
    # Xen
    ["XenServer"]="/XenCenter /xapi /cli"
    
    # Nutanix
    ["Nutanix"]="/prism /console /api/nutanix"
)

declare -A HYPERVISOR_CVES=(
    # VMware CVEs
    ["VMware ESXi"]="CVE-2021-21985 CVE-2021-22005 CVE-2020-3992 CVE-2019-5544 CVE-2018-6981"
    ["VMware vCenter"]="CVE-2021-21985 CVE-2021-22005 CVE-2022-22948 CVE-2021-21980"
    
    # Hyper-V CVEs
    ["Hyper-V"]="CVE-2023-24903 CVE-2021-28476 CVE-2020-1701 CVE-2019-0720"
    
    # Proxmox CVEs
    ["Proxmox VE"]="CVE-2023-23397 CVE-2022-3234 CVE-2021-3653"
    
    # KVM CVEs
    ["KVM/QEMU"]="CVE-2023-0664 CVE-2022-0216 CVE-2021-20255"
    
    # Xen CVEs
    ["XenServer"]="CVE-2022-42325 CVE-2021-28694 CVE-2020-15565"
    
    # Nutanix CVEs
    ["Nutanix"]="CVE-2023-28979 CVE-2022-3033"
)

declare -A HYPERVISOR_DEFAULT_CREDS=(
    ["VMware ESXi"]="root:root, root:password, admin:admin, root:vmware"
    ["VMware vCenter"]="administrator@vsphere.local:admin, root:vmware"
    ["Hyper-V"]="Administrator:password, Administrator:12345"
    ["Proxmox VE"]="root:root, root:proxmox, admin:admin"
    ["XenServer"]="root:root, admin:admin, xen:xen"
    ["Nutanix"]="admin:admin, nutanix:nutanix"
    ["oVirt"]="admin@internal:admin, root:root"
)

declare -A HYPERVISOR_BANNERS=(
    ["VMware ESXi"]="VMware ESXi|VMware vSphere|ESXi"
    ["VMware vCenter"]="VMware vCenter|VirtualCenter"
    ["Hyper-V"]="Microsoft-HTTPAPI|Hyper-V|Windows Hyper-V"
    ["Proxmox VE"]="Proxmox|PVE|pve-api"
    ["KVM/QEMU"]="QEMU|KVM|libvirt"
    ["XenServer"]="Xen|XCP|Citrix"
    ["Nutanix"]="Nutanix|Prism"
    ["oVirt"]="oVirt|RHEV|rhevm"
)

GUEST_VM_PORTS="22 80 443 445 3389 21 25 53 110 143 993 995 1433 1521 3306 5432 6379 8080 8443"
HYPERVISOR_MGMT_PORTS="80 111 139 443 445 548 902 903 2179 2375 2376 3128 4172 427 5000 5432 5900 5901 5985 5986 6443 8006 8080 8090 8100 8443 8700 8774 8776 8778 8899 9090 9440 9443 9696 10250 13007 16509 16514 18083 2020 2030"
COMMON_HOST_PORTS="21,22,25,53,80,110,111,123,135,139,143,389,443,445,465,587,993,995,1433,1521,2049,2375,2376,3128,3306,3389,4172,5000,5432,5900-5910,5985,5986,6379,6443,8006,8080,8090,8100,8443,8700,8774,8776,8778,8899,9090,9440,9443,9696,10250,13007,16509,16514,18083,2020,2030"

# =============================================================================
# PRINT BANNER
# =============================================================================

print_banner() {
    clear
    echo -e "${RED}${BOLD}"
    cat << "EOF"
    ██╗  ██╗██╗   ██╗██████╗ ███████╗██████╗ ██╗   ██╗██╗███████╗ ██████╗ ██████╗ 
    ██║  ██║╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗██║   ██║██║██╔════╝██╔═══██╗██╔══██╗
    ███████║ ╚████╔╝ ██████╔╝█████╗  ██████╔╝██║   ██║██║███████╗██║   ██║██████╔╝
    ██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══╝  ██╔══██╗╚██╗ ██╔╝██║╚════██║██║   ██║██╔══██╗
    ██║  ██║   ██║   ██║     ███████╗██║  ██║ ╚████╔╝ ██║███████║╚██████╔╝██║  ██║
    ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝
EOF
    echo -e "${NC}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║              HYPERVISOR-SPECIFIC ULTIMATE SCANNER               ║"
    echo "║                    Find → Identify → Destroy                    ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
}

# =============================================================================
# CHECK DEPENDENCIES
# =============================================================================

check_deps() {
    local deps=("nmap" "masscan" "curl" "wget" "dig" "nc" "python3" "hydra" "whatweb" "jq" "gcc")
    local missing=()
    
    echo -e "${YELLOW}[*] Checking dependencies...${NC}"
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}[!] Missing: ${missing[*]}${NC}"
        echo -e "${YELLOW}[*] Installing...${NC}"
        sudo apt update && sudo apt install -y "${missing[@]}" 2>/dev/null
    else
        echo -e "${GREEN}[+] All dependencies satisfied${NC}"
    fi
}

# =============================================================================
# HYPERVISOR DISCOVERY FUNCTION
# =============================================================================

discover_hypervisor() {
    local target="$1"
    local output_file="$2"
    local detected_hv=""
    local confidence=0
    local -a scans_performed=()
    local -a ev_open_ports=()
    local -a ev_banners=()
    local -a ev_certs=()
    local -a ev_paths=()
    local -a ev_versions=()
    
    echo -e "\n${PURPLE}[🔍] Hypervisor Discovery on $target${NC}" >&2
    
    {
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════"
        echo "HYPERVISOR DISCOVERY PHASE"
        echo "═══════════════════════════════════════════════════════════════════════"
    } >> "$output_file"
    
    # Method 1: Port-based detection
    scans_performed+=("Port-based detection (nc connect checks)")
    echo -e "${CYAN}  ├─[1/5] Checking hypervisor-specific ports...${NC}" >&2
    {
        echo ""
        echo "--- Port-Based Detection ---"
    } >> "$output_file"
    
    for hv_name in "${!HYPERVISOR_PORTS[@]}"; do
        ports="${HYPERVISOR_PORTS[$hv_name]}"
        IFS=',' read -ra port_array <<< "$ports"
        
        for port in "${port_array[@]}"; do
            port=$(echo "$port" | tr -d ' ')
            timeout 2 nc -zv "$target" "$port" 2>&1 | grep -q succeeded
            if [ $? -eq 0 ]; then
                echo "  ✓ $hv_name: Port $port is OPEN" >> "$output_file"
                ev_open_ports+=("$port/tcp")
                detected_hv="$hv_name"
                ((confidence+=20))
            fi
        done
    done
    
    # Method 2: Banner grabbing
    scans_performed+=("HTTP(S) header/banner grabbing (curl)")
    echo -e "${CYAN}  ├─[2/5] Grabbing banners and headers...${NC}" >&2
    {
        echo ""
        echo "--- Banner Grabbing ---"
    } >> "$output_file"
    
    for port in 80 443 8080 8443 9443 8006; do
        timeout 5 curl -sk "https://$target:$port" -I 2>/dev/null | head -20 > "${target}_headers.txt"
        timeout 5 curl -sk "http://$target:$port" -I 2>/dev/null | head -20 >> "${target}_headers.txt"
        
        if [ -s "${target}_headers.txt" ]; then
            for hv_name in "${!HYPERVISOR_BANNERS[@]}"; do
                pattern="${HYPERVISOR_BANNERS[$hv_name]}"
                if grep -Eiq "$pattern" "${target}_headers.txt"; then
                    echo "  ✓ $hv_name detected via banner" >> "$output_file"
                    ev_banners+=("$hv_name (port $port)")
                    detected_hv="$hv_name"
                    ((confidence+=30))
                fi
            done
            cat "${target}_headers.txt" >> "$output_file" 2>/dev/null
        fi
    done
    
    # Method 3: SSL Certificate inspection
    scans_performed+=("SSL certificate inspection (openssl x509)")
    echo -e "${CYAN}  ├─[3/5] Inspecting SSL certificates...${NC}" >&2
    {
        echo ""
        echo "--- SSL Certificate Analysis ---"
    } >> "$output_file"
    
    for port in 443 8443 9443 8006; do
        timeout 5 openssl s_client -connect "$target:$port" 2>/dev/null | openssl x509 -text 2>/dev/null > "${target}_cert.txt"
        if [ -s "${target}_cert.txt" ]; then
            if grep -qi "vmware" "${target}_cert.txt"; then
                echo "  ✓ VMware detected in SSL certificate" >> "$output_file"
                ev_certs+=("vmware keyword (port $port)")
                detected_hv="VMware"
                ((confidence+=25))
            elif grep -qi "microsoft" "${target}_cert.txt"; then
                echo "  ✓ Microsoft/Hyper-V detected in SSL certificate" >> "$output_file"
                ev_certs+=("microsoft keyword (port $port)")
                detected_hv="Hyper-V"
                ((confidence+=25))
            elif grep -qi "proxmox" "${target}_cert.txt"; then
                echo "  ✓ Proxmox detected in SSL certificate" >> "$output_file"
                ev_certs+=("proxmox keyword (port $port)")
                detected_hv="Proxmox VE"
                ((confidence+=25))
            fi
            cat "${target}_cert.txt" | grep -E "Subject:|Issuer:|Not Before|Not After" >> "$output_file"
        fi
    done
    
    # Method 4: Web path probing
    scans_performed+=("Web path probing (curl status checks)")
    echo -e "${CYAN}  ├─[4/5] Probing hypervisor web paths...${NC}" >&2
    {
        echo ""
        echo "--- Web Path Probing ---"
    } >> "$output_file"
    
    for hv_name in "${!HYPERVISOR_PATHS[@]}"; do
        paths="${HYPERVISOR_PATHS[$hv_name]}"
        for path in $paths; do
            for port in 80 443 8080 8443 9443 8006; do
                status=$(timeout 3 curl -sk -o /dev/null -w "%{http_code}" "https://$target:$port$path" 2>/dev/null)
                if [ "$status" = "200" ] || [ "$status" = "401" ] || [ "$status" = "302" ]; then
                    echo "  ✓ Found $hv_name path: $path (HTTP $status)" >> "$output_file"
                    ev_paths+=("$hv_name $path (port $port, HTTP $status)")
                    detected_hv="$hv_name"
                    ((confidence+=15))
                fi
            done
        done
    done
    
    # Method 5: Version fingerprinting
    if [ -n "$detected_hv" ]; then
        scans_performed+=("Version fingerprinting (service/API queries)")
        echo -e "${CYAN}  └─[5/5] Fingerprinting exact version...${NC}" >&2
        {
            echo ""
            echo "--- Version Fingerprinting ---"
        } >> "$output_file"
        
        case "$detected_hv" in
            *VMware*)
                # VMware version detection
                for port in 443 902 903; do
                    ver=$(timeout 5 curl -sk "https://$target:$port" | grep -Eo 'VMware ESXi [0-9]+\.[0-9]+\.[0-9]+|vCenter Server [0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
                    if [ -n "${ver:-}" ]; then
                        echo "$ver" >> "$output_file"
                        ev_versions+=("$ver (port $port)")
                    fi
                done
                ;;
            *Hyper-V*)
                # Hyper-V version detection
                srv=$(timeout 5 curl -sk "https://$target:5986" -I | grep -i "server" | head -n 1)
                [ -n "${srv:-}" ] && { echo "$srv" >> "$output_file"; ev_versions+=("WinRM HTTPS: $srv"); }
                srv=$(timeout 5 curl -sk "http://$target:5985" -I | grep -i "server" | head -n 1)
                [ -n "${srv:-}" ] && { echo "$srv" >> "$output_file"; ev_versions+=("WinRM HTTP: $srv"); }
                ;;
            *Proxmox*)
                # Proxmox version detection
                ev_versions+=("Proxmox API: /api2/json/nodes (port 8006)")
                timeout 5 curl -sk "https://$target:8006/api2/json/nodes" | jq . 2>/dev/null >> "$output_file"
                timeout 5 curl -sk "http://$target:8006" | grep -i "proxmox" >> "$output_file"
                ;;
            *Xen*)
                # Xen version detection
                ev_versions+=("Xen keyword check (HTTPS root)")
                timeout 5 curl -sk "https://$target" | grep -i "xen" >> "$output_file"
                ;;
            *Nutanix*)
                # Nutanix version detection
                ev_versions+=("Nutanix Prism API probe (port 9440)")
                timeout 5 curl -sk "https://$target:9440/PrismGateway/services/rest/v1/vms" | jq . 2>/dev/null >> "$output_file"
                ;;
        esac
    fi
    
    echo -e "${GREEN}  └─✓ Detection complete. Confidence: $confidence%${NC}" >&2

    {
        echo ""
        echo "=== DISCOVERY SUMMARY ==="
        echo "Scans performed:"
        for s in "${scans_performed[@]}"; do
            echo "  - $s"
        done
        echo ""
        echo "Findings:"
        echo "  - Detected hypervisor: ${detected_hv:-None}"
        echo "  - Confidence: ${confidence}%"
        if [ ${#ev_open_ports[@]} -gt 0 ]; then
            echo "  - Open ports observed: ${ev_open_ports[*]}"
        fi
        if [ ${#ev_banners[@]} -gt 0 ]; then
            echo "  - Banner matches: ${ev_banners[*]}"
        fi
        if [ ${#ev_certs[@]} -gt 0 ]; then
            echo "  - Certificate indicators: ${ev_certs[*]}"
        fi
        if [ ${#ev_paths[@]} -gt 0 ]; then
            echo "  - Web path hits:"
            for p in "${ev_paths[@]}"; do
                echo "    * $p"
            done
        fi
        if [ ${#ev_versions[@]} -gt 0 ]; then
            echo "  - Version evidence:"
            for v in "${ev_versions[@]}"; do
                echo "    * $v"
            done
        fi
        echo "========================="
        echo ""
    } >> "$output_file"
    
    # Return detected hypervisor
    echo "$detected_hv:$confidence"
}

classify_target_role() {
    local target="$1"
    local hv_type="$2"
    local confidence="$3"
    local output_file="$4"
    local mgmt_hits=0
    local guest_hits=0
    local guest_ports_hit=""
    local mgmt_ports_hit=""
    local path_hits=0
    local role="Inconclusive"
    local rationale=""
    local top_risk_layer="Unknown"

    echo -e "${CYAN}  ├─ Assessing whether $target is a hypervisor host, management plane, or guest VM...${NC}" >&2

    for port in $HYPERVISOR_MGMT_PORTS; do
        if timeout 2 nc -z "$target" "$port" >/dev/null 2>&1; then
            ((mgmt_hits+=1))
            mgmt_ports_hit+="${port}/tcp "
        fi
    done

    for port in $GUEST_VM_PORTS; do
        if timeout 2 nc -z "$target" "$port" >/dev/null 2>&1; then
            ((guest_hits+=1))
            guest_ports_hit+="${port}/tcp "
        fi
    done

    for scheme in https http; do
        for port in 80 443 8006 8443 9443; do
            for path in /ui /vsphere-client /sdk /api2/json /xapi /ovirt-engine /prism /wsman; do
                status=$(timeout 3 curl -sk -o /dev/null -w "%{http_code}" "${scheme}://$target:$port$path" 2>/dev/null)
                if [ "$status" = "200" ] || [ "$status" = "401" ] || [ "$status" = "302" ]; then
                    ((path_hits+=1))
                fi
            done
        done
    done

    if [ -n "$hv_type" ] && [ "${confidence:-0}" -ge 45 ] && { [ "$mgmt_hits" -ge 2 ] || [ "$path_hits" -ge 1 ]; }; then
        role="Likely hypervisor host or management plane"
        top_risk_layer="Hypervisor layer"
        rationale="Strong hypervisor fingerprints plus exposed management services/UI paths."
    elif [ -n "$hv_type" ] && [[ "$hv_type" == *"vCenter"* || "$hv_type" == *"SCVMM"* || "$hv_type" == *"OpenStack"* || "$hv_type" == *"Nutanix"* || "$hv_type" == *"OneView"* || "$hv_type" == *"UCS"* ]]; then
        role="Likely hypervisor management plane"
        top_risk_layer="Hypervisor layer"
        rationale="Control-plane product detected; compromise would affect multiple guest systems."
    elif [ -z "$hv_type" ] && [ "$guest_hits" -ge 1 ] && [ "$mgmt_hits" -le 1 ]; then
        role="Likely guest VM or general-purpose host"
        top_risk_layer="Guest layer"
        rationale="Reachable host with guest-style services and no strong hypervisor management indicators."
    elif [ -z "$hv_type" ] && [ "$guest_hits" -ge 1 ] && [ "$mgmt_hits" -ge 1 ]; then
        role="Likely virtualized host or mixed-purpose system"
        top_risk_layer="Guest layer"
        rationale="The target exposes both workload services and some management-like ports, but not enough evidence to call it a hypervisor."
    elif [ -n "$hv_type" ] && [ "${confidence:-0}" -lt 45 ] && [ "$guest_hits" -ge "$mgmt_hits" ]; then
        role="Possibly guest VM with virtualization artifacts"
        top_risk_layer="Guest layer"
        rationale="Some virtualization hints exist, but the exposed surface looks more like a workload than a hypervisor."
    else
        role="Inconclusive"
        top_risk_layer="Needs verification"
        rationale="The exposed services do not clearly separate hypervisor management from guest workload behavior."
    fi

    {
        echo ""
        echo "=== TARGET ROLE ASSESSMENT ==="
        echo "Question answered: Is this IP a hypervisor host or a guest VM?"
        echo "  - Classification: $role"
        echo "  - Primary risk layer: $top_risk_layer"
        echo "  - Rationale: $rationale"
        if [ -n "$mgmt_ports_hit" ]; then
            echo "  - Hypervisor/management ports observed: ${mgmt_ports_hit% }"
        fi
        if [ -n "$guest_ports_hit" ]; then
            echo "  - Guest/workload ports observed: ${guest_ports_hit% }"
        fi
        echo "  - Management/UI path hits: $path_hits"
        echo "=============================="
        echo ""
    } >> "$output_file"

    echo "$role|$top_risk_layer|$rationale"
}

write_risk_layer_summary() {
    local target="$1"
    local role="$2"
    local hv_type="$3"
    local confidence="$4"
    local output_file="$5"

    {
        echo ""
        echo "=== RISK LAYER SUMMARY ==="
        echo "Question answered: Where do the risks lie?"
        echo "  - Hypervisor layer risk: The hypervisor or its management plane is a shared control boundary; compromise can cascade across multiple guest VMs."
        echo "  - Guest layer risk: Each guest VM remains its own attack surface through OS, middleware, and application exposure."

        case "$role" in
            "Likely hypervisor host or management plane"|"Likely hypervisor management plane")
                echo "  - Assessment for $target: prioritize hypervisor-layer hardening first."
                echo "  - Focus areas: exposed management ports, web consoles/APIs, remote admin protocols, patch level, MFA, segmentation, and least privilege."
                [ -n "$hv_type" ] && echo "  - Product context: detected ${hv_type} at ${confidence}% confidence."
                ;;
            "Likely guest VM or general-purpose host"|"Possibly guest VM with virtualization artifacts")
                echo "  - Assessment for $target: prioritize guest-layer review first."
                echo "  - Focus areas: OS patching, service exposure, application vulnerabilities, credential hygiene, EDR/logging, and lateral movement controls."
                echo "  - Hypervisor risk still matters, but this IP does not currently look like the shared management boundary."
                ;;
            *)
                echo "  - Assessment for $target: evidence is mixed, so review both layers."
                echo "  - Next checks: validate ownership of the IP, correlate with CMDB/virtualization inventory, and compare observed ports against expected management interfaces."
                ;;
        esac

        echo "=========================="
        echo ""
    } >> "$output_file"
}

# =============================================================================
# GUEST / GENERAL HOST SCAN
# =============================================================================

generic_host_scan() {
    local target="$1"
    local output_file="$2"
    local target_role="$3"

    echo -e "${YELLOW}[!] No strong hypervisor match. Running guest/general-host scan...${NC}"

    {
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════"
        echo "GUEST / GENERAL HOST SCAN"
        echo "═══════════════════════════════════════════════════════════════════════"
        echo "Scans performed:"
        echo "  - nmap -sV --version-all (common guest + management ports)"
        echo "  - nmap -O (OS detection hints)"
        echo "  - HTTP(S) header checks on common web ports"
        echo "  - Guest-vs-management interpretation using exposed services"
        echo ""
        echo "Role-guided interpretation:"
        echo "  - Current classification: ${target_role:-Inconclusive}"
        echo ""
        echo "--- Service Scan ---"
        nmap -p "$COMMON_HOST_PORTS" -sV --version-all "$target" -oN - 2>/dev/null
        echo ""
        echo "--- Operating System Hints ---"
        nmap -O "$target" -oN - 2>/dev/null | grep -E "OS details|Running|OS guess|Device type"
        echo ""
        echo "--- Web Headers ---"
        for port in 80 443 8080 8443 8006 9443; do
            echo "[Port $port]"
            curl -sk "https://$target:$port" -I 2>/dev/null | head -5
            curl -sk "http://$target:$port" -I 2>/dev/null | head -5
        done
    } >> "$output_file" 2>/dev/null
}

# =============================================================================
# HYPERVISOR-SPECIFIC DEEP SCAN
# =============================================================================

deep_hypervisor_scan() {
    local target="$1"
    local hv_type="$2"
    local output_file="$3"
    
    echo -e "\n${RED}[💀] Launching HYPERVISOR-SPECIFIC deep scan for: $hv_type${NC}"
    
    {
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════"
        echo "HYPERVISOR-SPECIFIC DEEP SCAN: $hv_type"
        echo "═══════════════════════════════════════════════════════════════════════"
        echo "Scans performed (high level):"
        echo "  - Targeted nmap service/version scans on hypervisor-related ports"
        echo "  - Targeted HTTP(S) path/header checks for management UIs/APIs"
        echo "  - Additional enumeration depending on detected hypervisor family"
    } >> "$output_file"
    
    case "$hv_type" in
        *VMware*)
            echo -e "${YELLOW}  ├─ Scanning VMware-specific vectors...${NC}"
            {
                echo ""
                echo "=== VMWARE DEEP SCAN ==="
                echo "Scans performed:"
                echo "  - nmap -sV --version-all (VMware ports)"
                echo "  - HTTP(S) UI path checks (/ui, /vsphere-client, /vcenter, etc.)"
                echo "  - nmap --script vmware-version (where available)"
                echo ""
                
                # VMware port scan
                echo "--- VMware Service Scan ---"
                nmap -p 443,902,903,548,5989,427,8307 -sV --version-all "$target" -oN - 2>/dev/null
                
                # vCenter specific
                echo "--- vCenter Detection ---"
                for path in "/ui" "/vsphere-client" "/vcenter" "/folder" "/host" "/datastore"; do
                    curl -sk "https://$target:443$path" -I 2>/dev/null | head -1
                done
                
                # VMware vulnerabilities
                echo "--- Known VMware Vulnerabilities ---"
                echo "Check these CVEs: ${HYPERVISOR_CVES[$hv_type]}"
                
                # VMware version
                echo "--- Version Information ---"
                curl -sk "https://$target/sdk" 2>/dev/null | grep -Eo 'version="[^"]+"'
                curl -sk "https://$target:902/sdk" 2>/dev/null | grep -Eo 'version="[^"]+"'
                
                # VMware services
                echo "--- Running Services ---"
                nmap -p 443,902,903 --script vmware-version "$target" -oN - 2>/dev/null
                
                # Check for default creds
                echo "--- Default Credentials Check ---"
                echo "Try: ${HYPERVISOR_DEFAULT_CREDS[$hv_type]}"
            } >> "$output_file" 2>/dev/null
            ;;
            
        *Hyper-V*)
            echo -e "${YELLOW}  ├─ Scanning Hyper-V-specific vectors...${NC}"
            {
                echo ""
                echo "=== HYPER-V DEEP SCAN ==="
                echo "Scans performed:"
                echo "  - nmap -sV --version-all (WinRM/SMB/RDP ports)"
                echo "  - nmap winrm-* scripts (where available)"
                echo "  - nmap smb-* scripts (where available)"
                echo "  - nmap rdp-* scripts (where available)"
                echo ""
                
                # Hyper-V port scan
                echo "--- Hyper-V Service Scan ---"
                nmap -p 80,443,5985,5986,2179,3389,445 -sV --version-all "$target" -oN - 2>/dev/null
                
                # WinRM enumeration
                echo "--- WinRM Enumeration ---"
                nmap -p 5985,5986 --script winrm-* "$target" -oN - 2>/dev/null
                
                # SMB enumeration
                echo "--- SMB Enumeration ---"
                nmap -p 445 --script smb-* "$target" -oN - 2>/dev/null
                
                # RDP check
                echo "--- RDP Check ---"
                nmap -p 3389 --script rdp-* "$target" -oN - 2>/dev/null
                
                # Hyper-V vulnerabilities
                echo "--- Known Hyper-V Vulnerabilities ---"
                echo "Check these CVEs: ${HYPERVISOR_CVES[$hv_type]}"
                
                # Windows version detection
                echo "--- OS Version ---"
                nmap -O "$target" -oN - 2>/dev/null | grep -i "windows"
                
                # Check for default creds
                echo "--- Default Credentials Check ---"
                echo "Try: ${HYPERVISOR_DEFAULT_CREDS[$hv_type]}"
            } >> "$output_file" 2>/dev/null
            ;;
            
        *Proxmox*)
            echo -e "${YELLOW}  ├─ Scanning Proxmox-specific vectors...${NC}"
            {
                echo ""
                echo "=== PROXMOX DEEP SCAN ==="
                echo "Scans performed:"
                echo "  - nmap -sV --version-all (Proxmox ports)"
                echo "  - Proxmox API enumeration requests"
                echo "  - Proxmox UI version string checks"
                echo ""
                
                # Proxmox port scan
                echo "--- Proxmox Service Scan ---"
                nmap -p 8006,22,111,3128,85,86,5900-5999 -sV --version-all "$target" -oN - 2>/dev/null
                
                # Proxmox API enumeration
                echo "--- Proxmox API Enumeration ---"
                for endpoint in "/api2/json/nodes" "/api2/json/storage" "/api2/json/cluster" "/pve"; do
                    curl -sk "https://$target:8006$endpoint" -H "Authorization: PVEAPIToken=root@pam!token=00000000-0000-0000-0000-000000000000" 2>/dev/null | jq . 2>/dev/null
                done
                
                # Proxmox vulnerabilities
                echo "--- Known Proxmox Vulnerabilities ---"
                echo "Check these CVEs: ${HYPERVISOR_CVES[$hv_type]}"
                
                # Proxmox version
                echo "--- Version Information ---"
                curl -sk "https://$target:8006" | grep -i "proxmox"
                
                # Check for default creds
                echo "--- Default Credentials Check ---"
                echo "Try: ${HYPERVISOR_DEFAULT_CREDS[$hv_type]}"
            } >> "$output_file" 2>/dev/null
            ;;
            
        *KVM*|*QEMU*)
            echo -e "${YELLOW}  ├─ Scanning KVM/QEMU-specific vectors...${NC}"
            {
                echo ""
                echo "=== KVM/QEMU DEEP SCAN ==="
                echo "Scans performed:"
                echo "  - nmap -sV --version-all (libvirt/VNC ports)"
                echo "  - nmap libvirt-* scripts (where available)"
                echo "  - VNC port reachability checks (nc)"
                echo ""
                
                # KVM port scan
                echo "--- KVM Service Scan ---"
                nmap -p 22,16509,5900-5910,49152,16514 -sV --version-all "$target" -oN - 2>/dev/null
                
                # libvirt enumeration
                echo "--- libvirt Enumeration ---"
                nmap -p 16509 --script libvirt-* "$target" -oN - 2>/dev/null
                
                # VNC check
                echo "--- VNC Access Check ---"
                for port in {5900..5910}; do
                    timeout 2 nc -zv "$target" "$port" 2>&1 | grep -q succeeded && \
                        echo "VNC port $port is open - check for no-auth access"
                done
                
                # KVM vulnerabilities
                echo "--- Known KVM Vulnerabilities ---"
                echo "Check these CVEs: ${HYPERVISOR_CVES[$hv_type]}"
                
                # Check for default creds
                echo "--- Default Credentials Check ---"
                echo "Try: root:root, admin:admin, libvirt:libvirt"
            } >> "$output_file" 2>/dev/null
            ;;
            
        *Xen*)
            echo -e "${YELLOW}  ├─ Scanning Xen/XCP-ng-specific vectors...${NC}"
            {
                echo ""
                echo "=== XEN/XCP-NG DEEP SCAN ==="
                echo "Scans performed:"
                echo "  - nmap -sV --version-all (Xen ports)"
                echo "  - HTTP(S) API/UI path checks"
                echo ""
                
                # Xen port scan
                echo "--- Xen Service Scan ---"
                nmap -p 22,80,443,5900,5901 -sV --version-all "$target" -oN - 2>/dev/null
                
                # Xen API enumeration
                echo "--- Xen API Enumeration ---"
                for path in "/xapi" "/XenCenter" "/cli"; do
                    curl -sk "https://$target:443$path" -I 2>/dev/null | head -1
                done
                
                # Xen vulnerabilities
                echo "--- Known Xen Vulnerabilities ---"
                echo "Check these CVEs: ${HYPERVISOR_CVES[$hv_type]}"
                
                # Check for default creds
                echo "--- Default Credentials Check ---"
                echo "Try: ${HYPERVISOR_DEFAULT_CREDS[$hv_type]}"
            } >> "$output_file" 2>/dev/null
            ;;
            
        *Nutanix*)
            echo -e "${YELLOW}  ├─ Scanning Nutanix-specific vectors...${NC}"
            {
                echo ""
                echo "=== NUTANIX DEEP SCAN ==="
                echo "Scans performed:"
                echo "  - nmap -sV --version-all (Prism ports)"
                echo "  - HTTP(S) Prism API/UI path checks"
                echo ""
                
                # Nutanix port scan
                echo "--- Nutanix Service Scan ---"
                nmap -p 443,9440,2020,2030,111,2049 -sV --version-all "$target" -oN - 2>/dev/null
                
                # Prism enumeration
                echo "--- Prism API Enumeration ---"
                for path in "/prism" "/console" "/api/nutanix/v3"; do
                    curl -sk "https://$target:9440$path" -I 2>/dev/null | head -1
                done
                
                # Nutanix vulnerabilities
                echo "--- Known Nutanix Vulnerabilities ---"
                echo "Check these CVEs: ${HYPERVISOR_CVES[$hv_type]}"
                
                # Check for default creds
                echo "--- Default Credentials Check ---"
                echo "Try: ${HYPERVISOR_DEFAULT_CREDS[$hv_type]}"
            } >> "$output_file" 2>/dev/null
            ;;
            
        *oVirt*|*RHEV*)
            echo -e "${YELLOW}  ├─ Scanning oVirt/RHEV-specific vectors...${NC}"
            {
                echo ""
                echo "=== OVIRT/RHEV DEEP SCAN ==="
                echo "Scans performed:"
                echo "  - nmap -sV --version-all (oVirt ports)"
                echo "  - HTTP(S) API/UI path checks"
                echo ""
                
                # oVirt port scan
                echo "--- oVirt Service Scan ---"
                nmap -p 443,8443,5432,8080,8700 -sV --version-all "$target" -oN - 2>/dev/null
                
                # oVirt API enumeration
                echo "--- oVirt API Enumeration ---"
                for path in "/ovirt-engine" "/webadmin" "/api"; do
                    curl -sk "https://$target:443$path" -I 2>/dev/null | head -1
                done
                
                # oVirt vulnerabilities
                echo "--- Known oVirt Vulnerabilities ---"
                echo "Check CVEs related to oVirt/RHEV"
                
                # Check for default creds
                echo "--- Default Credentials Check ---"
                echo "Try: ${HYPERVISOR_DEFAULT_CREDS[$hv_type]}"
            } >> "$output_file" 2>/dev/null
            ;;
            
        *)
            echo -e "${YELLOW}  ├─ Generic hypervisor scan (unknown type)${NC}"
            {
                echo ""
                echo "=== GENERIC HYPERVISOR SCAN ==="
                echo "Scans performed:"
                echo "  - nmap -sV --version-all (all known hypervisor ports from database)"
                echo "  - HTTP(S) header checks on common web ports"
                echo ""
                
                # Scan all potential hypervisor ports
                all_ports=""
                for ports in "${HYPERVISOR_PORTS[@]}"; do
                    all_ports="${all_ports},${ports}"
                done
                all_ports="${all_ports#,}"
                
                nmap -p "$all_ports" -sV --version-all "$target" -oN - 2>/dev/null
                
                # Try to identify via banners
                for port in 80 443 8080 8443; do
                    curl -sk "https://$target:$port" -I 2>/dev/null | head -20
                done
            } >> "$output_file" 2>/dev/null
            ;;
    esac
    
    # Additional common checks for all hypervisors
    {
        echo ""
        echo "=== ADDITIONAL HYPERVISOR CHECKS ==="
        
        # OS Detection
        echo "--- Operating System ---"
        nmap -O "$target" -oN - 2>/dev/null | grep -E "OS details|Running|OS guess"
        
        # Open ports summary
        echo "--- All Open Ports Summary ---"
        nmap -p- --min-rate 1000 "$target" -oN - 2>/dev/null | grep "^[0-9]"
        
        # VM escape vulnerabilities check
        echo "--- VM Escape Vulnerability Check ---"
        echo "Check for:"
        echo "  - CVE-2021-21985 (VMware vCenter RCE)"
        echo "  - CVE-2021-22005 (VMware vCenter file upload)"
        echo "  - CVE-2023-24903 (Hyper-V RCE)"
        echo "  - CVE-2020-3992 (VMware ESXi escape)"
        echo "  - CVE-2022-0216 (KVM/libvirt escape)"
        
        # Check for management interfaces
        echo "--- Management Interfaces ---"
        for path in "/ui" "/admin" "/vsphere" "/hyperv" "/proxmox" "/xen" "/prism"; do
            for port in 80 443 8080 8443 9443 8006; do
                curl -sk "https://$target:$port$path" -I 2>/dev/null | head -1
                curl -sk "http://$target:$port$path" -I 2>/dev/null | head -1
            done
        done
        
    } >> "$output_file" 2>/dev/null
}

# =============================================================================
# SCAN TARGET FUNCTION
# =============================================================================

scan_target() {
    local target="$1"
    local output_file="$2"
    local start_time=$(date +%s)
    local role_assessment=""
    local target_role=""
    local top_risk_layer=""
    local role_rationale=""
    
    echo -e "\n${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}${BOLD}              SCANNING TARGET: $target${NC}"
    echo -e "${PURPLE}${BOLD}═══════════════════════════════════════════════════════════════════${NC}\n"
    
    # PHASE 1: Discover hypervisor
    discovery_result=$(discover_hypervisor "$target" "$output_file")
    hv_type=$(echo "$discovery_result" | cut -d':' -f1)
    confidence=$(echo "$discovery_result" | cut -d':' -f2)

    role_assessment=$(classify_target_role "$target" "$hv_type" "$confidence" "$output_file")
    target_role=$(echo "$role_assessment" | cut -d'|' -f1)
    top_risk_layer=$(echo "$role_assessment" | cut -d'|' -f2)
    role_rationale=$(echo "$role_assessment" | cut -d'|' -f3-)
    
    # PHASE 2: Route to the right scan path
    if [ -n "$hv_type" ] && [ "$confidence" -gt 30 ]; then
        deep_hypervisor_scan "$target" "$hv_type" "$output_file"
    else
        generic_host_scan "$target" "$output_file" "$target_role"
    fi

    write_risk_layer_summary "$target" "$target_role" "$hv_type" "$confidence" "$output_file"
    
    # FINAL: Summary for this target
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    {
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════"
        echo "TARGET SCAN COMPLETE: $target"
        echo "Duration: $duration seconds"
        echo "Hypervisor detected: ${hv_type:-None}"
        echo "Confidence: ${confidence:-0}%"
        echo "Target role: ${target_role:-Inconclusive}"
        echo "Primary risk layer: ${top_risk_layer:-Unknown}"
        echo "Role rationale: ${role_rationale:-None}"
        echo "═══════════════════════════════════════════════════════════════════════"
        echo ""
    } >> "$output_file"
    
    echo -e "\n${GREEN}[✓] Completed scan on $target (${duration}s)${NC}"
    echo -e "${GREEN}[✓] Hypervisor: ${hv_type:-None} (${confidence:-0}% confidence)${NC}"
    echo -e "${GREEN}[✓] Role: ${target_role:-Inconclusive} | Risk focus: ${top_risk_layer:-Unknown}${NC}"

    {
        echo "[+] Completed scan on $target (${duration}s)"
        echo "[+] Hypervisor: ${hv_type:-None} (${confidence:-0}% confidence)"
        echo "[+] Role: ${target_role:-Inconclusive}"
        echo "[+] Risk focus: ${top_risk_layer:-Unknown}"
        echo ""
    } >> "$output_file"
}

# =============================================================================
# MAIN MENU
# =============================================================================

main() {
    print_banner
    check_deps
    
    local output_file="hypervisor_scan_$(date +%Y%m%d_%H%M%S).txt"
    
    # Initialize output file
    {
        echo "╔═══════════════════════════════════════════════════════════════════════╗"
        echo "║              HYPERVISOR-SPECIFIC SCAN RESULTS                        ║"
        echo "║              Generated: $(date)                                       ║"
        echo "╚═══════════════════════════════════════════════════════════════════════╝"
        echo ""
    } > "$output_file"

    echo -e "${GREEN}[+] Writing results to: ${output_file}${NC}"
    {
        echo "Results file: $output_file"
        echo ""
    } >> "$output_file"
    
    while true; do
        echo -e "\n${BOLD}${WHITE}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${WHITE}║                    HYPERVISOR SCANNER                     ║${NC}"
        echo -e "${BOLD}${WHITE}╠════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${BOLD}${WHITE}║  ${CYAN}1)${WHITE}  Scan Single IP                              ║${NC}"
        echo -e "${BOLD}${WHITE}║  ${CYAN}2)${WHITE}  Scan IP File                                ║${NC}"
        echo -e "${BOLD}${WHITE}║  ${CYAN}3)${WHITE}  View Results                                ║${NC}"
        echo -e "${BOLD}${WHITE}║  ${CYAN}4)${WHITE}  Quit                                        ║${NC}"
        echo -e "${BOLD}${WHITE}╚════════════════════════════════════════════════════════════╝${NC}"
        echo -n -e "${GREEN}Select option [1-4]: ${NC}"
        read -r choice

        case "$choice" in
            1)
                echo -n -e "${YELLOW}Enter target IP/hostname: ${NC}"
                read -r target
                if [ -z "${target:-}" ]; then
                    echo -e "${RED}[!] No target entered${NC}"
                    continue
                fi
                scan_target "$target" "$output_file"
                ;;
            2)
                echo -n -e "${YELLOW}Enter target file path: ${NC}"
                read -r file_path
                if [ -z "${file_path:-}" ] || [ ! -f "$file_path" ]; then
                    echo -e "${RED}[!] File not found: $file_path${NC}"
                    continue
                fi

                echo -e "${CYAN}[*] Scanning targets from: $file_path${NC}"
                while IFS= read -r line || [ -n "$line" ]; do
                    line="$(echo "$line" | tr -d '\r' | xargs)"
                    [[ -z "$line" || "$line" =~ ^# ]] && continue
                    scan_target "$line" "$output_file"
                done < "$file_path"
                ;;
            3)
                echo -e "${CYAN}[*] Results file: $output_file${NC}"
                if [ -f "$output_file" ]; then
                    echo -e "${CYAN}--- Showing last 80 lines ---${NC}"
                    tail -n 80 "$output_file"
                else
                    echo -e "${YELLOW}[!] Results file not found yet${NC}"
                fi
                ;;
            4|q|Q)
                echo -e "${GREEN}[+] Exiting.${NC}"
                break
                ;;
            *)
                echo -e "${YELLOW}[!] Invalid option${NC}"
                ;;
        esac
    done
}

main "$@"

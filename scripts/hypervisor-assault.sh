#!/usr/bin/env bash
set -euo pipefail

# Hypervisor Assault (Discovery/Fingerprinting Edition)
# Educational + authorized testing only.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

OUTPUT_DIR="hypervisor_assault_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${OUTPUT_DIR}/assault.log"

# Safe defaults
RATE="1000"     # used only if masscan is available
THREADS="50"    # used only if masscan is available

# Hypervisor-related ports (discovery only)
PORTS_COMMON="22,80,443,445,3389,5900,8006,8080,8443,9443,5985,5986,902,903,548,16509,16514,49152"

log() {
  mkdir -p "$OUTPUT_DIR"
  printf "%b[%s] %s%b\n" "${GREEN}" "$(date '+%H:%M:%S')" "$1" "${NC}" | tee -a "$LOG_FILE" >/dev/null
}

warn() {
  mkdir -p "$OUTPUT_DIR"
  printf "%b[%s] %s%b\n" "${YELLOW}" "$(date '+%H:%M:%S')" "$1" "${NC}" | tee -a "$LOG_FILE" >/dev/null
}

die() {
  printf "%b[!] %s%b\n" "${RED}" "$1" "${NC}" >&2
  exit 1
}

check_deps() {
  local deps=(bash nmap curl dig awk sed grep sort wc)
  local missing=()
  for d in "${deps[@]}"; do
    command -v "$d" >/dev/null 2>&1 || missing+=("$d")
  done
  if ((${#missing[@]})); then
    die "Missing dependencies: ${missing[*]}. Install them and re-run."
  fi
}

print_banner() {
  printf "%b%bHypervisor Assault%b\n" "${BOLD}" "${CYAN}" "${NC}"
  printf "%bDiscovery/Fingerprinting Edition (no credential attacks).%b\n" "${CYAN}" "${NC}"
  printf "%bAuthorized testing only.%b\n\n" "${YELLOW}" "${NC}"
}

select_target_source() {
  local choice
  echo -e "${YELLOW}${BOLD}Choose one of the following:${NC}"
  echo -e "${CYAN}1) Target IP${NC}"
  echo -e "${CYAN}2) Target File${NC}"
  echo -e "${CYAN}   Example: /home/red/Desktop/HyperVisor/hypervisor-assault/examples/targets.txt${NC}"
  echo -e "${CYAN}3) Quit${NC}"
  echo -ne "${YELLOW}Select option [1-3]: ${NC}"
  read -r choice

  case "$choice" in
    1)
      echo -ne "${YELLOW}Enter target IP (or CIDR/domain/range): ${NC}"
      local t
      read -r t
      [[ -n "$t" ]] || die "No target entered"
      mkdir -p "$OUTPUT_DIR"
      printf "%s\n" "$t" > "${OUTPUT_DIR}/00_single_target.txt"
      echo "${OUTPUT_DIR}/00_single_target.txt"
      ;;
    2)
      echo -ne "${YELLOW}Enter target file path: ${NC}"
      local f
      read -r f
      [[ -f "$f" ]] || die "Target file not found: $f"
      echo "$f"
      ;;
    3|q|Q)
      exit 0
      ;;
    *)
      die "Invalid selection"
      ;;
  esac
}

expand_targets() {
  local input="$1"
  local out="${OUTPUT_DIR}/01_targets_expanded.txt"
  mkdir -p "$OUTPUT_DIR"
  : > "$out"

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    line="$(printf "%s" "$line" | tr -d '\r' | xargs)"

    if [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
      python3 - <<PY >>"$out" 2>/dev/null
import ipaddress
net = ipaddress.ip_network("$line", strict=False)
for ip in net.hosts():
    print(ip)
PY
    elif [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "$line" >> "$out"
    elif [[ "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$ ]]; then
      base=$(echo "$line" | cut -d'-' -f1 | rev | cut -d'.' -f2- | rev)
      start=$(echo "$line" | cut -d'-' -f1 | rev | cut -d'.' -f1 | rev)
      end=$(echo "$line" | cut -d'-' -f2)
      seq "$start" "$end" | awk -v b="$base" '{print b"."$1}' >> "$out"
    else
      dig +short "$line" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' >> "$out" 2>/dev/null || true
    fi
  done < "$input"

  sort -u -V "$out" -o "$out"
  echo "$out"
}

port_scan() {
  local targets_file="$1"
  local out="${OUTPUT_DIR}/02_open_ports.txt"
  mkdir -p "$OUTPUT_DIR"
  : > "$out"

  if command -v masscan >/dev/null 2>&1; then
    warn "masscan detected; using it with rate=${RATE} (requires sudo)."
    sudo masscan -iL "$targets_file" -p "$PORTS_COMMON" --rate "$RATE" --threads "$THREADS" --open-only -oX "${OUTPUT_DIR}/masscan.xml" \
      2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    if [[ -f "${OUTPUT_DIR}/masscan.xml" ]]; then
      grep -o 'addr="[^"]*" port="[^"]*"' "${OUTPUT_DIR}/masscan.xml" | sed 's/addr="//; s/" port="/:/; s/"//g' | sort -u > "$out" || true
    fi
  fi

  if [[ ! -s "$out" ]]; then
    warn "Using nmap connect scan on common ports (no sudo required for -sT)."
    nmap -sT -p "$PORTS_COMMON" -iL "$targets_file" --open -oG - 2>/dev/null \
      | awk '
          /Ports:/ {
            ip=$2
            line=$0
            sub(/^.*Ports: /, "", line)
            split(line, entries, /, /)
            for (i in entries) {
              split(entries[i], f, "/")
              if (f[2] == "open") {
                print ip ":" f[1]
              }
            }
          }
        ' | sort -u > "$out" || true
  fi

  if [[ ! -s "$out" ]]; then
    echo "# NO OPEN HYPERVISOR PORTS DETECTED" > "$out"
    echo "# If the target is a normal VMware guest OS, that is expected unless the guest exposes one of: ${PORTS_COMMON}" >> "$out"
  fi

  echo "$out"
}

fingerprint() {
  local open_ports_file="$1"
  local out="${OUTPUT_DIR}/03_fingerprints.txt"
  : > "$out"

  echo "# Fingerprints - $(date)" >> "$out"

  grep -v '^#' "$open_ports_file" | grep ':' | while IFS= read -r ep; do
    ip="${ep%%:*}"
    port="${ep##*:}"

    # Lightweight HTTP(S) header grab (safe)
    if [[ "$port" == "80" || "$port" == "8080" ]]; then
      hdr=$(curl -sS -m 3 -I "http://${ip}:${port}/" 2>/dev/null | tr -d '\r' | head -n 5 || true)
      [[ -n "$hdr" ]] && {
        echo "=== ${ip}:${port} (http) ===" >> "$out"
        echo "$hdr" >> "$out"
        echo >> "$out"
      }
    fi

    if [[ "$port" == "443" || "$port" == "8443" || "$port" == "9443" || "$port" == "8006" ]]; then
      hdr=$(curl -sS -k -m 3 -I "https://${ip}:${port}/" 2>/dev/null | tr -d '\r' | head -n 5 || true)
      [[ -n "$hdr" ]] && {
        echo "=== ${ip}:${port} (https) ===" >> "$out"
        echo "$hdr" >> "$out"
        echo >> "$out"
      }
    fi
  done

  echo "$out"
}

main() {
  print_banner
  check_deps

  mkdir -p "$OUTPUT_DIR"
  log "Output directory: $OUTPUT_DIR"

  local src
  if [[ $# -gt 0 ]]; then
    src="$1"
    [[ -f "$src" ]] || die "Target file not found: $src"
  else
    src="$(select_target_source)"
  fi

  log "Expanding targets from: $src"
  targets_expanded="$(expand_targets "$src")"
  count=$(wc -l < "$targets_expanded" | tr -d ' ')
  log "Targets: $count"

  log "Scanning common hypervisor ports"
  open_ports="$(port_scan "$targets_expanded")"

  log "Fingerprinting discovered endpoints"
  fp="$(fingerprint "$open_ports")"

  log "Done. Results: $fp"
  printf "%b%s%b\n" "${CYAN}" "Open: $open_ports" "${NC}"
}

main "$@"

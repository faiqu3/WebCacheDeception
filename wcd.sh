#!/bin/bash

########################################
# COLORS
########################################
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

########################################
# SAFE UNIQUE LOCK (portable)
########################################
LOCK_DIR="$(mktemp -d /tmp/wcd_lock.XXXXXX)"

lock() {
  while ! mkdir "$LOCK_DIR/lock" 2>/dev/null; do
    sleep 0.01
  done
}

unlock() {
  rmdir "$LOCK_DIR/lock" 2>/dev/null
}

########################################
# CLEAN EXIT (Ctrl+C safe)
########################################
cleanup() {
  echo -e "\n${RED}[!] Interrupted. Exiting cleanly.${RESET}"
  jobs -p | xargs -r kill 2>/dev/null
  rm -rf "$LOCK_DIR"
  exit 130
}

trap cleanup INT TERM
trap 'rm -rf "$LOCK_DIR"' EXIT

########################################
# ATOMIC OUTPUT
########################################
print_block() {
  local block="$1"
  lock
  printf "%b\n" "$block"
  [[ -n "$output_file" ]] && printf "%b\n" "$block" >> "$output_file"
  unlock
}

########################################
# BANNER
########################################
echo -e "${CYAN}------------------------------------------------------------${RESET}"
echo -e "${BOLD} Web Cache Deception Scanner${RESET}"
echo -e "${CYAN}------------------------------------------------------------${RESET}"

########################################
# HELP / USAGE
########################################
show_help() {
  echo -e "${BOLD}Usage:${RESET}"
  echo "  $0 --urlfile urls.txt --cookie 'session=abc' --reflection A,B,C [options]"
  echo
  echo -e "${BOLD}Description:${RESET}"
  echo "  Tests Web Cache Deception by appending static extensions"
  echo "  and detecting reflected values in cached responses."
  echo
  echo -e "${BOLD}Required:${RESET}"
  echo "  --urlfile FILE        File containing base URLs (one per line)"
  echo "  --cookie STRING       Auth cookie (used only for requests)"
  echo "  --reflection STRING   Comma-separated reflection values"
  echo
  echo -e "${BOLD}Optional:${RESET}"
  echo "  --proxy URL           HTTP proxy (e.g. http://127.0.0.1:8080)"
  echo "  -t, --thread N        Parallel requests per target (default: 10)"
  echo "  --output FILE         Save output to file"
  echo "  -h, --help            Show this help message"
  echo
  echo -e "${BOLD}Examples:${RESET}"
  echo "  $0 --urlfile urls.txt \\"
  echo "     --cookie \"session=abc123\" \\"
  echo "     --reflection \"wiener,TEST123\" \\"
  echo "     --proxy http://127.0.0.1:8080"
  echo
  exit 0
}

########################################
# DEFAULTS
########################################
threads=10
proxy_url=""
proxy_arg=()
output_file=""

########################################
# ARG PARSE
########################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --urlfile) url_file="$2"; shift 2 ;;
    --cookie) cookie_input="$2"; shift 2 ;;
    --reflection) reflection_input="$2"; shift 2 ;;
    --proxy) proxy_url="$2"; shift 2 ;;
    -t|--thread) threads="$2"; shift 2 ;;
    --output) output_file="$2"; shift 2 ;;
    -h|--help) show_help ;;
    *) echo -e "${RED}Unknown option: $1${RESET}"; exit 1 ;;
  esac
done

########################################
# VALIDATION
########################################
[[ -z "$url_file" || -z "$cookie_input" || -z "$reflection_input" ]] && show_help
[[ ! -f "$url_file" ]] && echo -e "${RED}URL file not found${RESET}" && exit 1

IFS=',' read -ra REFLECTIONS <<< "$reflection_input"
[[ -n "$proxy_url" ]] && proxy_arg=(-x "$proxy_url")

extensions=(css js png jpg gif ico woff woff2 svg)

########################################
# THREAD CONTROL
########################################
wait_for_slot() {
  while (( $(jobs -rp | wc -l) >= threads )); do
    sleep 0.05
  done
}

########################################
# SCAN FUNCTION
########################################
scan_one() {
  local base_url="$1"
  local ext="$2"

  local rand url hdr_tmp body_tmp
  rand=$(head -c 16 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 6)
  url="${base_url}/${rand}.${ext}?hackme$RANDOM"

  hdr_tmp=$(mktemp)
  body_tmp=$(mktemp)

  curl -sk \
    -H "Cookie: $cookie_input" \
    "${proxy_arg[@]}" \
    -D "$hdr_tmp" \
    -o "$body_tmp" \
    "$url"

  body_lc="$(tr '[:upper:]' '[:lower:]' < "$body_tmp")"
  matched_reflections=()

  for ref in "${REFLECTIONS[@]}"; do
    ref_clean="$(printf '%s' "$ref" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    ref_lc="$(printf '%s' "$ref_clean" | tr '[:upper:]' '[:lower:]')"

    if grep -qF -- "$ref_lc" <<< "$body_lc"; then
      matched_reflections+=("$ref_lc")
    fi
  done

  if (( ${#matched_reflections[@]} > 0 )); then
    cache_hdrs=$(grep -Ei '^(cache-control|age|etag|expires|pragma|x-cache|last-modified):' "$hdr_tmp" | sort -u)
    if [[ -n "$cache_hdrs" ]]; then
      block="${BOLD}[🔥 WCD HIT]${RESET} $url\n"
      block+="    ${GREEN}Reflected:${RESET}\n"
      for r in "${matched_reflections[@]}"; do
        block+="      - $r\n"
      done
      block+="    ${CYAN}Cache headers:${RESET}\n"
      while IFS= read -r line; do
        block+="      - $line\n"
      done <<< "$cache_hdrs"
      print_block "$block"
    fi
  fi

  rm -f "$hdr_tmp" "$body_tmp"
}

########################################
# MAIN LOOP
########################################
while IFS= read -r raw; do
  base_url="$(printf '%s' "$raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "$base_url" ]] && continue

  base_url="${base_url%%#*}"
  base_url="${base_url%%\?*}"
  base_url="${base_url%/}"

  print_block "\n${BLUE}=== Target:${RESET} $base_url"

  for ext in "${extensions[@]}"; do
    wait_for_slot
    scan_one "$base_url" "$ext" &
  done
  wait
done < "$url_file"

print_block "\n${GREEN}✅ Scan complete.${RESET}"

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
echo -e "${BOLD} Web Cache Deception Scanner (final stable build)${RESET}"
echo -e "${CYAN}------------------------------------------------------------${RESET}"

########################################
# HELP
########################################
show_help() {
  echo -e "${BOLD}Usage:${RESET}"
  echo "  $0 --urlfile urls.txt --cookie 'session=abc' --reflection VALUE [options]"
  echo
  echo -e "${BOLD}Required:${RESET}"
  echo "  --urlfile FILE           Base URLs (one per line)"
  echo "  --cookie STRING          Cookie (auth only)"
  echo "  --reflection STRING      Reflection value to detect"
  echo
  echo -e "${BOLD}Optional:${RESET}"
  echo "  --proxy URL              HTTP proxy"
  echo "  -t, --thread N           Parallel requests per target (default: 10)"
  echo "  -mc, --match-code CODES  Only test these HTTP codes"
  echo "  --output FILE            Save output"
  echo "  --vv                     Verbose/debug"
  exit 0
}

########################################
# DEFAULTS
########################################
threads=10
verbose=false
proxy_url=""
proxy_arg=()
match_codes=""
output_file=""

########################################
# ARG PARSE
########################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --urlfile) url_file="$2"; shift 2 ;;
    --cookie) cookie_input="$2"; shift 2 ;;
    --reflection) reflection="$2"; shift 2 ;;
    --proxy) proxy_url="$2"; shift 2 ;;
    --proxy=*) proxy_url="${1#--proxy=}"; shift ;;
    -t|--thread) threads="$2"; shift 2 ;;
    -mc|--match-code) match_codes="$2"; shift 2 ;;
    --output) output_file="$2"; shift 2 ;;
    --vv) verbose=true; shift ;;
    -h|--help) show_help ;;
    *) echo -e "${RED}Unknown option: $1${RESET}"; exit 1 ;;
  esac
done

########################################
# VALIDATION
########################################
[[ -z "$url_file" || -z "$cookie_input" || -z "$reflection" ]] && show_help
[[ ! -f "$url_file" ]] && echo -e "${RED}URL file not found${RESET}" && exit 1
! [[ "$threads" =~ ^[0-9]+$ ]] && echo -e "${RED}Invalid thread count${RESET}" && exit 1

print_block "${YELLOW}[i] Threads per target:${RESET} $threads"

if [[ -n "$proxy_url" ]]; then
  proxy_arg=(-x "$proxy_url")
  print_block "${YELLOW}[i] Proxy:${RESET} $proxy_url"
fi

########################################
# CONSTANTS
########################################
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
# SCAN FUNCTION (1 REQUEST ONLY)
########################################
scan_one() {
  local base_url="$1"
  local ext="$2"

  local rand hackid url hdr_tmp body_tmp status_code cache_hdrs
  rand=$(head -c 16 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 6)
  hackid=$(printf '%04d%04d' "$RANDOM")
  url="${base_url}/${rand}.${ext}?hackme${hackid}"

  hdr_tmp=$(mktemp)
  body_tmp=$(mktemp)

  status_code=$(curl --insecure -s \
    -H "User-Agent: WCDScanner" \
    -H "Cookie: $cookie_input" \
    -H "Accept-Encoding: identity" \
    "${proxy_arg[@]}" \
    -D "$hdr_tmp" \
    -o "$body_tmp" \
    -w "%{http_code}" \
    "$url")

  local test=true
  if [[ -n "$match_codes" ]]; then
    test=false
    IFS=',' read -ra mc <<< "$match_codes"
    for m in "${mc[@]}"; do [[ "$status_code" == "$m" ]] && test=true; done
  else
    [[ "$status_code" =~ ^3 ]] && test=false
  fi

  [[ "$test" == false ]] && { rm -f "$hdr_tmp" "$body_tmp"; return; }

  if grep -qF "$reflection" "$body_tmp"; then
    cache_hdrs=$(grep -Ei '^(cache-control|age|etag|expires|pragma|x-cache|last-modified):' "$hdr_tmp" | sort -u)

    if [[ -n "$cache_hdrs" ]]; then
      local block
      block="${BOLD}[🔥 WCD HIT]${RESET} $url\n"
      block+="    ${GREEN}Reflected:${RESET} $reflection\n"
      block+="    ${CYAN}Cache headers:${RESET}\n"
      while IFS= read -r line; do
        block+="      - $line\n"
      done <<< "$cache_hdrs"

      print_block "$block"
    fi
  elif $verbose; then
    print_block "${YELLOW}[DEBUG] No reflection:${RESET} $url"
  fi

  rm -f "$hdr_tmp" "$body_tmp"
}

########################################
# MAIN LOOP (NO OUTPUT BLEED)
########################################
while IFS= read -r raw; do
  base_url=$(echo "$raw" | xargs)
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

#!/bin/bash

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

echo -e "${CYAN}------------------------------------------------------------------${RESET}"
echo -e "${BOLD} Custom Reflection & Cache Detection (static paths + ?hackmeN)${RESET}"
echo -e "     (3xx skipped by default unless -mc is used, parallel requests)${RESET}"
echo -e "${CYAN}------------------------------------------------------------------${RESET}"

show_help() {
  echo -e "${BOLD}Usage:${RESET} $0 --urlfile urls.txt --cookie 'session=abc' [options]"
  echo
  echo -e "${BOLD}Required:${RESET}"
  echo "  --urlfile FILE           File containing URLs (one per line)"
  echo "  --cookie STRING          Cookie header (e.g. 'session=abc; token=1')"
  echo
  echo -e "${BOLD}Optional:${RESET}"
  echo "  --reflection TEXT  Additional reflection string(s) to search (comma-separated)"
  echo "  --output FILE            Save output to file"
  echo "  --proxy URL              HTTP proxy (e.g. http://127.0.0.1:8080)"
  echo "  -mc, --match-code CODES  Only test these HTTP codes (e.g. 200 or 200,404)"
  echo "  -t,  --thread N          Number of parallel requests (default: 10)"
  echo "  --vv                     Very verbose logging"
  echo "  -h, --help               Show help"
  exit 0
}

# Defaults
verbose=false
proxy_url=""
proxy_arg=()
match_codes=""
threads=10   # default concurrency

# Parse CLI args
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --urlfile) url_file="$2"; shift 2 ;;
        --cookie) cookie_input="$2"; shift 2 ;;
        --reflection) custom_reflection="$2"; shift 2 ;;
        --output) output_file="$2"; shift 2 ;;
        --proxy) proxy_url="$2"; shift 2 ;;
        --proxy=*) proxy_url="${1#--proxy=}"; shift ;;
        -mc|--match-code) match_codes="$2"; shift 2 ;;
        -t|--thread) threads="$2"; shift 2 ;;
        --vv) verbose=true; shift ;;
        -h|--help) show_help ;;
        *) echo -e "${RED}Unknown parameter: $1${RESET}"; exit 1 ;;
    esac
done

# Validate threads
if ! [[ "$threads" =~ ^[0-9]+$ ]] || [[ "$threads" -le 0 ]]; then
  echo -e "${RED}Invalid thread count: $threads${RESET}"
  exit 1
fi

THREADS="$threads"
echo -e "${YELLOW}[i] Using $THREADS parallel request(s)${RESET}"

# Make proxy functional
if [[ -n "$proxy_url" ]]; then
  proxy_arg=(-x "$proxy_url")
  echo -e "${YELLOW}[i] Using proxy: $proxy_url${RESET}"
fi

# Validate required
if [[ -z "$url_file" || -z "$cookie_input" ]]; then
  show_help
fi

# Output logger (not atomic, but good enough for our use)
log_output() {
  echo -e "$1"
  if [[ -n "$output_file" ]]; then
    echo -e "$1" >> "$output_file"
  fi
}

# Validate file
if [[ ! -f "$url_file" ]]; then
  echo -e "${RED}File not found: $url_file${RESET}"
  exit 1
fi

# Custom reflection list (no automatic cookie reflection)
declare -a reflect_values=()
if [[ -n "$custom_reflection" ]]; then
  IFS="," read -ra _custom_vals <<< "$custom_reflection"
  for v in "${_custom_vals[@]}"; do
    v=$(echo "$v" | xargs)
    [[ -n "$v" ]] && reflect_values+=("$v")
  done
fi

# Extensions we’ll test for EVERY URL (one request per ext)
extensions=("css" "js" "png" "jpg" "gif" "ico" "woff" "woff2" "svg" "avif")

# Concurrency control helper
wait_for_slot() {
  while (( $(jobs -rp | wc -l) >= THREADS )); do
    sleep 0.05
  done
}

# Function to scan a single (base_url, ext) pair
scan_one() {
  local base_url="$1"
  local ext="$2"

  # unique ID per request for hackme param
  local hackid
  hackid=$(printf '%04d%04d' "$RANDOM" "$RANDOM")

  # Random file name for this extension
  local rand path full_url
  rand=$(head -c 6 /dev/urandom | base64 | tr -dc 'a-z0-9' | head -c 6)
  path="/${rand}.${ext}"

  full_url="${base_url}${path}?hackme${hackid}"

  # ===== Single request: status + headers + body =====
  local response status_code headers body
  response=$(curl --insecure -s -D - \
    -H "User-Agent: WCDScanner" \
    -H "Cookie: $cookie_input" \
    "${proxy_arg[@]}" \
    "$full_url" 2>/dev/null)

  if [[ -z "$response" ]]; then
    status_code="000"
    headers=""
    body=""
  else
    # status line example: HTTP/1.1 200 OK
    status_code=$(printf '%s\n' "$response" | head -n 1 | awk '{print $2}')
    [[ -z "$status_code" ]] && status_code="000"

    # split headers and body on first blank line
    headers=$(printf '%s\n' "$response" | awk 'BEGIN{h=1} h && NF==0 {h=0} h')
    body=$(printf '%s\n' "$response" | awk 'BEGIN{h=1} h && NF==0 {h=0; next} !h')
  fi

  # Verbose request log
  if $verbose; then
    if [[ "$status_code" =~ ^2 ]]; then
      log_output "${GREEN}[REQ]${RESET} $full_url (${GREEN}${status_code}${RESET})"
    elif [[ "$status_code" =~ ^3 ]]; then
      log_output "${YELLOW}[REQ]${RESET} $full_url (${YELLOW}${status_code}${RESET})"
    else
      log_output "${RED}[REQ]${RESET} $full_url (${RED}${status_code}${RESET})"
    fi
  fi

  # Status 000 hint
  [[ "$status_code" == "000" ]] && \
    log_output "    ${YELLOW}Note:${RESET} Status 000 = failed connection (proxy/TLS issue)."

  # ===== Status filtering =====
  local should_test="true"

  if [[ -n "$match_codes" ]]; then
    should_test="false"
    local mc m
    IFS="," read -ra mc <<< "$match_codes"
    for m in "${mc[@]}"; do
      m=$(echo "$m" | xargs)
      [[ "$status_code" == "$m" ]] && should_test="true"
    done
  else
    # Default skip 3xx
    [[ "$status_code" =~ ^3 ]] && should_test="false"
  fi

  if [[ "$should_test" == "false" ]]; then
    $verbose && log_output "    ${YELLOW}Skipping status $status_code (filtered).${RESET}"
    return
  fi

  # ===== Reflection check =====
  local reflected=false
  local reflection_output=""
  local val

  for val in "${reflect_values[@]}"; do
    if echo "$body" | grep -qF "$val"; then
      reflected=true
      reflection_output+="      - Reflected: ${BOLD}$val${RESET}\n"
    fi
  done

  # ===== Display =====
  if $reflected || $verbose; then
    local color="${RED}"
    [[ "$status_code" =~ ^2 ]] && color="${GREEN}"
    [[ "$status_code" =~ ^3 ]] && color="${YELLOW}"

    log_output "${BOLD}[+] URL:${RESET} $full_url"
    log_output "    Status: ${color}${status_code}${RESET}"
  fi

  if $reflected; then
    log_output "    ${GREEN}Reflections found:${RESET}"
    # Print reflection lines
    while IFS= read -r line; do
      log_output "$line"
    done <<< "$(printf "%b" "$reflection_output")"

    local cache_hdrs
    cache_hdrs=$(echo "$headers" | grep -Ei 'cache|etag|expires|pragma|age|last-modified')
    if [[ -n "$cache_hdrs" ]]; then
      log_output "    ${CYAN}Cache-Relevant Headers:${RESET}"
      echo "$cache_hdrs" | sed 's/^/      - /' | while IFS= read -r line; do
        log_output "$line"
      done
    else
      log_output "    ${RED}No cache-related headers found.${RESET}"
    fi
  fi
}

# MAIN LOOP
while IFS= read -r raw_url; do
  # Trim whitespace
  base_url=$(echo "$raw_url" | xargs)
  [[ -z "$base_url" ]] && continue

  # Strip fragment if present
  base_url="${base_url%%#*}"
  # Strip existing query string if present
  base_url="${base_url%%\?*}"
  # Remove trailing slash to avoid '//' when appending our own path
  base_url="${base_url%/}"

  echo
  log_output "${BLUE}=== Target: ${base_url} ===${RESET}"

  # For each extension, schedule a parallel scan
  for ext in "${extensions[@]}"; do
    wait_for_slot
    scan_one "$base_url" "$ext" &
  done

done < "$url_file"

# Wait for all background jobs to finish
wait

log_output "\n${GREEN}✅ Scan complete.${RESET}"


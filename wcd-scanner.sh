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
echo -e "${BOLD} Cookie + Custom Reflection & Cache Detection (with ?hackmeN & random paths)${RESET}"
echo -e "     (Only reflected responses will be shown unless --vv is used)"
echo -e "${CYAN}------------------------------------------------------------------${RESET}"

show_help() {
  echo -e "${BOLD}Usage:${RESET} $0 --urlfile <file_with_urls> --cookie \"name=value; other=xyz\" [options]"
  echo
  echo "Options:"
  echo "  --urlfile <file>         File containing base URLs (one per line)"
  echo "  --cookie <string>        Cookie string (e.g., \"name=value; other=xyz\")"
  echo "  --customreflection <str> Add custom reflection string to check"
  echo "  --output <file>          Save results to file"
  echo "  --proxy <url>            Send requests via proxy (e.g., http://127.0.0.1:8080)"
  echo "  --vv                     Verbose output (shows all requests sent)"
  echo "  -h, --help               Show this help message"
  exit 0
}

# Defaults
verbose=false
proxy_arg=""

# Parse CLI arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --urlfile) url_file="$2"; shift 2 ;;
        --cookie) cookie_input="$2"; shift 2 ;;
        --customreflection) custom_reflection="$2"; shift 2 ;;
        --output) output_file="$2"; shift 2 ;;
        --proxy) proxy_arg="--proxy $2"; shift 2 ;;
        --vv) verbose=true; shift ;;
        -h|--help) show_help ;;
        *) echo -e "${RED}Unknown parameter: $1${RESET}"; exit 1 ;;
    esac
done

# Validate required inputs
if [[ -z "$url_file" || -z "$cookie_input" ]]; then
  show_help
fi

# Output logger
log_output() {
  echo -e "$1"
  if [[ -n "$output_file" ]]; then
    echo -e "$1" >> "$output_file"
  fi
}

# Resource extensions
extensions=("css" "js" "jpg" "avif" "html")

# URL-decode function
urldecode() {
  printf '%b' "${1//%/\\x}"
}

# Extract and decode cookie values
declare -a reflect_values
IFS=';' read -ra pairs <<< "$cookie_input"
for pair in "${pairs[@]}"; do
  val=$(echo "$pair" | cut -d= -f2- | xargs)
  decoded_val=$(urldecode "$val")
  if [[ -n "$decoded_val" ]]; then
    reflect_values+=("$decoded_val")
  fi
done

# Add custom reflection string if provided
if [[ -n "$custom_reflection" ]]; then
  reflect_values+=("$custom_reflection")
fi

counter=0

# Read each base URL from file
while IFS= read -r base_url || [[ -n "$base_url" ]]; do
  [[ -z "$base_url" ]] && continue

  # Remove trailing slash to avoid //
  base_url="${base_url%/}"

  for ext in "${extensions[@]}"; do
    counter=$((counter + 1))

    # Generate random filename
    rand_name=$(head -c 6 /dev/urandom | base64 | tr -dc 'a-z0-9' | head -c 6)
    path="/${rand_name}.${ext}"

    # Build full URL with cache buster
    full_url="${base_url}${path}?hackme${counter}"

    # Send requests & capture status
    status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "User-Agent: WCDScanner" -H "Cookie: $cookie_input" $proxy_arg "$full_url")
    headers=$(curl -s -D - -o /dev/null -H "User-Agent: WCDScanner" -H "Cookie: $cookie_input" $proxy_arg "$full_url")
    body=$(curl -s -H "User-Agent: WCDScanner" -H "Cookie: $cookie_input" $proxy_arg "$full_url")

    # If --vv, log every request sent
    if $verbose; then
      if [[ "$status_code" =~ ^2 ]]; then
        log_output "${GREEN}[REQ]${RESET} $full_url  (${BOLD}Status:${RESET} ${GREEN}$status_code${RESET})"
      elif [[ "$status_code" =~ ^3 ]]; then
        log_output "${YELLOW}[REQ]${RESET} $full_url  (${BOLD}Status:${RESET} ${YELLOW}$status_code${RESET})"
      else
        log_output "${RED}[REQ]${RESET} $full_url  (${BOLD}Status:${RESET} ${RED}$status_code${RESET})"
      fi
    fi

    # Check for reflection
    reflected=false
    reflection_output=""
    for val in "${reflect_values[@]}"; do
      if echo "$body" | grep -Fq "$val"; then
        reflection_output+="  ${YELLOW}⚠️  Reflected in response body:${RESET} $val\n"
        reflected=true
      fi
    done

    # Only show output if reflection is found OR verbose mode is enabled
    if [[ "$reflected" == true || "$verbose" == true ]]; then
      if [[ "$reflected" == true ]]; then
        log_output "\n${GREEN}[+]${RESET} ${BOLD}Testing URL:${RESET} $full_url"
        log_output "$reflection_output"
      fi

      cache_headers=$(echo "$headers" | grep -iE '^Cache-Control:|^Age:|^X-Cache:|^CF-Cache-Status:' | head -n 10)
      if [[ -n "$cache_headers" ]]; then
        log_output "  ${CYAN}🧠 Cache headers found:${RESET}"
        while IFS= read -r line; do
          log_output "   - $line"
        done <<< "$cache_headers"
      else
        if [[ "$reflected" == true ]]; then
          log_output "  ${RED}❌ No cache-related headers found.${RESET}"
        fi
      fi
    fi
  done

done < "$url_file"

log_output "\n${GREEN}✅ Scan complete.${RESET}"

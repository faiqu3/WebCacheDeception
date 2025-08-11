# Web Cache Deception (WCD) Scanner

## 📌 Description
The **Web Cache Deception (WCD) Scanner** is a penetration testing utility that helps detect websites vulnerable to **Web Cache Deception attacks**.

It checks for:

- **Reflected cookies** – when a cookie value is echoed back in a page’s response and could be stored in a public cache.
- **Custom reflection points** – when user-controlled input or sensitive data such as API keys appears in the response and might be cached, as demonstrated in [PortSwigger’s WCD lab](https://portswigger.net/web-security/web-cache-deception/lab-wcd-exploiting-path-mapping).
  
These flaws are dangerous because if sensitive data is cached publicly, other users (or attackers) could retrieve it later.

---

## 🚀 Features
- Detects **Web Cache Deception** vulnerabilities.
- Identifies **reflected cookies** and **custom reflected data** in cacheable responses.
- **Verbose mode** (`--vv`) to display every request sent.
- **Proxy support** (`--proxy`) to route traffic through Burp Suite, OWASP ZAP, etc.
- **Color-coded output** for quick reading.
- Supports **custom wordlists** for URLs and file extensions.

---

## 🛠 Usage

### Basic Scan

```
Usage: ./wcd-scanner.sh --urlfile <file_with_urls> --cookie "<name=value; ...>" [options]

Required:
  --urlfile <file>         File containing target base URLs (one per line)
  --cookie "<cookie_str>"  Cookie string to send with each request

Options:
  --customreflection <str> Custom string to search for in response body
  --output <file>          Save results to a log file
  --proxy <url>            Route requests via a proxy (e.g., http://127.0.0.1:8080)
  --vv                     Verbose mode — logs every request and status code
  -h, --help               Show this help message
```

## 📖 Examples

### 1️. Basic scan
  Scans all URLs listed in urls.txt using the provided session cookie.
  Searches for reflected cookies in the HTTP response that might be cached by the server.

```bash
./wcd-scanner.sh --urlfile urls.txt --cookie "session=abc123"
```

### 2. Scan with custom reflection detection

Search for a specific keyword (e.g., api_key) in the cached response body.
```
./wcd-scanner.sh --urlfile urls.txt --cookie "session=abc123" --customreflection "api_key"
```
## 📹 Proof of Concept Video
[![Watch the video](https://img.youtube.com/vi/uI3CiuiqODY/0.jpg)](https://youtu.be/uI3CiuiqODY)

### 3. Verbose mode (show all HTTP requests)

Log every request sent and its status code.
```
./wcd-scanner.sh --urlfile urls.txt --cookie "session=abc123" --vv
```
### 4. Route through proxy (e.g., Burp Suite)

Send traffic via a proxy for deeper inspection.
```
./wcd-scanner.sh --urlfile urls.txt --cookie "session=abc123" --proxy http://127.0.0.1:8080
```
### 5. Combine options (verbose + proxy + output file)

Run a detailed scan, route via proxy, and save results to a file.
```
./wcd-scanner.sh --urlfile urls.txt --cookie "session=abc123" --vv --proxy http://127.0.0.1:8080 --output results.log
```

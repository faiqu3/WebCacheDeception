# 🧨 Web Cache Deception Scanner (WCD)

A **lightweight, signal-focused Web Cache Deception scanner** written in Bash, designed for **bug bounty hunting** and **real-world testing**.

This tool automatically appends static-looking paths to sensitive endpoints, checks for **reflection of attacker-controlled values**, and confirms whether the response is **cacheable** — the exact combo required to identify exploitable **Web Cache Deception (WCD)** issues.

Built with:

* parallel execution
* clean output (no noise)
* proxy/Burp support
* safe interruption handling

---

## ✨ Features

* 🔥 **Web Cache Deception focused**
* 🎯 Detects **ONLY attacker-controlled reflection** (no cookie false positives)
* 🧠 Outputs results **only when reflection + cache headers exist**
* 🚀 Parallel scanning with configurable threads
* 🧪 Appends multiple static extensions (`.css`, `.js`, `.png`, etc.)
* 🔐 Cookie-based authentication support
* 🧰 Proxy support (Burp / ZAP)
* 🛑 Skips redirects (3xx) by default
* 🧹 Deduplicated cache headers
---

## 📦 Installation

### Requirements

* Bash (≥ 4)
* `curl`
* Standard Unix tools (`grep`, `sed`, `awk`, `mktemp`)

### Clone

```bash
git clone https://github.com/yourusername/web-cache-deception.git
cd web-cache-deception
chmod +x wcd_stag.sh
```

---

## 🚀 Usage

### Basic scan

```bash
./wcd_stag.sh \
  --urlfile urls.txt \
  --cookie "session=abc123" \
  --reflection WCD_TEST
```

### With Burp proxy

```bash
./wcd_stag.sh \
  --urlfile urls.txt \
  --cookie "session=abc123" \
  --reflection WCD_TEST \
  --proxy http://127.0.0.1:8080
```

### Increase threads

```bash
./wcd_stag.sh \
  --urlfile urls.txt \
  --cookie "session=abc123" \
  --reflection WCD_TEST \
  -t 20
```

### Match specific response codes only

```bash
./wcd_stag.sh \
  --urlfile urls.txt \
  --cookie "session=abc123" \
  --reflection WCD_TEST \
  -mc 200
```

---

## 🧾 Input Format

### `urls.txt`

```text
https://example.com/account
https://example.com/profile/settings
https://example.com/admin/dashboard
```

The tool will:

* strip query parameters (`?x=y`)
* normalize trailing slashes
* append static paths safely

---

## 📤 Output Example

```text
[🔥 WCD HIT] https://example.com/account/ab12cd.css?hackme12345
    Reflected: WCD_TEST
    Cache headers:
      - cache-control: max-age=300
      - age: 120
```

> ⚠️ Only **real, exploitable signals** are printed.
> No reflection → no output.
> No cache headers → no output.

---

## 🧠 How Detection Works

For each base URL:

1. Appends static-looking paths (`/random.css`, `/random.js`, etc.)
2. Sends **one HTTP request per path**
3. Checks response body for the reflection value
4. Confirms cacheability via headers:

   * `cache-control`
   * `age`
   * `etag`
   * `expires`
   * `x-cache`
5. Reports **only when both conditions are true**

This minimizes noise and speeds up triage.

---

## ⚙️ Option Reference

| Option                    | Description                                |
| ------------------------- | ------------------------------------------ |
| `--urlfile FILE`          | File containing base URLs                  |
| `--cookie STRING`         | Cookie header (auth only)                  |
| `--reflection STRING`     | Attacker-controlled value to detect        |
| `--proxy URL`             | HTTP proxy (Burp/ZAP)                      |
| `-t, --thread N`          | Parallel requests per target (default: 10) |
| `-mc, --match-code CODES` | Only test specific HTTP status codes       |
| `--output FILE`           | Save output to file                        |
| `--vv`                    | Verbose/debug mode                         |
| `-h, --help`              | Show help                                  |

## 😊 For Contribution 
Connect with me: [imfaiqu3](https://x.com/imfaiqu3)



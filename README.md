# 🕸️ WCD - web cache deception scanner

A **reflection-driven Web Cache Deception scanner** that verifies whether **user-controlled values are reflected** in responses and, **only if reflected**, checks whether that response is **cacheable**.

This tool is built to answer one real question:

> “Is my reflected data being cached and served back?”

If the answer is yes — that’s impact.

---

## 🚀 What This Tool Actually Does

This scanner:

* Injects **random static file paths** (`.css`, `.js`, `.png`, etc.)
* Appends **unique `?hackmeXXXX` parameters**
* Sends **authenticated requests using cookies**
* Searches responses for **user-supplied reflection values**
* **Only when reflection is detected**:

  * Extracts cache-related headers
  * Highlights possible cache exposure
* Runs in **parallel** for speed
* Skips redirects (3xx) by default to reduce noise

No reflection → no cache analysis → no false hype.

---

## 🎯 Use Cases

### 🧑‍💻 Bug Bounty Hunters

* Prove **user-controlled reflection**
* Confirm whether reflected content is cacheable
* Find **real Web Cache Deception bugs**
* Generate clean, defensible reports

### 🏢 Companies & Security Teams

* Detect reflection + caching combos
* Validate CDN and proxy behavior
* Prevent sensitive data from being cached
* Reduce real-world data exposure risk

---

## 📦 Requirements

* Bash
* curl
* Standard GNU utilities
* Linux / macOS

---

## 📥 Installation

```bash
git clone https://github.com/yourusername/reflection-cache-scanner.git
cd reflection-cache-scanner
chmod +x scanner.sh
```

---

## 🛠️ Usage

### 🔴 Basic Scan (Reflection Is REQUIRED)

```bash
./scanner.sh \
  --urlfile urls.txt \
  --cookie "session=abc123" \
  --reflection "abc123"
```

> Without `--reflection`, the tool cannot determine whether data is reflected or cached.

---

### Multiple Reflection Values

```bash
./scanner.sh \
  --urlfile urls.txt \
  --cookie "session=abc123" \
  --reflection "abc123,email,@example.com"
```

Each value is tested independently.

---

### Match Specific Status Codes

(Default behavior skips 3xx responses)

```bash
./scanner.sh \
  --urlfile urls.txt \
  --cookie "session=abc123" \
  -mc 200,404
```

---

### Increase Speed (Parallel Requests)

```bash
./scanner.sh \
  --urlfile urls.txt \
  --cookie "session=abc123" \
  --reflection "abc123" \
  -t 20
```

---

### Save Output

```bash
./scanner.sh \
  --urlfile urls.txt \
  --cookie "session=abc123" \
  --output findings.txt
```

---

### Proxy Traffic (Burp / ZAP)

```bash
./scanner.sh \
  --urlfile urls.txt \
  --cookie "session=abc123" \
  --reflection "abc123" \
  --proxy http://127.0.0.1:8080
```

---

### Very Verbose Mode

```bash
./scanner.sh \
  --urlfile urls.txt \
  --cookie "session=abc123" \
  --reflection "abc123" \
  --vv
```

---

## ⚙️ Option Reference

| Flag                | Description                                |
| ------------------- | ------------------------------------------ |
| `--urlfile`         | File with target base URLs                 |
| `--cookie`          | Cookie header for authenticated testing    |
| `--reflection`      | **Required** value(s) to detect reflection |
| `--output`          | Save output to file                        |
| `--proxy`           | HTTP proxy                                 |
| `-mc, --match-code` | Only test specific HTTP status codes       |
| `-t, --thread`      | Parallel requests (default: 10)            |
| `--vv`              | Very verbose logging                       |
| `-h, --help`        | Show help                                  |

---

## 🧠 How Detection Works

1. Base URL is normalized (no query / fragment)
2. Random static paths are appended:

   ```
   /x7k9q2.css?hackme3482
   ```
3. Authenticated request is sent
4. Response body is searched for reflection values
5. **If reflection is found**:

   * Cache headers are extracted
   * Cache exposure is highlighted
6. If no reflection → request is ignored

This ensures **high signal, low noise**.

---

## 📄 Example Finding

```text
[+] URL: https://target.com/a1b2c3.css?hackme1029
    Status: 200
    Reflections found:
      - Reflected: abc123
    Cache-Relevant Headers:
      - Cache-Control: public, max-age=3600
      - Age: 87
```

Reflection + cache headers = 🚨 potential WCD.

---

## 🧠 Bounty Hunter Notes

* Always verify with a **fresh unauthenticated request**
* Focus on:

  * `Cache-Control: public`
  * `Age` headers
  * CDN-backed targets
* Reflected secrets = higher impact
* Static extension paths often bypass cache rules

---

## 🛡️ Remediation (For Companies)

* Disable caching on authenticated routes
* Use:

  ```
  Cache-Control: private, no-store
  ```
* Review CDN edge rules
* Ensure reflected user data is never cached

---

## ⚠️ Legal Disclaimer

Scan only:

* Assets you own
* Assets you’re authorized to test
* Public bounty scope targets

Use responsibly.

---

## ⭐ Final Words

This tool is about **proof**, not guesses.
Reflection first. Cache second. Impact always.

If it helps you win:
⭐ the repo
Use it smart
Hack ethically 🔥

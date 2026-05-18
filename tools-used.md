# Tools Used in Recon Workflows

Reference documentation for the core tools used in external attack surface enumeration and offensive security workflows. Each section covers the tool's role in the recon chain, key flags, and practical usage notes.

---

## Nmap

**Role in workflow:** Port scanning and service version detection. Entry point for external recon — determines what is running on a target before any application-layer testing begins.

**Repository:** https://github.com/nmap/nmap  
**Documentation:** https://nmap.org/book/

### Key flags

| Flag | Purpose |
|------|---------|
| `-sV` | Service version detection |
| `-sC` | Default NSE script scan |
| `-T4` | Aggressive timing (faster, more detectable) |
| `-p-` | All 65535 ports |
| `--open` | Only show open ports |
| `-Pn` | Skip host discovery (treat as up) |
| `-oA` | Output in all formats (normal, XML, grepable) |

### Workflow position

Nmap runs early — before Nuclei and FFUF — because service discovery informs which templates and wordlists are relevant. Running Nuclei against all templates on a target running only a static nginx server wastes time. Knowing the target runs Apache Tomcat on port 8080 directs template selection precisely.

```bash
# Standard external recon scan
nmap -sV -sC -T4 --open -p 80,443,8080,8443,3000,22,21,25,6379,9200 target.com -oA nmap-out

# Full port scan (slower, more thorough)
nmap -sV -T3 -p- target.com -oA nmap-full
```

---

## Nuclei

**Role in workflow:** Template-based vulnerability detection. Runs structured checks against web applications, APIs, and network services using a community-maintained template library.

**Repository:** https://github.com/projectdiscovery/nuclei  
**Templates:** https://github.com/projectdiscovery/nuclei-templates

### Key flags

| Flag | Purpose |
|------|---------|
| `-u` | Single URL target |
| `-l` | List of URLs from file |
| `-t` | Template path or directory |
| `-severity` | Filter by severity (info, low, medium, high, critical) |
| `-tags` | Filter by tag (cve, misconfig, exposure, etc.) |
| `-o` | Output file |
| `-rate-limit` | Requests per second (be conservative on live targets) |

### Template categories

The Nuclei template library is organised by category:

- `cves/` — CVE-tagged checks for specific software versions
- `exposures/` — exposed files, panels, and sensitive endpoints
- `misconfigurations/` — security header issues, CORS, CSRF
- `technologies/` — fingerprinting running software stacks
- `vulnerabilities/` — general web vulnerability patterns

### Workflow position

Nuclei runs after Nmap identifies live services. Technology detection templates run first to fingerprint the stack, then CVE and vulnerability templates run against confirmed technologies. This reduces false positives and template noise significantly.

```bash
# Technology fingerprinting first
nuclei -u https://target.com -t /templates/technologies/ -o tech.txt

# Then targeted CVE scanning
nuclei -u https://target.com -t /templates/cves/ -severity high,critical -o cves.txt

# Full scan with rate limiting (respectful of target)
nuclei -u https://target.com -t /templates/ -severity medium,high,critical -rate-limit 50
```

---

## FFUF

**Role in workflow:** Web fuzzer for directory enumeration, endpoint discovery, and parameter fuzzing. Surfaces paths and parameters that are not linked from the application's visible interface.

**Repository:** https://github.com/ffuf/ffuf

### Key flags

| Flag | Purpose |
|------|---------|
| `-u` | Target URL with `FUZZ` placeholder |
| `-w` | Wordlist path |
| `-mc` | Match HTTP status codes |
| `-fc` | Filter status codes |
| `-fs` | Filter by response size |
| `-H` | Custom header |
| `-o` | Output file |
| `-of` | Output format (json, csv, md) |
| `-t` | Threads (default 40) |
| `-rate` | Requests per second limit |

### Wordlist recommendations

- `SecLists/Discovery/Web-Content/common.txt` — general directory discovery
- `SecLists/Discovery/Web-Content/raft-large-words.txt` — large coverage
- `SecLists/Discovery/Web-Content/api/objects.txt` — API endpoint discovery
- `SecLists/Discovery/Web-Content/burp-parameter-names.txt` — parameter fuzzing

### Workflow position

FFUF runs after Nuclei's initial surface scan. Directories and endpoints discovered by FFUF feed into SQLMap for injection testing and into manual testing for logic flaw assessment. Filter response sizes carefully — a single incorrect filter removes valid findings.

```bash
# Directory discovery
ffuf -u https://target.com/FUZZ -w common.txt -mc 200,301,302,403 -o dirs.json -of json

# Filter noise by response size
ffuf -u https://target.com/FUZZ -w common.txt -mc 200 -fs 1234

# Subdomain fuzzing
ffuf -u https://FUZZ.target.com -w subdomains.txt -mc 200,301 -H "Host: FUZZ.target.com"
```

---

## SQLMap

**Role in workflow:** Automated SQL injection detection and database extraction. Tests specific parameters identified during recon for SQL injection vulnerabilities.

**Repository:** https://github.com/sqlmapproject/sqlmap

### Key flags

| Flag | Purpose |
|------|---------|
| `-u` | Target URL with parameter |
| `--data` | POST data |
| `-r` | Load request from file |
| `--batch` | Non-interactive mode (auto-accept defaults) |
| `--level` | Test depth 1-5 (default 1) |
| `--risk` | Risk level 1-3 (default 1) |
| `--dbms` | Force database type |
| `--dbs` | Enumerate databases |
| `--dump` | Dump table data |
| `--tamper` | Tamper scripts for WAF bypass |

### Usage notes

SQLMap with `--level=3 --risk=2` runs significantly more tests and may cause unintended side effects on databases (slow queries, log entries, potential data modification at `--risk=3`). Use conservative settings for initial detection:

```bash
# Initial detection pass (conservative)
sqlmap -u "https://target.com/item?id=1" --batch --level=1 --risk=1

# Deeper testing once injection confirmed
sqlmap -u "https://target.com/item?id=1" --batch --level=3 --risk=2 --dbs

# From Burp Suite request file
sqlmap -r saved-request.txt --batch --dbms=mysql
```

Always run SQLMap only against parameters you have explicit authorisation to test.

---

## Supporting tools

### Subfinder
Passive subdomain enumeration using multiple data sources.  
`https://github.com/projectdiscovery/subfinder`

### Amass
Active and passive subdomain enumeration with DNS resolution.  
`https://github.com/owasp-amass/amass`

### httpx
Fast HTTP probing to check which subdomains are live and serving web content.  
`https://github.com/projectdiscovery/httpx`

---

## Tool chain summary

```
subfinder / amass    →  subdomains-live.txt
                              ↓
nmap -sV -sC         →  open ports + service versions
                              ↓
nuclei -t /templates →  CVEs + misconfigurations + exposures
                              ↓
ffuf -w wordlist     →  hidden paths + parameters + endpoints
                              ↓
sqlmap --batch       →  SQL injection validation
                              ↓
AI analysis layer    →  risk scoring + clustered findings + report
```

Each stage produces structured output that the next stage consumes. The chain is only as good as the authorisation behind it — always confirm scope before running any tool.

# Recon Workflow Example

A step-by-step walkthrough of a complete external recon workflow against a single target domain. This example assumes you have explicit written authorisation to test the target.

---

## Target scope

```
Target: example-bugbounty-target.com
Scope:  *.example-bugbounty-target.com
Out of scope: payment.example-bugbounty-target.com
```

Always confirm scope before running any tools. Out-of-scope findings should not be tested even if discovered during recon.

---

## Stage 1 — Subdomain discovery

Goal: map the full external attack surface before scanning anything.

```bash
# Passive enumeration
subfinder -d example-bugbounty-target.com -silent -o subdomains-passive.txt

# Active enumeration
amass enum -d example-bugbounty-target.com -o subdomains-active.txt

# Combine and deduplicate
cat subdomains-passive.txt subdomains-active.txt | sort -u > subdomains-all.txt

# Probe for live hosts
cat subdomains-all.txt | httpx -silent -o subdomains-live.txt
```

**What to look for:**
- `dev.`, `staging.`, `api.`, `admin.`, `internal.` subdomains
- Subdomains resolving to third-party services (potential subdomain takeover candidates)
- Subdomains returning non-standard HTTP status codes

---

## Stage 2 — Port and service discovery

Goal: identify what is actually running on each live host, not just what is on port 80/443.

```bash
# Quick scan of common ports on live hosts
nmap -iL subdomains-live.txt -sV -T4 --open -p 21,22,23,25,80,443,3000,3306,5432,6379,8080,8443,9200,27017 -oA nmap-services

# Full port scan on high-value targets
nmap -sV -sC -T4 -p- high-value-target.example.com -oA nmap-full
```

**What to look for:**
- Databases exposed without authentication (Redis, MongoDB, Elasticsearch on default ports)
- Development servers on port 3000, 8080, 8443
- SSH on non-standard ports
- Services running outdated software versions (check against CVE databases)

---

## Stage 3 — Nuclei template scanning

Goal: run structured vulnerability checks against all live web surfaces.

```bash
# Scan all live subdomains with high/critical severity templates
nuclei -l subdomains-live.txt -t /templates -severity medium,high,critical -o nuclei-findings.txt

# Target-specific technology detection first (reduces noise)
nuclei -l subdomains-live.txt -t /templates/technologies/ -o tech-fingerprint.txt

# Then run technology-specific CVE templates
nuclei -l subdomains-live.txt -t /templates/cves/ -severity high,critical -o nuclei-cves.txt
```

**What to look for:**
- Exposed admin panels (`.../admin`, `.../phpmyadmin`, `.../wp-admin`)
- Exposed config and environment files (`.env`, `config.php`, `web.config`)
- `.git` directory exposure
- CVE matches against identified software versions
- Misconfigured security headers (CSP, CORS, HSTS)

---

## Stage 4 — Directory and path fuzzing

Goal: discover endpoints that are not linked from the application surface.

```bash
# Standard directory fuzzing
ffuf -u https://target.example.com/FUZZ \
     -w /wordlists/SecLists/Discovery/Web-Content/common.txt \
     -mc 200,201,301,302,403 \
     -o ffuf-dirs.json \
     -of json

# API endpoint discovery
ffuf -u https://api.example.com/FUZZ \
     -w /wordlists/SecLists/Discovery/Web-Content/api/objects.txt \
     -mc 200,201,400,401,403 \
     -H "Content-Type: application/json"

# Parameter fuzzing on known endpoints
ffuf -u "https://target.example.com/search?FUZZ=test" \
     -w /wordlists/SecLists/Discovery/Web-Content/burp-parameter-names.txt \
     -mc 200 -fs 1234
```

**What to look for:**
- Backup files (`.bak`, `.old`, `.zip`, `.tar.gz`)
- Version control directories (`.git`, `.svn`)
- Documentation endpoints (`/swagger`, `/api-docs`, `/graphql`)
- Debug endpoints (`/debug`, `/test`, `/health` with verbose output)

---

## Stage 5 — SQL injection validation

Goal: test parameters discovered during fuzzing for SQL injection vectors.

```bash
# Basic detection on GET parameter
sqlmap -u "https://target.example.com/page?id=1" \
       --batch \
       --level=2 \
       --risk=1 \
       --dbms=mysql

# POST parameter testing
sqlmap -u "https://target.example.com/login" \
       --data="username=test&password=test" \
       --batch \
       --level=2

# From a saved request file (Burp export)
sqlmap -r request.txt --batch --level=3 --risk=2
```

**Important:** Only test parameters you have explicit authorisation to test. SQLMap with high risk/level settings can cause unintended damage to databases. Use `--level=1 --risk=1` for initial detection passes.

---

## Stage 6 — AI-assisted prioritisation

After stages 1-5, you typically have:
- A list of live subdomains (dozens to hundreds)
- Nmap service scan results across all of them
- Nuclei findings (potentially hundreds of template matches)
- FFUF output showing exposed paths
- SQLMap results on tested parameters

Raw output from these tools requires manual triage to separate high-signal findings from noise. An AI analysis layer helps by:

1. **Clustering related findings** — an exposed `.git` + an admin panel + a CORS misconfiguration on the same subdomain represents a higher-risk target than three isolated findings on different hosts
2. **Prioritising by exploitability** — a Nuclei CVE match on a service version does not always mean the service is exploitable; contextual analysis helps separate confirmed issues from theoretical ones
3. **Generating report scaffolding** — producing initial finding descriptions, severity assessments, and remediation recommendations that the pentester reviews and refines

The AI does not replace manual exploitation or report writing. It reduces the triage and documentation overhead so the pentester can focus on validation.

---

## Output structure

After a complete workflow run, organise findings as:

```
recon-output/
  subdomains-live.txt         # confirmed live hosts
  nmap-services.xml           # service scan results
  nuclei-findings.txt         # template matches
  ffuf-dirs.json              # directory fuzzing output
  sqli-results/               # sqlmap output per target
  analysis-report.md          # AI-assisted triage summary
```

This structure makes it straightforward to hand off to a reporting tool or write up findings manually.

---

## Responsible disclosure notes

If you discover a valid vulnerability:
1. Stop testing that specific issue once confirmed — do not attempt to expand access
2. Document the finding with sufficient reproduction steps
3. Report through the programme's designated disclosure channel
4. Do not share findings publicly until the programme confirms remediation or grants permission

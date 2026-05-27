# phantomred-recon-workflows

![Last Commit](https://img.shields.io/github/last-commit/adityamachiraju4/phantomred-recon-workflows)
![Stars](https://img.shields.io/github/stars/adityamachiraju4/phantomred-recon-workflows?style=flat)
![License](https://img.shields.io/badge/license-MIT-blue)
![Topics](https://img.shields.io/badge/topics-recon%20%7C%20nuclei%20%7C%20ffuf%20%7C%20bug%20bounty-red)

Documented recon workflows, tool chaining patterns, and attack surface enumeration methodology for bug bounty hunters and pentesters. Maintained by [PhantomRed](https://www.phantomred.com) — autonomous AI penetration testing.

---

## Quick Start

```bash
# Clone
git clone https://github.com/adityamachiraju4/phantomred-recon-workflows.git
cd phantomred-recon-workflows

# Make scripts executable
chmod +x scripts/*.sh

# Run full recon pipeline against a target
./scripts/full-recon-pipeline.sh target.com
```

**Requirements:** `subfinder`, `assetfinder`, `amass`, `dnsx`, `httpx`, `nuclei`, `ffuf`, `jq`

```bash
# Install all tools via Go
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/tomnomnom/assetfinder@latest
go install github.com/owasp-amass/amass/v4/...@master
go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/ffuf/ffuf/v2@latest
```

---

## Pipeline Architecture

![PhantomRed Autonomous Recon Pipeline](screenshots/recon-pipeline.png)


```
Target domain
     │
     ▼
┌─────────────────────────────────────────────┐
│  PHASE 1 — Passive Subdomain Enumeration    │
│  subfinder + assetfinder + amass (passive)  │
│  → subs-all.txt  (merged, deduplicated)     │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│  PHASE 2 — DNS Validation                   │
│  dnsx (A, CNAME, MX resolution)             │
│  → dns-valid.txt + potential-takeovers.txt  │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│  PHASE 3 — Live Host Probing                │
│  httpx (HTTP/HTTPS + tech detection)        │
│  → live-hosts.txt                           │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│  PHASE 4 — Vulnerability Scanning           │
│  nuclei (exposures, CVEs, misconfigs)       │
│  → nuclei-triage.txt (severity-sorted)      │
└──────────────────────┬──────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────┐
│  PHASE 5 — Content Discovery                │
│  ffuf (directory + backup + param fuzzing)  │
│  → ffuf/*.json                              │
└─────────────────────────────────────────────┘
```

---

## Scripts

| Script | Description | Usage |
|--------|-------------|-------|
| `scripts/full-recon-pipeline.sh` | End-to-end pipeline: enum → DNS → httpx → nuclei → ffuf | `./scripts/full-recon-pipeline.sh target.com` |
| `scripts/subdomain-recon.sh` | Subdomain enumeration + DNS validation + CNAME takeover detection | `./scripts/subdomain-recon.sh target.com` |
| `scripts/nuclei-pipeline.sh` | Severity-gated Nuclei scan + triage + delta detection | `./scripts/nuclei-pipeline.sh live-hosts.txt` |
| `scripts/ffuf-content-discovery.sh` | Directory, backup file, and parameter fuzzing | `./scripts/ffuf-content-discovery.sh live-hosts.txt` |

---

## One-liners

```bash
# Fastest live subdomain sweep
subfinder -d target.com -silent | httpx -silent | tee live-hosts.txt

# Nuclei scan on live hosts (high/critical only)
cat live-hosts.txt | nuclei -severity high,critical -rl 50 -silent

# Full passive enum → merge → DNS validate
subfinder -d target.com -silent > sf.txt & \
assetfinder --subs-only target.com > af.txt & \
amass enum -passive -d target.com > am.txt & \
wait && cat sf.txt af.txt am.txt | sort -u | dnsx -silent > dns-valid.txt

# CNAME takeover detection
dnsx -l subs.txt -cname -silent | grep -E 'amazonaws|github\.io|heroku|azurewebsites'

# Nuclei + jq triage (sort findings by severity)
nuclei -l live.txt -json -o results.json && \
jq -r '[.info.severity,.host,.info.name] | @tsv' results.json | sort -k1

# Net-new findings across re-scans
comm -13 <(sort previous-triage.txt) <(sort current-triage.txt)
```

---

## Workflow Docs

| File | Description |
|------|-------------|
| `workflows/subdomain-recon-methodology.md` | Passive vs active recon, tool selection, pipeline sequencing |
| `workflows/nuclei-template-guide.md` | Template categories, rate limiting, false positive reduction |
| `workflows/attack-surface-checklist.md` | Pre-engagement checklist for bug bounty and pentest scope |
| `tools-used.md` | Tool reference with install commands and key flags |
| `workflow-example.md` | Step-by-step recon walkthrough with sample output |

---

## Tool Reference

### Subdomain Enumeration

| Tool | Mode | Best For |
|------|------|----------|
| `subfinder` | Passive | Fast CT log + passive DNS enumeration |
| `assetfinder` | Passive | crt.sh, Facebook CT, VirusTotal |
| `amass` | Passive + Active | ASN-based discovery + DNS brute force |
| `shuffledns` | Active | Permutation brute force with custom wordlists |

### Validation & Probing

| Tool | Purpose |
|------|---------|
| `dnsx` | DNS resolution, CNAME detection, takeover identification |
| `httpx` | Live HTTP/HTTPS probing, tech fingerprinting, status codes |

### Vulnerability Scanning

| Tool | Purpose |
|------|---------|
| `nuclei` | Template-based scanning (CVEs, exposures, misconfigs) |
| `ffuf` | Directory fuzzing, parameter discovery, vhost fuzzing |
| `sqlmap` | SQL injection detection and exploitation |

---

## Operational Notes

**Passive before active.** Always exhaust passive sources (subfinder, assetfinder, amass passive) before running active DNS brute force or HTTP probing. Passive recon leaves zero footprint.

**Always httpx-filter.** Never run Nuclei or FFUF directly against raw subdomain lists. httpx filters out dead hosts, parking pages, and NXDOMAIN records — reducing noise and preventing wasted scan cycles.

**Rate limit everything.** Use `-rl 50 -bulk-size 25` on Nuclei and `-rate 100` on FFUF as baseline limits. Reduce further on private programs and targets with explicit rate-limit policies.

**Delta over re-scan.** Save each run's output in a date-stamped directory. Use `comm -13` to surface only net-new findings instead of re-triaging your entire known subdomain inventory on every run.

**CNAME before HTTP.** Run `dnsx -cname` on your full subdomain list before httpx. Dangling CNAMEs pointing to deprovisioned cloud services are claimable and consistently pay well on bug bounty programs.

---

## Related Resources

- [PhantomRed — Autonomous Penetration Testing](https://www.phantomred.com/autonomous-penetration-testing.html)
- [Subdomain Recon Automation Guide](https://www.phantomred.com/subdomain-recon-automation.html)
- [Nuclei Automation Workflows](https://www.phantomred.com/nuclei-automation-workflows.html)
- [Nmap + Nuclei + FFUF Automation](https://www.phantomred.com/nmap-nuclei-ffuf-automation.html)
- [Recon Workflow Generator](https://www.phantomred.com/recon-workflow-generator.html)
- [Reconnaissance Automation for Bug Bounty](https://www.phantomred.com/reconnaissance-automation-for-bug-bounty.html)

---

## Responsible Use

All techniques documented here are for use on targets you own or have **explicit written authorisation** to test. Unauthorised scanning is illegal in most jurisdictions. Bug bounty programs define their own scope — always read the programme rules before running any tools.

---

## License

MIT — see [LICENSE](LICENSE)

---

*Maintained by [PhantomRed](https://www.phantomred.com) — autonomous AI penetration testing by [PhredSec Technologies Private Limited](https://www.phantomred.com/about.html)*

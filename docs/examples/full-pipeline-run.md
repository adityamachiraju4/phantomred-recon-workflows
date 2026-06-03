# Example: Full Pipeline Run

An annotated end-to-end run of the recon-to-validation pipeline against a single target.
This is the complete chain from `docs/workflows.md`, shown as one continuous workflow.

> **Authorization first.** Every active phase below generates traffic against the target.
> Run only against assets you own or are explicitly authorized to test, and respect the
> scope and rate limits of any bug bounty program.

## Setup

```bash
TARGET="example.com"
mkdir -p run/$TARGET
cd run/$TARGET
```

## Phase 1 — Subdomain Enumeration

```bash
subfinder -d $TARGET -all -silent -o subfinder.txt
amass enum -passive -d $TARGET -o amass.txt
assetfinder --subs-only $TARGET > assetfinder.txt

# Merge into one unique list
cat subfinder.txt amass.txt assetfinder.txt | sort -u > all-subs.txt
echo "Discovered $(wc -l < all-subs.txt) unique subdomains"
```

## Phase 2 — HTTP Probing

```bash
cat all-subs.txt \
  | httpx -silent -status-code -title -tech-detect -follow-redirects \
  -o live-hosts.txt

awk '{ print $1 }' live-hosts.txt > urls.txt
echo "$(wc -l < urls.txt) live hosts"
```

## Phase 3 — Service Scanning

```bash
# Extract IPs and scan top ports with version detection
nmap -iL urls.txt -T4 --top-ports 1000 -sV --open -oN nmap.txt
```

## Phase 4 — Vulnerability Detection

```bash
nuclei -update-templates
nuclei -list urls.txt \
  -severity medium,high,critical \
  -tags cve,misconfig,exposure \
  -rate-limit 50 \
  -o nuclei-findings.txt
```

## Phase 5 — Content Discovery

```bash
ffuf -u "https://$TARGET/FUZZ" \
  -w /opt/wordlists/raft-medium.txt \
  -mc 200,301,403 \
  -o ffuf.json
```

## Phase 6 — Injection Validation

```bash
# Validate a parameter flagged in earlier phases
sqlmap -u "https://$TARGET/item?id=1" --batch --level 2 --risk 2
```

## Result

At the end of the run you have, per target:

- `all-subs.txt` — complete subdomain inventory
- `live-hosts.txt` — live, fingerprinted hosts
- `nmap.txt` — open ports and services
- `nuclei-findings.txt` — triaged vulnerability findings
- `ffuf.json` — discovered content
- SQLMap output — validated injection results

The [PhantomRed platform](https://www.phantomred.com) runs this entire chain
autonomously, correlating and prioritizing the output into a single report.

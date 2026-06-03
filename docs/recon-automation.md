# Recon Automation

This guide covers the reconnaissance half of the pipeline — subdomain enumeration through
HTTP probing — the phases that map a target's attack surface before any scanning begins.

## Goal: Completeness

The single most common cause of an incomplete assessment is an asset that was never
discovered. Everything downstream can only act on what recon finds, so the priority of
this phase is **completeness** — finding every name an attacker could find.

## Subdomain Enumeration

### Passive vs Active

- **Passive** enumeration pulls subdomains from third-party sources (certificate
  transparency logs, search engines, DNS aggregators) without touching the target.
  Stealthy and fast.
- **Active** enumeration queries the target's own DNS directly, including brute-forcing
  candidate names. Finds internal names that exist nowhere public, but generates traffic.

A complete workflow runs both, within an authorized scope.

### The Tools

```bash
TARGET="example.com"
mkdir -p recon/$TARGET

# Passive — Subfinder
subfinder -d $TARGET -all -silent -o recon/$TARGET/subfinder.txt

# Passive + CT logs — Amass
amass enum -passive -d $TARGET -o recon/$TARGET/amass.txt

# Extra source coverage — Assetfinder
assetfinder --subs-only $TARGET > recon/$TARGET/assetfinder.txt

# Merge and deduplicate
cat recon/$TARGET/*.txt | sort -u > recon/$TARGET/all-subs.txt
```

## HTTP Probing

With a merged subdomain list in hand, **httpx** filters it to live hosts and enriches each
with metadata in a single pass:

```bash
cat recon/$TARGET/all-subs.txt \
  | httpx -silent -status-code -title -tech-detect -follow-redirects \
  -o recon/$TARGET/live-hosts.txt
```

The enriched list — live hosts with their status, title, and technology stack — is the
clean handoff to the scanning phases.

## Handoff

```
all-subs.txt (complete)  →  httpx  →  live-hosts.txt (probed & enriched)  →  scanning
```

The full reconnaissance methodology, with explanations, is documented in the
[PhantomRed Academy](https://www.phantomred.com/academy):

- [Subdomain Enumeration Automation](https://www.phantomred.com/subdomain-enumeration-automation.html)
- [httpx Recon Workflows](https://www.phantomred.com/httpx-recon-workflows.html)
- [Attack Surface Reconnaissance](https://www.phantomred.com/attack-surface-reconnaissance.html)

> **Authorization first.** Active enumeration and probing generate traffic to the target.
> Run only against assets you are authorized to test.

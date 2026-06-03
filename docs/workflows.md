# Workflows Overview

This document explains how the individual reconnaissance and scanning tools connect into
a single automated offensive security pipeline. The principle throughout is
**orchestration over individual scanning** — each phase consumes the previous phase's
output, so the chain runs as one workflow rather than a dozen manual steps.

## The Full Chain

```
Subdomain Enumeration
        ↓
   HTTP Probing
        ↓
  Service Scanning
        ↓
Vulnerability Detection
        ↓
 Content Discovery
        ↓
Injection Validation
        ↓
      Report
```

## Phase by Phase

### 1. Subdomain Enumeration

The opening phase discovers every asset the target owns. No single tool sees everything,
so the workflow runs several and merges the results:

- **Subfinder** — fast passive discovery from 40+ sources
- **Amass** — certificate transparency and active enumeration
- **Assetfinder** — lightweight additional source coverage

Output is deduplicated into one subdomain list. See
[recon-automation.md](recon-automation.md) for detail.

### 2. HTTP Probing

A raw subdomain list is noise until you know which hosts are live and what they run.
**httpx** probes the full list, filters to responsive hosts, and fingerprints each one
(status code, title, technology stack). The clean, enriched list feeds everything
downstream.

### 3. Service Scanning

**Nmap** maps open ports and detects service versions on the live hosts, surfacing
services that live off the standard web ports — admin panels, APIs, dev servers.

### 4. Vulnerability Detection

**Nuclei** runs template-based detection across the live URLs, scoped by severity and
tag to keep findings precise. See [nuclei-workflows.md](nuclei-workflows.md).

### 5. Content Discovery

**FFUF** fuzzes live hosts for hidden directories, files, and endpoints that enumeration
and crawling miss — frequently where the interesting attack surface hides.

### 6. Injection Validation

**SQLMap** validates injection findings on flagged parameters, confirming and
characterizing what earlier phases surfaced. This is an active, intrusive phase — run it
only within an authorized scope.

## Why Orchestration Matters

Run these tools by hand and the glue work — exporting, reformatting, re-importing between
each tool — often takes longer than the testing itself, and the result varies every time.
Encoding the pipeline once makes every run identical, complete, and a single command away.

This is the methodology that the [PhantomRed platform](https://www.phantomred.com)
automates end to end.

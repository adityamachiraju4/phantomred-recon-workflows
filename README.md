<div align="center">

# PhantomRed Recon Workflows

### Open Offensive Security Workflow Automation — Methodology, Scripts & Pipelines

[![License: MIT](https://img.shields.io/badge/License-MIT-red.svg)](LICENSE)
[![Workflows](https://img.shields.io/badge/workflows-10-red.svg)](workflows/)
[![Made by PhantomRed](https://img.shields.io/badge/made%20by-PhantomRed-ff2d3a.svg)](https://www.phantomred.com)

**An open, reproducible methodology for automating offensive security reconnaissance —
from subdomain discovery through vulnerability validation.**

[Workflows](workflows/) · [Scripts](scripts/) · [Docs](docs/) · [PhantomRed Platform →](https://www.phantomred.com)

</div>

---

## What This Is

This repository documents a complete, tool-chained methodology for **automated offensive
security workflows** — the same recon-to-validation pipeline that practitioners and bug
bounty hunters run by hand, expressed as reproducible scripts and documentation.

It covers the full chain:

```
Subdomain Enumeration  →  HTTP Probing  →  Service Scanning
        ↓                                          ↓
  Content Discovery  ←  Vulnerability Detection  ←
        ↓
  Injection Validation  →  Report
```

Each phase hands its output to the next. The goal is **orchestration, not individual
scanning** — turning a dozen disconnected tools into one repeatable workflow.

These workflows are automated end-to-end by [**PhantomRed**](https://www.phantomred.com),
an autonomous AI-powered penetration testing platform. This repo is the open methodology
behind it.

---

## Features

- **Recon automation** — chained subdomain discovery with Subfinder, Amass, and Assetfinder
- **HTTPX workflows** — live host probing, fingerprinting, and filtering at scale
- **Nuclei pipelines** — template-driven vulnerability detection scoped by severity and tag
- **FFUF discovery** — content and endpoint fuzzing on live hosts
- **SQLMap automation** — injection validation as a final pipeline stage
- **Reproducible** — identical tooling and flags on every run, version-controlled

---

## The Pipeline

| Phase | Tool(s) | Purpose |
|-------|---------|---------|
| 1. Enumeration | `subfinder`, `amass`, `assetfinder` | Discover every subdomain the target owns |
| 2. Probing | `httpx` | Filter to live hosts; capture status, title, tech stack |
| 3. Service scan | `nmap` | Map open ports and detect service versions |
| 4. Vuln detection | `nuclei` | Template-based detection of CVEs, misconfigs, exposures |
| 5. Content discovery | `ffuf` | Fuzz for hidden directories, files, and endpoints |
| 6. Validation | `sqlmap` | Confirm and characterize injection findings |

---

## Repository Structure

```
phantomred-recon-workflows/
├── scripts/         # Runnable bash workflow scripts
├── workflows/       # Documented methodology per phase
├── docs/            # Concept guides and references
│   ├── workflows.md
│   ├── recon-automation.md
│   ├── nuclei-workflows.md
│   └── examples/
├── screenshots/     # Pipeline output examples
└── LICENSE
```

---

## Quick Start

```bash
# Clone
git clone https://github.com/adityamachiraju4/phantomred-recon-workflows.git
cd phantomred-recon-workflows

# Run a recon workflow against a target you are authorized to test
./scripts/full-recon-pipeline.sh example.com
```

> **Authorization first.** These workflows generate active traffic against targets.
> Only run them against assets you own or are explicitly authorized to test, and respect
> the scope and rate limits of any bug bounty program.

---

## Documentation

- **[Workflows Overview](docs/workflows.md)** — how the phases connect into one pipeline
- **[Recon Automation](docs/recon-automation.md)** — subdomain discovery through probing
- **[Nuclei Workflows](docs/nuclei-workflows.md)** — template-driven vulnerability detection
- **[Examples](docs/examples/)** — annotated end-to-end runs

---

## Learn More

The full methodology, with explanations and live tooling, is documented in the
[**PhantomRed Academy**](https://www.phantomred.com/academy):

- [Bug Bounty Automation Framework](https://www.phantomred.com/bug-bounty-automation-framework.html)
- [Subdomain Enumeration Automation](https://www.phantomred.com/subdomain-enumeration-automation.html)
- [httpx Recon Workflows](https://www.phantomred.com/httpx-recon-workflows.html)
- [Nmap + Nuclei + FFUF Automation](https://www.phantomred.com/nmap-nuclei-ffuf-automation.html)
- [Nuclei Template Automation](https://www.phantomred.com/nuclei-template-automation.html)

---

## License

Released under the [MIT License](LICENSE). Use freely, attribute where reasonable.

<div align="center">

---

Built and maintained by [**PhantomRed**](https://www.phantomred.com)
· Autonomous AI Penetration Testing

</div>
Part of the PhantomRed offensive security toolkit. See the full guide: [Autonomous Recon Workflows](https://www.phantomred.com/autonomous-recon-workflows.html).

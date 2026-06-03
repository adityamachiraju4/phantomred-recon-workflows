# Nuclei Workflows

This guide covers the vulnerability detection phase: running **Nuclei** against the live
hosts surfaced by recon, scoped so that findings stay precise and triageable.

## Two Halves of Nuclei

Nuclei has two distinct concerns, and conflating them is where most setups get noisy:

1. **Execution** — how the scanner runs against targets (this doc)
2. **Templates** — which detection logic runs, kept current and scoped
   (see [Nuclei Template Automation](https://www.phantomred.com/nuclei-template-automation.html))

## Keep Templates Current

CVE templates are added daily. A library that has not been updated silently misses every
newly disclosed vulnerability — the scan looks clean because it never checked.

```bash
nuclei -update
nuclei -update-templates
nuclei -templates-version   # verify before a campaign
```

> In current Nuclei versions, CVE templates live inside the `http/` directory organized
> by year — not a top-level `cves/` folder.

## Scoped Scanning

Severity and tag filtering are the primary levers for signal-to-noise:

```bash
# CVE templates, high and critical only
nuclei -list urls.txt \
  -tags cve \
  -severity high,critical \
  -rate-limit 50 \
  -o cve-findings.txt

# Misconfigurations and exposures, medium and up
nuclei -list urls.txt \
  -tags misconfig,exposure \
  -severity medium,high,critical \
  -o misconfig-findings.txt
```

## Piping From Recon

Nuclei reads from stdin, so it chains directly off httpx:

```bash
cat all-subs.txt \
  | httpx -silent -mc 200 \
  | nuclei -severity medium,high,critical -o findings.txt
```

This one-liner is the recon-to-findings core of the pipeline: enumeration feeds httpx,
httpx feeds Nuclei.

## Structured Output

Use JSON export to feed findings into downstream systems without parsing glue:

```bash
nuclei -list urls.txt -severity high,critical -json-export findings.json
```

## Learn More

- [Nuclei Template Automation](https://www.phantomred.com/nuclei-template-automation.html) — the template ecosystem
- [Nmap + Nuclei + FFUF Automation](https://www.phantomred.com/nmap-nuclei-ffuf-automation.html) — the full scanning chain

> **Authorization first.** Nuclei generates detectable traffic. Scan only authorized targets.

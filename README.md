# phantomred-recon-workflows

Documented recon workflows, tool chaining patterns, and attack surface enumeration methodology for bug bounty hunters and freelance pentesters.

These workflows reflect how modern offensive security automation is structured — from initial domain recon through vulnerability validation. They are tool-agnostic where possible and reference open-source tools throughout.

---

## What autonomous recon automation looks like

Manual recon involves running individual tools, collecting outputs, cross-referencing results, and feeding findings into the next stage by hand. That process works, but it does not scale across large scopes or repeated engagements.

Autonomous recon automation chains these tools in sequence, passes outputs between stages programmatically, and applies analysis at the end. The goal is not to replace the pentester — it is to eliminate the repetitive orchestration work so the pentester can focus on exploitation and reporting.

The full chain looks like this:

```
Target domain
  └─ Subdomain enumeration        (subfinder, amass)
  └─ Port & service discovery     (nmap -sV -sC)
  └─ Web surface scanning         (nuclei -t /templates)
  └─ Directory & path fuzzing     (ffuf -w wordlist.txt)
  └─ Injection testing            (sqlmap --batch)
  └─ AI-assisted analysis         (LLM → risk scoring + report)
```

Each stage feeds the next. Nmap output informs which services Nuclei targets. FFUF output surfaces endpoints that SQLMap tests. The AI layer receives all findings and produces a risk-prioritized summary.

---

## Tools used in this workflow

### Nmap
Port scanning and service version detection. The entry point for any external recon workflow. Key flags:

```bash
nmap -sV -sC -T4 -p- target.com
```

`-sV` detects service versions. `-sC` runs default scripts. `-p-` scans all 65535 ports. Output feeds into service-specific scanning in the next stage.

### Nuclei
Template-based vulnerability scanner with 9000+ community and official templates covering CVEs, misconfigurations, exposed panels, and web application checks.

```bash
nuclei -u https://target.com -t /templates -severity medium,high,critical
```

Templates are organised by technology, CVE, and vulnerability class. Running technology-specific templates against services discovered by Nmap significantly reduces noise.

### FFUF
Fast web fuzzer for directory enumeration, parameter discovery, and virtual host fuzzing.

```bash
ffuf -u https://target.com/FUZZ -w /wordlists/common.txt -mc 200,301,302,403
```

Useful for finding admin panels, backup files, exposed config endpoints, and unlinked paths that do not appear in crawls.

### SQLMap
Automated SQL injection detection and exploitation tool. Runs against specific parameters identified during fuzzing or crawling.

```bash
sqlmap -u "https://target.com/page?id=1" --batch --level=3 --risk=2
```

Should be run only against targets with explicit written authorisation.

---

## Attack surface discovery concepts

Attack surface enumeration starts broader than most teams expect. For a single domain, the real scope includes:

- **Subdomains** — dev, staging, api, admin, and legacy subdomains often have weaker security posture than the main domain
- **Open ports** — services running on non-standard ports are frequently missed in web-only assessments
- **Exposed paths** — admin panels, `.env` files, `.git` directories, backup archives, and config files surfaced by fuzzing
- **Third-party integrations** — JavaScript files often leak API endpoints, cloud storage buckets, and internal service references
- **CVE exposure** — services running outdated software versions with public CVEs and available Nuclei templates

Mapping all of this before starting exploitation gives a significantly clearer picture of where actual risk lives.

---

## AI-assisted analysis in offensive workflows

After the tool pipeline completes, raw findings need to be contextualised. Not all open ports are equally significant. Not all Nuclei template matches indicate exploitable vulnerabilities in every configuration.

An AI analysis layer can:
- Cluster related findings (e.g. an exposed `.git` directory + a misconfigured server header + an outdated CMS version are likely related)
- Assign risk weighting based on finding combinations rather than individual CVSS scores
- Generate remediation context for findings that would otherwise require manual research
- Produce an executive summary from technical outputs

This does not replace manual analysis. It reduces the time spent on initial triage and report scaffolding.

---

## Further reading

For a detailed comparison of [manual vs autonomous penetration testing](https://www.phantomred.com/phantomred-vs-burp-suite.html) approaches and where each fits in a professional workflow, see the PhantomRed documentation.

---

## Files in this repository

| File | Contents |
|------|----------|
| `README.md` | Overview, tool chain, concepts |
| `workflow-example.md` | Step-by-step recon workflow walkthrough |
| `tools-used.md` | Tool reference with flags and use cases |

---

## Responsible use

All techniques documented here are for use on targets you own or have explicit written authorisation to test. Unauthorised scanning is illegal in most jurisdictions. Bug bounty programs define their own scope — always read the programme rules before running any tools.

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

## Autonomous Reconnaissance Workflow

Reconnaissance automation is not about running more tools faster. It is about structuring the workflow so each stage informs the next, reducing the time between initial scope discovery and actionable findings.

A well-structured autonomous reconnaissance workflow covers four distinct phases:

**1. Attack surface discovery**
The first phase maps what actually exists before any vulnerability testing begins. Subdomain enumeration, port scanning, and service fingerprinting define the scope boundary. Many engagements reveal that the real attack surface — staging environments, forgotten API subdomains, legacy admin panels — is significantly larger than the documented asset inventory.

**2. Vulnerability prioritisation**
Not every finding carries equal weight. A Nuclei CVE match on an outdated library version carries different risk than an exposed `.env` file containing live credentials. Effective offensive security workflows rank findings by exploitability and blast radius, not just CVSS score. Combining Nmap service data with Nuclei template matches and FFUF-discovered paths gives a more accurate exploitability picture than any single tool alone.

**3. Offensive security workflows**
The chain — reconnaissance → service detection → template scanning → fuzzing → injection testing — mirrors how a skilled attacker enumerates a target. The difference between manual and automated execution is not the methodology; it is the time taken to complete each stage and the consistency of coverage across large scopes.

**4. AI-assisted analysis**
After the pipeline completes, an AI analysis layer contextualises findings: clustering related issues, generating remediation summaries, and producing an executive overview from raw tool output. This accelerates the triage phase without replacing manual validation of exploitability.

A deeper comparison between manual testing workflows and autonomous pentesting approaches can be found here:
https://www.phantomred.com/phantomred-vs-burp-suite.html

---

## Tools Commonly Used in Pentesting Pipelines

Security professionals draw from a consistent set of tools across reconnaissance, vulnerability scanning, and exploitation phases. Here is where each commonly-used tool fits in an external pentest workflow:

**Nmap** — Port scanning and service version detection. Entry point for any external engagement. Identifies open ports, running services, and software versions that inform all subsequent scanning decisions. Essential for both network-layer recon and feeding service context into Nuclei.

**Nuclei** — Template-based vulnerability scanner maintained by ProjectDiscovery. 9000+ community templates covering CVEs, exposed admin panels, misconfigured services, and web application vulnerability patterns. Runs after Nmap service detection to apply targeted templates against confirmed technologies rather than scanning everything blindly.

**FFUF** — Fast web fuzzer for directory enumeration, parameter discovery, and virtual host identification. Surfaces endpoints and paths that are not linked from the application surface — backup files, development endpoints, exposed configuration files, and unprotected admin interfaces. FFUF output feeds directly into manual testing and SQLMap.

**SQLMap** — Automated SQL injection detection and database extraction. Runs against specific parameters discovered during fuzzing or application crawling. Should always be used with explicit authorisation — `--level` and `--risk` settings should be conservative on production targets.

**Burp Suite** — Industry-standard proxy for manual web application testing. Not an automation tool, but the primary instrument for request interception, manual exploitation, and deep application logic testing. Sits alongside automated tools rather than replacing them — automated recon and manual Burp-based exploitation are complementary workflows, not competing ones.

Each tool addresses a different phase of the engagement. Effective pentest pipelines chain them deliberately rather than running each in isolation.

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

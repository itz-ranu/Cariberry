# Security Policy

## Supported Versions

Cariberry doesn't have versioned releases — it's a single rolling build.
Only the latest code on `main` is supported; if a vulnerability is found,
the fix lands there and there's nothing older to patch separately.

## Reporting a Vulnerability

Please report vulnerabilities privately rather than opening a public issue.

Use GitHub's **Private vulnerability reporting**: go to the
[Security tab](../../security) of this repo and click **Report a
vulnerability**. That opens a private draft advisory only visible to you and
the maintainer, so nothing is disclosed before it's fixed.

*(If that option isn't showing up, it needs to be turned on once under repo
**Settings → Security → Private vulnerability reporting**.)*

What to expect:
- I'll acknowledge your report as soon as I can — this is a solo hobby
  project, so there's no guaranteed SLA, but I'll do my best to respond
  within a few days.
- If it's confirmed, I'll work on a fix and credit you in the advisory
  (unless you'd rather stay anonymous) once it's out.
- If it's declined (not a security issue, out of scope, etc.), I'll explain
  why.

Given the app's actual attack surface — it's a local menu-bar app with no
networking code and no server component — most reports will likely be about
things like unsafe file handling of `rules.json`/`pet.json`, or the
AppleScript-based browser-tab reading. Those are still worth reporting.

---
name: entertainment-scout
description: Find and rank upcoming sports and esports events worth watching using web-accessible schedules, trusted source lists, user preferences, blind-spot scanning, and significance scoring. Use when the user asks what sports/esports to watch, asks for a watch guide for tonight/this weekend/a date range, wants recommendations across favorite and discovery games, wants notable events outside their preferences, or wants short explanations of why live events matter.
---

# Entertainment Scout

## Overview

Create a concise, source-backed watch list for live sports and esports over a user-specified time window. Favor canonical schedule sources first, include a high-threshold blind-spot scan outside saved preferences, then use web search for context that explains why each event is worth attention.

## Workflow

1. Determine the time window and timezone. If the user gives a relative window, convert it to explicit dates. Default to `America/Chicago` from `references/preferences.yaml` when the user does not specify a timezone.
2. Read `references/preferences.yaml` for favorite sports, games, teams, services, and discovery bias.
3. Read `references/sources.yaml` to choose source pages, APIs, and search patterns relevant to the requested sports or games.
4. Gather candidate events from canonical schedule sources before broad web search. Prefer official league/tournament pages, well-maintained specialist schedule pages, and documented APIs.
5. If `blind_spot_scan.enabled` is true, also gather candidates from `blind_spot_sources` and broad notability searches, even when they do not match saved preferences.
6. Normalize each event into one shape: title, category, start time, league/tournament, teams/players, stage, watch availability when found, source links, and confidence.
7. Read `references/scoring.md` and score events by user fit, stakes, cultural significance, quality signals, time fit, source confidence, and blind-spot notability.
8. Use web search for context on top candidates: standings, playoffs, finals, rivalry, prize pool, rankings, roster news, recent storylines, or broader cultural relevance.
9. Return a ranked list with short explanations and links. Separate favorite-fit picks, mainstream-significance picks, and outside-your-usual-lane picks when useful.

## Source Rules

- Cite source links for every recommended event.
- Prefer structured data and official pages over generic snippets.
- Do not treat a single scraped or SEO page as authoritative when an official or specialist schedule source disagrees.
- Do not bypass paywalls, logins, robots restrictions, or anti-abuse systems.
- Call out uncertainty when times, stream availability, teams, or stakes are not confirmed.
- Keep watch recommendations timely; always verify current schedule pages for live or future events.

## Output Shape

Use this compact structure unless the user asks for another format:

```text
Best bets
1. Event title
   Time: Sat, Jul 4, 2026, 7:00 PM CT
   Why care: One or two concrete reasons.
   Fit: Favorite, discovery, or mainstream-significance pick.
   Watch: Network/stream if verified.
   Confidence: High/Medium/Low
   Sources: source links

Also worth a look
- Shorter ranked bullets for lower-confidence or niche events.

Outside your usual lane
- High-threshold blind-spot picks only. Omit this section if nothing clearly notable appears.

Notes
- Mention timezone, excluded sources, or schedule uncertainty.
```

## Updating The Skill

- Add or remove user tastes in `references/preferences.yaml`.
- Add source URLs or search patterns in `references/sources.yaml`.
- Adjust ranking behavior in `references/scoring.md`.
- For a scheduled version, reuse this skill as the recommendation logic and run it from an automation that supplies a fixed time window, such as "next 7 days" every Thursday morning.

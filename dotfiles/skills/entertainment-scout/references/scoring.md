# Entertainment Scout Scoring

Use this rubric to rank candidates. Treat scores as judgment aids, not hard math.

## Dimensions

- User fit: favorite sport/game/team/player/league, preferred region, available watch service.
- Stakes: playoffs, elimination match, final, rivalry, championship implications, qualification implications.
- Quality: strong teams, ranked matchup, star players, current form, expected closeness.
- Cultural significance: major tournament, iconic venue, large prize pool, opening weekend, derby/rivalry, community attention, unusual storyline.
- Time fit: starts soon, fits the requested window, reasonable local viewing time.
- Source confidence: confirmed by official or specialist sources, clear time zone, confirmed teams, verified watch link.
- Discovery value: non-favorite event likely to be enjoyable or important to understand the scene.
- Blind-spot notability: outside saved preferences, but important enough to avoid missing: championship/final, major, playoff, international event, star matchup, rivalry, major community moment, or unusually large audience.

## Default Weighting

Use this order when the user has not specified a preference:

1. Strong user fit with high stakes.
2. Major mainstream or cultural event even outside favorites.
3. Discovery pick with a clear reason.
4. Convenient live timing.
5. Lower-stakes favorite content.

If `discovery_bias` in preferences is:

- `low`: mostly recommend favorites; include only obvious major events outside favorites.
- `medium`: mix favorites and major discovery picks.
- `high`: actively surface unfamiliar but significant events.

## Blind-Spot Scan

When `blind_spot_scan.enabled` is true, reserve a small section for notable events outside the user's saved preferences. Keep the bar high:

- Include the event when a neutral fan could reasonably regret missing it.
- Prefer finals, playoffs, majors, derbies/rivalries, top-ranked matchups, international tournaments, unusually large prize pools, or high-attention cultural moments.
- Exclude routine regular-season games, low-stakes group-stage matches, and niche matches unless there is a specific hook.
- Limit the section to `blind_spot_scan.max_picks`; fewer is better when evidence is weak.
- Label the fit as `outside your usual lane` and explain the concrete notability hook.

## Confidence Labels

- High: official/specialist source confirms event time and participating sides, and context is corroborated.
- Medium: event is confirmed, but stakes, stream, or participants are partially inferred.
- Low: source is weak, date/time is ambiguous, participants are TBD, or only broad web snippets support the pick.

## Explanation Rules

- Say why the event matters in plain language, not just that it is "important."
- Name the concrete hook: elimination, grand final, rivalry, debut, upset risk, title implications, qualification, star matchup, or cultural moment.
- Distinguish facts from inference. Use phrases like "likely" or "appears to" when evidence is incomplete.
- Avoid filler and hype. A good explanation should help the user decide whether to spend time watching.

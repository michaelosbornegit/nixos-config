---
name: sim-debug
description: Interact with the running iOS Simulator programmatically using idb. Use when debugging screens, verifying UI behavior, taking screenshots, tapping, scrolling, or inspecting UI elements in the simulator. Invoke with /sim-debug.
allowed-tools: Bash, Read, Glob, Grep
---

# iOS Simulator Debug Skill

Use idb (Facebook iOS Debug Bridge) to inspect and interact with the booted iPhone simulator.

## Golden Rule: describe-all first, screenshot only when needed

**Before every tap, swipe, or interaction — run `describe-all` to read live state.** It gives you labels, roles, and exact coordinates in one call. Never hardcode coordinates from memory or prior sessions.

**Use `describe-all` (preferred):**
- To verify which screen you're on
- To find element coordinates before tapping
- To confirm a toggle changed state (check role/value)
- After a swipe, to see what's now visible

**Use `screenshot` (fallback) only when:**
- You need to inspect something visual not captured in accessibility data (colors, images, layout rendering)
- `describe-all` output alone isn't enough to confirm what you see

The standard interaction sequence:

```bash
IDB=~/Library/Python/3.9/bin/idb

# Step 1: Read current state with describe-all
$IDB ui describe-all | python3 -c "
import sys, json
items = json.load(sys.stdin)
for i in items:
    label = i.get('AXLabel') or ''
    f = i['frame']
    if label:
        cx = f['x'] + f['width']/2
        cy = f['y'] + f['height']/2
        print(f'  tap({cx:.0f}, {cy:.0f})  {label[:60]}')
"

# Step 2: Act — use coordinates from the output above
$IDB ui tap <cx> <cy>
sleep 0.8

# Step 3: Confirm — use describe-point on the known element (faster than describe-all)
$IDB ui describe-point <cx> <cy>

# Step 4: Screenshot only if you need visual confirmation
# $IDB screenshot /tmp/screen.png
```

---

## Setup: Start idb_companion (if not already running)

Always check if `idb_companion` is running before issuing commands. If not, start it:

```bash
# Check if running
pgrep -x idb_companion

# If not running, start it (nix package, Xcode 16.3 compatible):
/nix/store/fm5b8rvyjw2lr13ln9jgrxfvsq6s4vvj-idb-companion-1.1.8/bin/idb_companion \
  --udid D07F3DFB-A79D-4366-831F-B737FF5561B3 \
  --grpc-port 10882 \
  &>/tmp/idb_companion.log &

# Wait for it to start, then connect:
sleep 3
~/Library/Python/3.9/bin/idb connect localhost 10882
```

> The ObjC `FBProcess` class conflict warning is non-fatal — idb still works correctly.

## Reference

- **idb CLI**: `~/Library/Python/3.9/bin/idb`
- **Booted simulator UDID**: `D07F3DFB-A79D-4366-831F-B737FF5561B3` (iPhone 16 Plus)
- **Device logical resolution**: 430×932 pts — all tap/swipe coordinates use this space
- **Companion port**: 10882

For brevity, set a shell alias in commands below:
```bash
IDB=~/Library/Python/3.9/bin/idb
```

---

## Common Commands

### Take a screenshot
```bash
$IDB screenshot /tmp/screen.png
```
Then use the Read tool to view `/tmp/screen.png`.

### Describe all UI elements (with coordinates)

Use when orienting to a new screen or finding an element's coordinates for the first time (~0.22s).

```bash
$IDB ui describe-all | python3 -c "
import sys, json
items = json.load(sys.stdin)
for i in items:
    label = i.get('AXLabel') or ''
    role = i.get('role', '')
    frame = i['frame']
    if label:
        print(f'{role:20} {label[:50]:50} y={frame[\"y\"]:.0f} x={frame[\"x\"]:.0f} w={frame[\"width\"]:.0f} h={frame[\"height\"]:.0f}')
"
```

### Describe a single point (faster confirmation)

Use after an interaction when you already know the element's coordinates — ~40% faster than `describe-all` (~0.13s).

```bash
$IDB ui describe-point <x> <y>
# With JSON for scripting:
$IDB ui describe-point <x> <y> | python3 -c "
import sys, json
i = json.loads(sys.stdin.read())
print(i.get('AXLabel'), '| value:', i.get('AXValue'), '| enabled:', i.get('enabled'))
"
```

### Tap at coordinates (device logical pts)
```bash
$IDB ui tap <x> <y>
# Example: tap center of screen
$IDB ui tap 215 466
```

### Swipe / scroll (controlled drag — never fling)

Always use `--duration` of **0.8 or higher** and `--delta 5` (small step size) to produce a slow, controlled drag. Without these, idb defaults to a fast gesture that registers as a fling and causes momentum scrolling or unintended navigation.

```bash
# Scroll up a little (slow drag — content moves up)
$IDB ui swipe 215 600 215 400 --duration 0.8 --delta 5

# Scroll up more
$IDB ui swipe 215 700 215 300 --duration 1.0 --delta 5

# Scroll down
$IDB ui swipe 215 300 215 600 --duration 0.8 --delta 5
```

Rules:
- **Always set `--duration`** — minimum 0.8s for a controlled drag
- **Always set `--delta 5`** — smaller steps = smoother, more realistic gesture
- **Keep travel distance moderate** (200–400pts per swipe) — large fast swipes fling
- After each swipe, wait and re-read state before the next action

### Type text
```bash
$IDB ui text "hello world"
```

### Press a key (key codes)
```bash
$IDB ui key 36   # Return/Enter
$IDB ui key 51   # Delete/Backspace
$IDB ui key 53   # Escape
```

### Navigate back (tap back button)
```bash
# Back button is typically at ~x=40, y=165 on most screens
$IDB ui tap 40 165
```

---

## Workflow: Inspect a Screen

1. **describe-all** — read live state and get coordinates
2. **Tap** — use center coords from describe-all output
3. **describe-all again** — confirm navigation/state change
4. **Screenshot** only if visual confirmation is needed

```bash
IDB=~/Library/Python/3.9/bin/idb

# 1. Read current state — always start here
$IDB ui describe-all | python3 -c "
import sys, json
items = json.load(sys.stdin)
for i in items:
    label = i.get('AXLabel') or ''
    f = i['frame']
    if label:
        cx = f['x'] + f['width']/2
        cy = f['y'] + f['height']/2
        print(f'  tap({cx:.0f}, {cy:.0f})  {label[:60]}')
"

# 2. Tap using coordinates from the output above (not from memory)
$IDB ui tap <cx> <cy>
sleep 0.8

# 3. Confirm state changed — describe-point is faster when you know the coordinate
$IDB ui describe-point <cx> <cy>

# 4. Screenshot only if you need to see something visual
# $IDB screenshot /tmp/after.png
```

---

## Workflow: Verify Toggle Behavior

```bash
IDB=~/Library/Python/3.9/bin/idb

# 1. Confirm screen and get live toggle coordinates
$IDB ui describe-all | python3 -c "
import sys, json
items = json.load(sys.stdin)
for i in items:
    role = i.get('role','')
    if 'Check' in role or 'Switch' in role or 'Generic' in role:
        f = i['frame']
        cx = f['x'] + f['width']/2
        cy = f['y'] + f['height']/2
        val = i.get('AXValue', '')
        print(f'  toggle at ({cx:.0f}, {cy:.0f})  value={val}  label={i.get(\"AXLabel\",\"\")}')
"

# 2. Tap toggle off — use coords from above
$IDB ui tap <cx> <cy> && sleep 0.5

# 3. Verify with describe-point — faster since we already know the coordinate
$IDB ui describe-point <cx> <cy> | python3 -c "
import sys, json
i = json.loads(sys.stdin.read())
print(i.get('AXLabel'), '→ value:', i.get('AXValue'), '| enabled:', i.get('enabled'))
"

# 4. Tap toggle on
$IDB ui tap <cx> <cy> && sleep 0.5

# 5. Verify restored — describe-point again
$IDB ui describe-point <cx> <cy> | python3 -c "
import sys, json
i = json.loads(sys.stdin.read())
print(i.get('AXLabel'), '→ value:', i.get('AXValue'), '| enabled:', i.get('enabled'))
"

# 6. Screenshot only if you need visual confirmation of toggle appearance
# $IDB screenshot /tmp/toggle_check.png
```

---

## Workflow: Navigate to a Screen

Most navigation uses the bottom tab bar. Tab bar coordinates (iPhone 16 Plus, 430×932):

| Tab  | Tap coordinates |
|------|----------------|
| Plan | `tap 72 854`   |
| Care | `tap 215 854`  |
| Me   | `tap 358 854`  |

To navigate within the Me stack (from ProfileScreen):
1. Scroll down if needed: `$IDB ui swipe 215 600 215 300 --duration 0.8 --delta 5`
2. Find the item with `describe-all`
3. Tap it by center coordinates
4. Tap back button (`tap 40 165`) to return

---

## Troubleshooting

**"Could not connect to localhost:10882"**
→ idb_companion isn't running. Start it (see Setup above).

**Companion crashes immediately**
→ Check `/tmp/idb_companion.log`. The ObjC class conflict warning is safe to ignore — it's not a crash.

**Tap has no effect**
→ Coordinates may be off. Use `describe-all` to get exact element frames rather than guessing from screenshots.

**`describe-all` shows negative Y values**
→ Element is off-screen (scrolled out of view). Scroll first, then re-run `describe-all`.

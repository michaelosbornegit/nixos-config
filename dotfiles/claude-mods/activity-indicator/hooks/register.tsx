import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Phase } from '../types'

const phase = atom({ plugin: 'activity-indicator', key: 'phase' } as const, 'idle' as Phase)
const title = atom({ plugin: 'activity-indicator', key: 'title' } as const, null as string | null)

// The mod API has no title getter, but the session's transcript records each
// rename as a `custom-title` row (the desktop app's sidebar name) and the
// generated one as `ai-title`. The last of each wins; a custom title beats an
// AI one.
const TITLE_ROW = /"type":"(custom-title|ai-title)","(?:customTitle|aiTitle)":("(?:[^"\\]|\\.)*")/g

// grep's -E spelling of TITLE_ROW: the title rows are pulled out of the
// transcript by grep, so the mod never loads the whole file. A long session's
// transcript runs to megabytes, past what $.fs.read will take (4 MiB).
const TITLE_GREP = '"type":"(custom-title|ai-title)","(customTitle|aiTitle)":"([^"\\\\]|\\\\.)*"'

const titleFrom = (text: string): string | null => {
  let custom: string | null = null
  let ai: string | null = null
  for (const [, kind, json] of text.matchAll(TITLE_ROW)) {
    if (kind === 'custom-title') custom = JSON.parse(json)
    else ai = JSON.parse(json)
  }
  return custom ?? ai
}

// SVG text does not wrap and the frame's width is not known here, so the name
// is word-wrapped by character count: WRAP fits a narrow (~300px) pane at the
// title's size. Past MAX_LINES the last line ends in an ellipsis.
const WRAP = 39
const MAX_LINES = 3

const wrap = (s: string): string[] => {
  const lines: string[] = []
  let line = ''
  for (const word of s.split(/\s+/).filter(Boolean)) {
    // A single word longer than a line is cut to fit.
    const w = word.length > WRAP ? word.slice(0, WRAP - 1) + '…' : word
    if (line && line.length + 1 + w.length > WRAP) {
      lines.push(line)
      line = w
    } else {
      line = line ? `${line} ${w}` : w
    }
  }
  if (line) lines.push(line)
  if (lines.length <= MAX_LINES) return lines
  const last = lines[MAX_LINES - 1]
  return [...lines.slice(0, MAX_LINES - 1), (last.length > WRAP - 1 ? last.slice(0, WRAP - 1) : last) + '…']
}

const xml = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/'/g, '&apos;')

// The name's lines on top, the status row under them. Without a title, a
// single row of status.
const ROW = 32
const PAD = 10
const LINE = 16
const lineCount = (t: string | null) => (t ? wrap(t).length : 0)
// Where the status row's centre sits.
const statusY = (t: string | null) => (t ? PAD + lineCount(t) * LINE + 12 : ROW / 2)
const heightFor = (t: string | null) => (t ? statusY(t) + 17 : ROW)

// Asked of the frame, which the slot caps at its own width. Without an explicit
// width and height the sandboxed frame falls back to the browser's 300x150.
const FRAME_W = 4000

// Pure SMIL in a sandboxed frame, so it animates with no timer. The drawing is
// sized in percentages of that frame, so it spans the pane at any width
// without being scaled. Text a narrow pane has no room for fades out under
// the `fade` mask at the right edge.
const FONT = "font-family='Helvetica Neue,Helvetica,Arial,sans-serif'"

const defs = (h: number, extra: string) => `<defs>
    ${extra}
    <clipPath id='clip'><rect width='100%' height='${h}' rx='8'/></clipPath>
    <linearGradient id='fadeg' x1='0' x2='1'><stop offset='.88' stop-color='#fff'/><stop offset='.98' stop-color='#000'/></linearGradient>
    <mask id='fade'><rect width='100%' height='${h}' fill='url(#fadeg)'/></mask>
  </defs>`

const nameRow = (t: string | null, fill: string) =>
  t
    ? `<text ${FONT} font-size='12.5' font-weight='400' fill='${fill}'>${wrap(t)
        .map((l, i) => `<tspan x='14' y='${PAD + 11 + i * LINE}'>${xml(l)}</tspan>`)
        .join('')}</text>`
    : ''

const bar = (x: number, cy: number, heights: number[], begin: number) => {
  const hs = heights.join(';')
  const ys = heights.map(h => cy - h / 2).join(';')
  return `<rect x='${x}' width='3' rx='1.5' fill='#2f9e55' y='${cy - heights[0] / 2}' height='${heights[0]}'>
    <animate attributeName='height' values='${hs}' dur='1.15s' begin='${begin}s' repeatCount='indefinite'/>
    <animate attributeName='y' values='${ys}' dur='1.15s' begin='${begin}s' repeatCount='indefinite'/>
  </rect>`
}

const orbDef = (id: string, color: string) =>
  `<radialGradient id='${id}'><stop offset='0' stop-color='${color}' stop-opacity='.55'/><stop offset='1' stop-color='${color}' stop-opacity='0'/></radialGradient>`

const orb = (id: string, cy: number, r: number, from: number, to: number, dur: number) =>
  `<circle cy='${cy}' r='${r}' cx='${from}%' fill='url(#${id})'>
    <animate attributeName='cx' values='${from}%;${to}%;${from}%' dur='${dur}s' repeatCount='indefinite' calcMode='spline' keySplines='.45 0 .55 1;.45 0 .55 1' keyTimes='0;.5;1'/>
  </circle>`

const frame = (h: number, body: string) =>
  `<svg xmlns='http://www.w3.org/2000/svg' width='100%' height='${h}' style='display:block'>${body}</svg>`

const working = (t: string | null) => {
  const h = heightFor(t)
  const cy = statusY(t)
  return frame(h, `
  ${defs(h, `<linearGradient id='base' x1='0' x2='1'><stop offset='0' stop-color='#e4f5e6'/><stop offset='.5' stop-color='#d3efd8'/><stop offset='1' stop-color='#e2f3ee'/></linearGradient>
    <linearGradient id='sweep' x1='0' x2='1'><stop offset='0' stop-color='#fff' stop-opacity='0'/><stop offset='.5' stop-color='#fff' stop-opacity='.85'/><stop offset='1' stop-color='#fff' stop-opacity='0'/></linearGradient>
    ${orbDef('og', '#3dbb6c')}${orbDef('ot', '#4fc3c0')}`)}
  <g clip-path='url(#clip)'>
    <rect width='100%' height='${h}' fill='url(#base)'/>
    ${orb('og', h / 2, 60, 8, 62, 7)}
    ${orb('ot', h / 2, 52, 92, 38, 9)}
    <rect y='0' width='24%' height='${h}' fill='url(#sweep)'>
      <animate attributeName='x' values='-24%;100%' dur='2.6s' repeatCount='indefinite'/>
    </rect>
  </g>
  <g mask='url(#fade)'>
    ${nameRow(t, '#1d4f2f')}
    ${bar(14, cy, [4, 14, 7, 16, 4], 0)}
    ${bar(20, cy, [10, 6, 16, 8, 10], 0.15)}
    ${bar(26, cy, [6, 16, 9, 12, 6], 0.3)}
    ${bar(32, cy, [14, 8, 15, 6, 14], 0.45)}
    <text x='44' y='${cy + 4.5}' ${FONT} font-size='12.5' font-weight='500' letter-spacing='.4' fill='#2f7a47'>Working<tspan>.<animate attributeName='fill-opacity' values='0;1;1;0' keyTimes='0;.2;.8;1' dur='1.5s' repeatCount='indefinite'/></tspan><tspan>.<animate attributeName='fill-opacity' values='0;0;1;1;0' keyTimes='0;.2;.4;.8;1' dur='1.5s' repeatCount='indefinite'/></tspan><tspan>.<animate attributeName='fill-opacity' values='0;0;1;1;0' keyTimes='0;.4;.6;.8;1' dur='1.5s' repeatCount='indefinite'/></tspan></text>
  </g>`)
}

const idle = (t: string | null) => {
  const h = heightFor(t)
  const cy = statusY(t)
  return frame(h, `
  ${defs(h, `<linearGradient id='base' x1='0' x2='1'><stop offset='0' stop-color='#fdf0f4'/><stop offset='.5' stop-color='#fbe4ec'/><stop offset='1' stop-color='#fdf0f4'/></linearGradient>`)}
  <g clip-path='url(#clip)'><rect width='100%' height='${h}' fill='url(#base)'/></g>
  <g mask='url(#fade)'>
    ${nameRow(t, '#7d2f4a')}
    <circle cx='22' cy='${cy}' r='4.5' fill='#d9476f'>
      <animate attributeName='opacity' values='1;.55;1' dur='2.4s' repeatCount='indefinite'/>
    </circle>
    <circle cx='22' cy='${cy}' r='4.5' fill='none' stroke='#d9476f' stroke-width='1.5'>
      <animate attributeName='r' values='4.5;11' dur='2.4s' repeatCount='indefinite'/>
      <animate attributeName='opacity' values='.7;0' dur='2.4s' repeatCount='indefinite'/>
    </circle>
    <text x='36' y='${cy + 4.5}' ${FONT} font-size='12.5' font-weight='500' letter-spacing='.4' fill='#b04a6f'>Ready for you</text>
  </g>`)
}

export const register: Register = on => {
  // The transcript is <config>/projects/<dir>/<session id>.jsonl, <dir> being
  // where the session started, which a later /cd or worktree move does not
  // change; so find it by id once and keep the path.
  let transcript: string | null = null
  let isLogged = false

  // A title is set or renamed around a turn, so look again at both ends. The
  // look runs beside the turn, never in front of it, and a failed one keeps
  // the last title seen.
  on('prompt.submit', async ($, e, next) => {
    await update($, phase, () => 'working' as Phase)
    void (async () => {
      try {
        if (!transcript) {
          const base = ((await $.env.get('CLAUDE_CONFIG_DIR')) ?? `${await $.env.get('HOME')}/.claude`) + '/projects'
          const file = `${await $.session.id()}.jsonl`
          for (const dir of await $.fs.list(base)) {
            if (dir.kind === 'dir' && (await $.fs.exists(`${base}/${dir.name}/${file}`))) {
              transcript = `${base}/${dir.name}/${file}`
              break
            }
          }
        }
        if (!transcript) return
        // grep exits 1 when nothing matches yet (an untitled session).
        const { exitCode, stdout } = await $.process.run(['grep', '-a', '-o', '-E', TITLE_GREP, transcript])
        const t = exitCode === 0 ? titleFrom(stdout) : null
        if (t) await update($, title, () => t)
      } catch (err) {
        if (!isLogged) $.ui.log(`activity-indicator: no session title (${err})`, { to: 'debug' })
        isLogged = true
      }
    })()
    return next(e)
  })

  on('turn.start', async ($, e, next) => {
    await update($, phase, () => 'working' as Phase)
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    await update($, phase, () => 'idle' as Phase)
    void (async () => {
      if (!transcript) return
      try {
        const { exitCode, stdout } = await $.process.run(['grep', '-a', '-o', '-E', TITLE_GREP, transcript])
        const t = exitCode === 0 ? titleFrom(stdout) : null
        if (t) await update($, title, () => t)
      } catch {}
    })()
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const isWorking = (await read($, phase)) === 'working'
    const t = await read($, title)
    const { Box, Svg } = $.ui.resolve(e)

    return (
      <Box>
        <Svg
          source={isWorking ? working(t) : idle(t)}
          alt={(t ? t + ': ' : '') + (isWorking ? 'Claude is working' : 'Ready for you')}
          width={FRAME_W}
          height={heightFor(t)}
          isInteractive
        />
      </Box>
    )
  })
}

import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Phase } from '../types'

const phase = atom({ plugin: 'activity-indicator', key: 'phase' } as const, 'idle' as Phase)

const H = 32
// Asked of the frame, which the slot caps at its own width. Without an explicit
// width and height the sandboxed frame falls back to the browser's 300x150.
const FRAME_W = 4000

// Pure SMIL in a sandboxed frame, so it animates with no timer. The drawing is
// sized in percentages of that frame, so it spans the pane at any width
// without being scaled. The label and bars hang off a nested <svg x='50%'>.
const FONT = "font-family='Helvetica Neue,Helvetica,Arial,sans-serif'"

const bar = (x: number, heights: number[], begin: number) => {
  const hs = heights.join(';')
  const ys = heights.map(h => (H - h) / 2).join(';')
  return `<rect x='${x}' width='3' rx='1.5' fill='#2f9e55' y='${(H - heights[0]) / 2}' height='${heights[0]}'>
    <animate attributeName='height' values='${hs}' dur='1.15s' begin='${begin}s' repeatCount='indefinite'/>
    <animate attributeName='y' values='${ys}' dur='1.15s' begin='${begin}s' repeatCount='indefinite'/>
  </rect>`
}

const orbDef = (id: string, color: string) =>
  `<radialGradient id='${id}'><stop offset='0' stop-color='${color}' stop-opacity='.55'/><stop offset='1' stop-color='${color}' stop-opacity='0'/></radialGradient>`

const orb = (id: string, r: number, from: number, to: number, dur: number) =>
  `<circle cy='16' r='${r}' cx='${from}%' fill='url(#${id})'>
    <animate attributeName='cx' values='${from}%;${to}%;${from}%' dur='${dur}s' repeatCount='indefinite' calcMode='spline' keySplines='.45 0 .55 1;.45 0 .55 1' keyTimes='0;.5;1'/>
  </circle>`

const frame = (body: string) =>
  `<svg xmlns='http://www.w3.org/2000/svg' width='100%' height='${H}' style='display:block'>${body}</svg>`

const working = () => frame(`
  <defs>
    <linearGradient id='base' x1='0' x2='1'><stop offset='0' stop-color='#e4f5e6'/><stop offset='.5' stop-color='#d3efd8'/><stop offset='1' stop-color='#e2f3ee'/></linearGradient>
    <linearGradient id='sweep' x1='0' x2='1'><stop offset='0' stop-color='#fff' stop-opacity='0'/><stop offset='.5' stop-color='#fff' stop-opacity='.85'/><stop offset='1' stop-color='#fff' stop-opacity='0'/></linearGradient>
    ${orbDef('og', '#3dbb6c')}${orbDef('ot', '#4fc3c0')}
    <clipPath id='clip'><rect width='100%' height='${H}' rx='8'/></clipPath>
  </defs>
  <g clip-path='url(#clip)'>
    <rect width='100%' height='${H}' fill='url(#base)'/>
    ${orb('og', 56, 8, 62, 7)}
    ${orb('ot', 48, 92, 38, 9)}
    <rect y='0' width='24%' height='${H}' fill='url(#sweep)'>
      <animate attributeName='x' values='-24%;100%' dur='2.6s' repeatCount='indefinite'/>
    </rect>
  </g>
  <svg x='50%' y='0' width='1' height='${H}' overflow='visible'>
    ${bar(-78, [6, 18, 9, 22, 6], 0)}
    ${bar(-71, [14, 8, 22, 10, 14], 0.15)}
    ${bar(-64, [8, 22, 12, 16, 8], 0.3)}
    ${bar(-57, [18, 10, 20, 8, 18], 0.45)}
    <text x='-40' y='21' ${FONT} font-size='14' font-weight='600' letter-spacing='.6' fill='#24613a'>Working<tspan>.<animate attributeName='fill-opacity' values='0;1;1;0' keyTimes='0;.2;.8;1' dur='1.5s' repeatCount='indefinite'/></tspan><tspan>.<animate attributeName='fill-opacity' values='0;0;1;1;0' keyTimes='0;.2;.4;.8;1' dur='1.5s' repeatCount='indefinite'/></tspan><tspan>.<animate attributeName='fill-opacity' values='0;0;1;1;0' keyTimes='0;.4;.6;.8;1' dur='1.5s' repeatCount='indefinite'/></tspan></text>
  </svg>`)

const idle = () => frame(`
  <defs>
    <linearGradient id='base' x1='0' x2='1'><stop offset='0' stop-color='#fdf0f4'/><stop offset='.5' stop-color='#fbe4ec'/><stop offset='1' stop-color='#fdf0f4'/></linearGradient>
    <clipPath id='clip'><rect width='100%' height='${H}' rx='8'/></clipPath>
  </defs>
  <g clip-path='url(#clip)'><rect width='100%' height='${H}' fill='url(#base)'/></g>
  <svg x='50%' y='0' width='1' height='${H}' overflow='visible'>
    <circle cx='-70' cy='16' r='5' fill='#d9476f'>
      <animate attributeName='opacity' values='1;.55;1' dur='2.4s' repeatCount='indefinite'/>
    </circle>
    <circle cx='-70' cy='16' r='5' fill='none' stroke='#d9476f' stroke-width='1.5'>
      <animate attributeName='r' values='5;15' dur='2.4s' repeatCount='indefinite'/>
      <animate attributeName='opacity' values='.7;0' dur='2.4s' repeatCount='indefinite'/>
    </circle>
    <text x='-52' y='21' ${FONT} font-size='14' font-weight='600' letter-spacing='.6' fill='#a8476a'>Ready for you</text>
  </svg>`)

export const register: Register = on => {
  on('prompt.submit', async ($, e, next) => {
    await update($, phase, () => 'working' as Phase)
    return next(e)
  })

  on('turn.start', async ($, e, next) => {
    await update($, phase, () => 'working' as Phase)
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    await update($, phase, () => 'idle' as Phase)
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const isWorking = (await read($, phase)) === 'working'
    const { Box, Svg } = $.ui.resolve(e)

    return (
      <Box>
        <Svg
          source={isWorking ? working() : idle()}
          alt={isWorking ? 'Claude is working' : 'Ready for you'}
          width={FRAME_W}
          height={H}
          isInteractive
        />
      </Box>
    )
  })
}

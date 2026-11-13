import { expect, test } from 'claude-code/testing'

const BAND = {
  plugin: 'activity-indicator',
  component: 'AbovePrompt',
  requestId: 'abovePrompt',
  props: {
    hasSurvey: false,
    isWorking: false,
    maxRows: 10,
    bodyColumns: 80,
    scroll: { offset: 0, bodyRows: 9 },
    view: {},
  },
} as const

test('the band draws an Svg on desktop', async ($, on) => {
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })

  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  const svg = await ui.find({ type: 'Svg' })
  expect(svg).toBeTruthy()
  await ui.unmount()
})

const task = (id: string, status: string) => ({ id, type: 'shell', status, description: `task ${id}` })

const endTurn = async ($: any, on: any, tasks: ReturnType<typeof task>[], agentId?: string) => {
  await $.classic.Stop({ stop_hook_active: false, background_tasks: tasks })
  await $.turn.complete({ answer: '', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer', ...(agentId ? { agentId } : {}) })
}

const altOf = async ($: any) => {
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  const svg: any = await ui.find({ type: 'Svg' })
  await ui.unmount()
  return svg.props.alt as string
}

for (const surface of ['desktop'] as const) {
  test(`stays green on ${surface} while background work runs`, async ($, on) => {
    on('session.start', (_, e) => ({ cwd: e.cwd }))
    on('classic.Stop', () => ({}))
    on('turn.complete', () => ({ text: '' }))
    await $.session.start({ cwd: '/', surface, isInteractive: true })

    await endTurn($, on, [task('a', 'running'), task('b', 'running'), task('c', 'completed')])
    expect(await altOf($)).toBe('2 running in background')

    await endTurn($, on, [])
    expect(await altOf($)).toBe('Ready for you')
  })
}

test('a subagent ending its turn does not flip the band to idle', async ($, on) => {
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('turn.start', (_, e) => ({ turnId: e.turnId }))
  on('turn.complete', () => ({ text: '' }))
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })

  await $.turn.start({ turnId: 't1' } as any)
  await $.turn.complete({ answer: '', durationMs: 1, isAborted: false, turnId: 't2', reason: 'answer', agentId: 'sub1' })
  expect(await altOf($)).toBe('Claude is working')
})

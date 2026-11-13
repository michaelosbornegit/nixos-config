import { expect, mock, test } from 'claude-code/testing'

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

test('a spawned session shows the title its first prompt carries', async ($, on) => {
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('classic.UserPromptSubmit', () => ({}))
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })

  await $.classic.UserPromptSubmit({ prompt: 'go', session_title: 'Rust engine', transcript_path: '/t/s.jsonl' })
  expect(await altOf($)).toBe('Rust engine: Ready for you')
})

test('a new session picks up its title once the transcript holds one', async ($, on) => {
  const clock = mock.clock(on)
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('classic.UserPromptSubmit', () => ({}))
  on('prompt.submit', (_, e) => ({ text: e.text }))
  // The title row is written partway into the first turn.
  let isWritten = false
  on('process.run', () => ({
    value: isWritten
      ? { exitCode: 0, stdout: '"type":"ai-title","aiTitle":"Parser speed"\n', stderr: '', isStdoutTruncated: false, isStderrTruncated: false }
      : { exitCode: 2, stdout: '', stderr: 'no such file', isStdoutTruncated: false, isStderrTruncated: false },
  }))
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })

  await $.classic.UserPromptSubmit({ prompt: 'go', transcript_path: '/t/new.jsonl' })
  await $.prompt.submit({ text: 'go' } as any)
  expect(await altOf($)).toBe('Claude is working')

  isWritten = true
  await clock.advance(5000)
  await clock.advance(10)
  expect(await altOf($)).toBe('Parser speed: Claude is working')
})

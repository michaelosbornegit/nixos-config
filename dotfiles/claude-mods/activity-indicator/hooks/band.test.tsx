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

const altOf = async ($: any) => {
  const ui = await $.ui.mount({ ...BAND, surface: 'desktop' })
  const svg: any = await ui.find({ type: 'Svg' })
  await ui.unmount()
  return svg.props.alt as string
}

const done = { stderr: '', isStdoutTruncated: false, isStderrTruncated: false }

// The engine beneath the mod: prompts enter, turns end, and each tool answers
// with the record a background launch returns.
const engine = async ($: any, on: any) => {
  mock.clock(on)
  on('ui.log', () => ({ value: undefined }))
  on('session.start', (_: any, e: any) => ({ cwd: e.cwd }))
  on('prompt.submit', (_: any, e: any) => ({ text: e.text }))
  on('turn.start', (_: any, e: any) => ({ turnId: e.turnId }))
  on('turn.complete', () => ({ text: '' }))
  on('tool.call', (_: any, e: any) => {
    if (e.tool === 'Bash') return { result: { stdout: '', stderr: '', interrupted: false, backgroundTaskId: e.description } }
    if (e.tool === 'Agent') return { result: { status: 'async_launched', agentId: 'agent1', description: 'a', prompt: 'p', outputFile: '/o' } }
    if (e.tool === 'Monitor') return { result: { taskId: e.description, timeoutMs: 1000, persistent: e.persistent } }
    return { result: {} }
  })
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })
}

const endTurn = ($: any) => $.turn.complete({ answer: '', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })

const notify = ($: any, id: string, status?: string) =>
  $.prompt.submit({
    text: `<task-notification>\n<task-id>${id}</task-id>\n<tool-use-id>toolu_1</tool-use-id>\n${status ? `<status>${status}</status>\n` : ''}<summary>done</summary>\n</task-notification>`,
    wait: false,
    origin: { kind: 'task-notification' },
  })

test('stays green while background work runs, until each one reports its end', async ($, on) => {
  await engine($, on)
  await $.tool.call({ tool: 'Bash', command: 'sleep 99', description: 'b1', run_in_background: true })
  await $.tool.call({ tool: 'Agent', description: 'a', prompt: 'p', subagent_type: 'Explore', run_in_background: true })
  await endTurn($)
  expect(await altOf($)).toBe('2 running in background')

  await notify($, 'b1', 'completed')
  await endTurn($)
  expect(await altOf($)).toBe('1 running in background')

  await notify($, 'agent1', 'failed')
  await endTurn($)
  expect(await altOf($)).toBe('Ready for you')
})

test("a monitor's interim events keep it counted; a persistent one never counts", async ($, on) => {
  await engine($, on)
  await $.tool.call({ tool: 'Monitor', description: 'm1', command: 'tail -f x', timeout_ms: 1000 })
  await $.tool.call({ tool: 'Monitor', description: 'm2', command: 'tail -f y', timeout_ms: 1000, persistent: true })
  await endTurn($)
  expect(await altOf($)).toBe('1 running in background')

  await notify($, 'm1')
  await endTurn($)
  expect(await altOf($)).toBe('1 running in background')
})

test('stopping a task stops counting it', async ($, on) => {
  await engine($, on)
  await $.tool.call({ tool: 'Bash', command: 'sleep 99', description: 'b1', run_in_background: true })
  await $.tool.call({ tool: 'TaskStop', task_id: 'b1' })
  await endTurn($)
  expect(await altOf($)).toBe('Ready for you')
})

test('a subagent ending its turn does not flip the band to idle', async ($, on) => {
  await engine($, on)
  await $.turn.start({ turnId: 't1' } as any)
  await $.turn.complete({ answer: '', durationMs: 1, isAborted: false, turnId: 't2', reason: 'answer', agentId: 'sub1' })
  expect(await altOf($)).toBe('Claude is working')
})

test('a new session picks up its title once the transcript holds one', async ($, on) => {
  const clock = mock.clock(on)
  mock.env(on, { HOME: '/h' })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('prompt.submit', (_, e) => ({ text: e.text }))
  on('session.id', () => ({ value: 'sid' }))
  on('fs.list', () => ({ value: [{ name: 'proj', kind: 'dir' }] }))
  // The transcript is written partway into the first turn, its title row with it.
  let isWritten = false
  on('fs.exists', () => ({ value: isWritten }))
  on('process.run', () => ({ value: { exitCode: 0, stdout: '"type":"ai-title","aiTitle":"Parser speed"\n', ...done } }))
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })

  await $.prompt.submit({ text: 'go', wait: false, origin: { kind: 'composer' } } as any)
  expect(await altOf($)).toBe('Claude is working')

  isWritten = true
  await clock.advance(5000)
  await clock.advance(10)
  expect(await altOf($)).toBe('Parser speed: Claude is working')
})

export type Phase = 'idle' | 'working'

// The live context window's fill, once a response of it reported one.
export type ContextFill = { tokens: number; window: number; percent: number }

declare module 'claude-code' {
  interface PluginState {
    'activity-indicator': { phase: Phase; title: string | null; tasks: readonly string[]; context: ContextFill | null }
  }
}

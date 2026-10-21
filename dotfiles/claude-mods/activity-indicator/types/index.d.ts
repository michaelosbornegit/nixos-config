export type Phase = 'idle' | 'working'

declare module 'claude-code' {
  interface PluginState {
    'activity-indicator': { phase: Phase }
  }
}

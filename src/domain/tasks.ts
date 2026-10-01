import type { LearningTask, ModelEvent, Mode, SourceSnapshot } from './types';
export type MockScenario = 'success' | 'rate-limit' | 'partial' | 'hold';
export interface ProviderAdapter {
  analyze(
    source: SourceSnapshot,
    mode: Mode,
    signal: AbortSignal,
  ): AsyncIterable<ModelEvent>;
}
export function applyEvent(
  task: LearningTask,
  event: ModelEvent,
): LearningTask {
  if (['completed', 'failed', 'cancelled', 'partial'].includes(task.status))
    return task;
  if (event.type === 'stream')
    return { ...task, status: 'streaming', output: task.output + event.text };
  if (event.type === 'complete') return { ...task, status: 'completed' };
  if (event.type === 'partial')
    return { ...task, status: 'partial', error: event.reason };
  return { ...task, status: 'failed', error: event.code };
}
function waitForAbort(signal: AbortSignal): Promise<void> {
  return new Promise((resolve) => {
    if (signal.aborted) resolve();
    else signal.addEventListener('abort', () => resolve(), { once: true });
  });
}
/** Emits actual local fixture events; no network, timers or claimed AI quality. */
export function mockProvider(scenario: MockScenario): ProviderAdapter {
  return {
    async *analyze(source, mode, signal) {
      if (signal.aborted) return;
      if (scenario === 'rate-limit') {
        yield { type: 'fail', code: 'RATE_LIMIT · 本地模拟限流，未发送请求' };
        return;
      }
      const labels: Record<Mode, string> = {
        translate: '译文示例',
        grammar: '语法界面示例',
        reading: '读音界面示例',
        page: '当前样本页分段示例',
      };
      yield { type: 'stream', text: `${labels[mode]}（mock，非模型结果）\n` };
      if (scenario === 'hold') {
        await waitForAbort(signal);
        return;
      }
      for (const paragraph of source.quote.exact.split('\n')) {
        if (signal.aborted) return;
        yield {
          type: 'stream',
          text: `原文：${paragraph}\n这是一条自制界面测试结果；真实翻译、语法及假名尚未接入。\n`,
        };
      }
      if (signal.aborted) return;
      yield scenario === 'partial'
        ? { type: 'partial', reason: '本地模拟：后一片段失败，已有结果保留' }
        : { type: 'complete' };
    },
  };
}

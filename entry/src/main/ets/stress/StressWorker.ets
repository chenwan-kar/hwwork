import { taskpool } from '@kit.ArkTS';

@Concurrent
export function busyLoop(durationMs: number, workerId: number): number {
  let count: number = 0;
  const endTime: number = Date.now() + durationMs;
  let lastReportTime: number = Date.now();
  while (Date.now() < endTime) {
    count++;
    if (Date.now() - lastReportTime >= 500) {
      try {
        taskpool.Task.sendData(workerId, count);
      } catch (e) {
      }
      lastReportTime = Date.now();
    }
  }
  return count;
}

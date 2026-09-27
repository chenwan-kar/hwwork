import { taskpool } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { busyLoop } from '../stress/StressWorker';

const STRESS_DURATION_MS: number = 10000;
const STRESS_THREAD_COUNT: number = 4;
const COUNTDOWN_SECONDS: number = 10;

class TaskItem {
  name: string = '';
  done: boolean = false;

  constructor(name: string, done: boolean) {
    this.name = name;
    this.done = done;
  }
}

@Entry
@Component
struct Index {
  @State tasks: TaskItem[] = [
    new TaskItem('读 OpenHarmony 概览', false),
    new TaskItem('搭好 DevEco 环境', false),
    new TaskItem('完成一次 CLI 构建', false)
  ];
  @State stressRunning: boolean = false;
  @State stressRemaining: number = COUNTDOWN_SECONDS;
  @State stressLiveCount: number = 0;
  @State stressResultCount: number = 0;
  private threadCounts: number[] = [0, 0, 0, 0];
  private finishedThreadCount: number = 0;
  private countdownTimerId: number = -1;

  private doneCount(): number {
    return this.tasks.filter((task: TaskItem) => task.done).length;
  }

  private stressIcon(): string {
    if (this.stressRunning) {
      return '\u25CF';
    }
    return this.stressResultCount > 0 ? '\u2714' : '\u25CB';
  }

  private stressIconColor(): string {
    if (this.stressRunning) {
      return '#0C59D8';
    }
    return this.stressResultCount > 0 ? '#0C59D8' : '#B0B0B0';
  }

  private stressTitle(): string {
    if (this.stressRunning) {
      return `压测中… 已累加 ${this.stressLiveCount} 次`;
    }
    if (this.stressResultCount > 0) {
      return `压测完成，共累加 ${this.stressResultCount} 次`;
    }
    return `CPU 压测（${STRESS_THREAD_COUNT} 线程 × ${COUNTDOWN_SECONDS} 秒）`;
  }

  private sumThreadCounts(): number {
    let sum: number = 0;
    for (let i: number = 0; i < this.threadCounts.length; i++) {
      sum += this.threadCounts[i];
    }
    return sum;
  }

  private finishStress(): void {
    clearInterval(this.countdownTimerId);
    this.stressResultCount = this.sumThreadCounts();
    this.stressRunning = false;
  }

  private startStress(): void {
    this.stressRunning = true;
    this.stressRemaining = COUNTDOWN_SECONDS;
    this.stressLiveCount = 0;
    this.stressResultCount = 0;
    this.finishedThreadCount = 0;
    this.threadCounts = [0, 0, 0, 0];
    this.countdownTimerId = setInterval(() => {
      if (this.stressRemaining > 0) {
        this.stressRemaining--;
      }
    }, 1000);
    for (let i: number = 0; i < STRESS_THREAD_COUNT; i++) {
      const task: taskpool.Task = new taskpool.Task(busyLoop, STRESS_DURATION_MS, i);
      task.onReceiveData((workerId: number, count: number): void => {
        this.threadCounts[workerId] = count;
        this.stressLiveCount = this.sumThreadCounts();
      });
      taskpool.execute(task).then((result: Object) => {
        const finalCount: number = result as number;
        this.threadCounts[i] = finalCount;
        this.stressLiveCount = this.sumThreadCounts();
        this.finishedThreadCount++;
        if (this.finishedThreadCount >= STRESS_THREAD_COUNT) {
          this.finishStress();
        }
      }).catch((err: BusinessError) => {
        this.finishedThreadCount++;
        if (this.finishedThreadCount >= STRESS_THREAD_COUNT) {
          this.finishStress();
        }
      });
    }
  }

  aboutToDisappear(): void {
    clearInterval(this.countdownTimerId);
  }

  build() {
    Column() {
      Column() {
        Text('HarmonySchedLab')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
        Text('第 4 周 · 调度压测')
          .fontSize(16)
          .fontColor('#8C8C8C')
          .margin({ top: 4 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 12 }) {
        ForEach(this.tasks, (task: TaskItem, index: number) => {
          Row() {
            Text(task.done ? '\u2714' : '\u25CB')
              .fontSize(22)
              .fontColor(task.done ? '#0C59D8' : '#B0B0B0')
              .margin({ right: 12 })
            Text(task.name)
              .fontSize(17)
              .fontColor(task.done ? '#9AA0A6' : '#182431')
              .decoration({ type: task.done ? TextDecorationType.LineThrough : TextDecorationType.None })
            Blank()
          }
          .width('100%')
          .padding(16)
          .borderRadius(12)
          .backgroundColor(task.done ? '#EDF1F7' : '#FFFFFF')
          .onClick(() => {
            this.tasks[index] = new TaskItem(task.name, !task.done);
          })
        }, (task: TaskItem, index: number) => `${index}_${task.name}_${task.done}`)

        Row() {
          Text(this.stressIcon())
            .fontSize(22)
            .fontColor(this.stressIconColor())
            .margin({ right: 12 })
          Text(this.stressTitle())
            .fontSize(17)
            .fontColor('#182431')
          Blank()
          if (this.stressRunning) {
            Text(`剩余 ${this.stressRemaining}s`)
              .fontSize(14)
              .fontColor('#8C8C8C')
          }
        }
        .width('100%')
        .padding(16)
        .borderRadius(12)
        .backgroundColor(this.stressRunning ? '#EDF1F7' : '#FFFFFF')
        .onClick(() => {
          if (!this.stressRunning) {
            this.startStress();
          }
        })
      }
      .width('100%')
      .margin({ top: 24 })

      Blank()

      Column({ space: 8 }) {
        Progress({ value: this.doneCount(), total: this.tasks.length, type: ProgressType.Linear })
          .width('100%')
          .color('#0C59D8')
        Text(`已完成 ${this.doneCount()} / ${this.tasks.length}`)
          .fontSize(14)
          .fontColor('#666666')
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#F5F6FA')
  }
}

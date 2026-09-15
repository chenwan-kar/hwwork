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

  private doneCount(): number {
    return this.tasks.filter((task: TaskItem) => task.done).length;
  }

  build() {
    Column() {
      Column() {
        Text('HarmonyOS')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
        Text('第二周')
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

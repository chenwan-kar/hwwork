# HarmonyVibeLab 开发日志（vibe_log）

> 按时间线记录每个改动与验证依据。项目：课程学习打卡页（HarmonyOS 课 · 第二周作业）。

## 2026-09-15 · 阶段一：需求分析与方案设计（未改代码）

### 需求
首页展示课程标题 "HarmonyOS"、副标题 "第二周"，三条今日学习任务：

1. 读 OpenHarmony 概览
2. 搭好 DevEco 环境
3. 完成一次 CLI 构建

点击任务切换 完成/未完成，底部实时显示完成进度。

### 方案要点（验证依据）
- 只需改动 `entry/src/main/ets/pages/Index.ets`（空模板默认页），不需要新增页面或改 `module.json5`。
- 数据模型用 `class TaskItem`（name + done），状态用 `@State tasks: TaskItem[]`。
- **关键依据**：`@State` 仅观测第一层变化，直接 `this.tasks[i].done = !done` 不会触发 UI 刷新。
  依据：官方 FAQ《如何解决使用@State修饰对象数组，数据变化时页面不刷新问题》(faqs-arkui-1071)。
  → 因此点击时采用**整项替换**：`this.tasks[i] = new TaskItem(name, !done)`（数组项替换属第一层，可被观测）。
- ForEach 键值使用默认生成规则（`index + '__' + JSON.stringify(item)`），项内容变化 → 键值变化 → 组件重建刷新；不要写只含 name 的稳定键，否则替换后键值不变会导致不刷新（同一 FAQ 场景三）。
- 底部进度：`Progress({ value: 完成数, total: 3, type: ProgressType.Linear })` + `已完成 x / 3` 文本，完成数用 `tasks.filter(t => t.done).length` 计算。
- 复现与上传：`.gitignore` 已排除 `build/oh_modules/local.properties/.hvigor`，满足"换电脑 clone 后 `ohpm install --all` 即可复现"。

### 下一步
实现 Index.ets → 静态检查 → 构建 → Previewer/模拟器验证 → git 提交推送 GitHub。

---

## 2026-09-15 · 阶段二：实现 Index.ets

### 改动内容
仅重写 `entry/src/main/ets/pages/Index.ets`（模板默认页），其余工程文件零改动：

1. `class TaskItem { name: string; done: boolean }`：任务数据模型，显式 class + 构造函数（ArkTS 规范）。
2. `@State tasks: TaskItem[]`：3 条任务初始均为未完成。
3. 页面结构 `Column` 三段式：
   - 头部：Text "HarmonyOS"（32fp 加粗）+ Text "第二周"（16fp 灰色）
   - 中部：ForEach 渲染任务行（Row = 勾选符号 Text + 任务名 Text + Blank），完成态显示 ✔/蓝色、删除线、灰字、浅蓝底色
   - 底部：Progress(Linear) + "已完成 x / 3"，完成数由 `tasks.filter(t => t.done).length` 实时计算
4. 交互：整行 `.onClick` → `this.tasks[index] = new TaskItem(task.name, !task.done)`（**整项替换**，依据见阶段一：@State 只观测第一层）。
5. ForEach 键值：`` `${index}_${task.name}_${task.done}` ``，包含完成状态，保证状态变化 → 键值变化 → 组件重建刷新。

### 验证依据
- `arkts_check`（ArkTS 严格模式静态检查）：0 错误。
- `hvigor` 构建：BUILD SUCCESSFUL（assembleHap，约 1 分 33 秒）。

---

## 2026-09-15 · 阶段三：模拟器运行与验证

### 运行环境
Pura 90 模拟器（本机 DevEco Studio 6.1 自带镜像），安装 HAP 并启动 EntryAbility 成功。

### 验证过程与结果
- `devecocli ui layout` 布局树确认页面元素齐全：标题/副标题/3 条任务行/进度条/进度文本。
- 通过 `devecocli ui click` 对任务行编程点击，配合布局树观察：勾选符号（✔/○）、删除线联动、底部 Progress 值与 "已完成 x / 3" 文本随状态实时更新，均正常。
- 过程中模拟器窗口在桌面可见，存在人工点击与自动验证并行的干扰记录（最终状态由人工复核）。
- **最终结论（用户手动验证确认）**：点击任务切换完成/未完成、底部进度实时更新，功能符合需求。

### 复现步骤（换机同样适用）
```
git clone <仓库地址>
cd HarmonyVibeLab
ohpm install --all
hvigor 构建（或 DevEco Studio Build）→ 运行到模拟器/Previewer
```

### 待办
- git 提交并推送到 GitHub 个人仓库（.gitignore 已排除 build/oh_modules/local.properties）。

# HarmonySchedLab 假期作业日志（vibe_sched_log）

> 鸿蒙操作系统（2026 秋）· 第 4 周假期作业：调度观察 · Agent 结对 · 负载小项目。
> 工程基于第 2 周 HarmonyVibeLab（课程打卡页）扩展：保留原 3 张学习任务卡，新增第 4 张"CPU 压测"任务卡。
> 工程文件夹已由 hwwork 改名为 HarmonySchedLab（满足作业提交结构与英文路径要求）。

## 2026-09-27 · 阶段〇：基线确认与工程改名

- 我做了：`git status` 确认第 2 周工作已全部提交（最后提交 7c8867d，工作区干净，作为回滚基线）；把工程文件夹 `Desktop\hwwork` 改名为 `Desktop\HarmonySchedLab`；应用显示名由 HarmonyVibeLab 改为 HarmonySchedLab（AppScope string 资源）。
- 我看到：改名对 git 仓库无影响；`.hvigor/`、`build/` 属可再生成缓存，若残留旧路径报错删除重建即可。
- AI 参与：确认改名对 git/构建的影响——git 只关心仓库内部内容，文件夹改名不破坏历史；构建缓存目录为机器本地产物。

## 2026-09-27 · 阶段一：AI 结对两问（先让它讲，再写代码）

### 问题 1：TaskPool 和普通线程（Worker）有什么区别？压测该用哪个？

- **我的 Prompt 原文**："HarmonyOS 里 TaskPool 和普通线程（Worker）有什么区别？我要写一个启动 4 个并发线程各跑 10 秒纯计算的压测应用，该用哪个？"
- **AI 回答要点**：TaskPool 面向**任务**粒度——函数用 `@Concurrent` 标注后通过 `taskpool.execute()` 提交，线程的创建、复用、调度、销毁全部由系统线程池托管；Worker 面向**线程**粒度——手动 `new ThreadWorker()`、手动 `postMessage`/`onmessage`/`terminate` 管理整个生命周期。TaskPool 的 worker 在任务结束后归还池中复用，适合大量短任务并发；Worker 适合需要长驻、复杂双向通信的场景。压测是 4 个独立的 10 秒计算任务，无长驻需求，用 TaskPool 代码最简洁，且并发度由系统调度（4 核设备上 4 个任务可真正并行）。
- **我的核对**：对照本机 SDK `@ohos.taskpool.d.ts`（API 24）——`taskpool.execute(task: Task)` 存在；`Task` 类提供 `static sendData(...)`（API 11+，第 283 行）与实例方法 `onReceiveData(callback)`（API 11+，第 343 行），文档注释明确"sendData 在 TaskPool 线程内调用、宿主线程需先注册回调"，与 AI 说法一致，且证实 TaskPool 也具备进度上报能力（不必为实时进度退到 Worker）。
- **结论**：采信。压测用 TaskPool 实现 4 线程并发，实时进度用 `sendData`/`onReceiveData` 通道。

### 问题 2：为什么压测线程不能写在 UI 线程里？

- **我的 Prompt 原文**："为什么 CPU 压测的死循环不能直接写在 ArkUI 页面代码（UI 线程）里？写进去会发生什么？"
- **AI 回答要点**：UI 线程负责界面绘制与交互事件分发。若在 UI 线程跑 10 秒纯计算死循环，主线程事件循环被长时间占用——期间界面冻结、倒计时文字不刷新、所有点击无响应，超时后系统按应用无响应（ANR）处理。因此耗时计算必须放 TaskPool/Worker 线程，UI 线程只接收结果并更新状态。**可验证的判据**：压测运行期间若倒计时秒数持续跳动、其他任务卡仍可点击，即证明计算没有占用 UI 线程。
- **我的核对**：课件 4.0"调度时机与五大指标"——终端场景把"响应/可预期"放在首位，用户对瞬间卡顿零容忍；UI 线程被独占直接破坏响应性指标。ArkTS 官方并发文档同样要求耗时任务使用 TaskPool，禁止在主线程执行长耗时计算。AI 说法与两者一致。
- **结论**：采信，并把"压测期间倒计时流畅、原任务卡可点击"列入验证清单，作为压测不在 UI 线程的**实证**（见阶段四验证结果）。

## 2026-09-27 · 阶段二：方案设计（与 AI 结对，先讲清楚再动手）

- **压测任务卡交互**：完全沿用第 2 周任务卡格式（Row = 状态图标 + 文字 + Blank），三态流转：
  - 空闲 `○ CPU 压测（4 线程 × 10 秒）` → 点击开始；
  - 运行 `● 压测中… 已累加 N 次` + 右侧 `剩余 Xs` → 点击无效（防重入）；
  - 完成 `✔ 压测完成，共累加 N 次` → 点击再次触发（满足作业"结束后可再次触发"）。
  - 原 3 张学习任务卡与底部进度条逻辑不动（压测卡不参与完成数统计）。
- **并发与进度通道选型**：4 个 `taskpool.Task` 并发提交 `@Concurrent busyLoop`；实时进度用 worker 侧 `taskpool.Task.sendData(workerId, count)`（每 500ms）+ 宿主侧 `task.onReceiveData()` 回调聚合。选型依据：本机 SDK `@ohos.taskpool.d.ts`（API 24）第 283 行 `static sendData(...)`、第 343 行 `onReceiveData(callback)`，均为 API 11+ 公开接口，无需求退到 emitter/Worker 方案。
- **@Concurrent 限制核对**：busyLoop 参数/返回值均为 number（可序列化）；无闭包、不访问 UI；worker 侧不持有任何主线程对象。符合 ArkTS 并发规范。
- **@State 更新方式**：沿用第 2 周经验（@State 仅观测第一层）——计数用 `@State stressLiveCount: number` 直接赋值触发刷新；线程分量表用普通 `private threadCounts: number[]`（无需触发 UI）。

## 2026-09-27 · 阶段三：实现与构建

- **改动文件**（仅 2 个代码文件）：
  - 新增 `entry/src/main/ets/stress/StressWorker.ets`：`@Concurrent busyLoop(durationMs, workerId)` 累加空转，每 500ms `taskpool.Task.sendData` 上报；
  - 改写 `entry/src/main/ets/pages/Index.ets`：新增第 4 张压测卡 + `startStress()`（创建 4 个 Task、注册进度回调、UI 侧 setInterval 倒计时）+ `aboutToDisappear` 清理定时器。
- **AI 参与与修正**：首次构建报 WARN `Function may throw exceptions`（`sendData` 可抛 10200022∼10200024）——若在循环内抛出会中断 10 秒压测。核对 d.ts 后在 worker 侧用 try-catch 包住 `sendData`（进度上报为尽力而为，失败不影响压测循环），警告消除。
- **验证依据**：`arkts_check` 0 错误；hvigor `assembleHap` BUILD SUCCESSFUL（全量 32.4s，增量 4.7s）。

## 2026-09-27 · 阶段四：模拟器验证（Pura 90，API 24）

### 功能验证（三轮触发）
- 空闲态：布局树显示 `○ CPU 压测（4 线程 × 10 秒）`；
- 运行态：`● 压测中… 已累加 74424074 次` + `剩余 7s`——**实时计算量与倒计时同步跳动**（进度通道工作正常）；
- 完成态：第 1 轮 `✔ 压测完成，共累加 366492222 次`；再次点击触发第 2 轮，完成 `共累加 354333669 次`——**可再次触发**验证通过；
- **非阻塞实证**：压测运行期间倒计时持续刷新、布局树可正常导出、原任务卡可点击——证明压测确实不在 UI 线程（呼应阶段一问题 2）。

### 负载观测（top -n 1 -b，作业任务 C 要求的前/中/后对比）
- 压测前：`400%cpu … 400%idle`，应用进程 `com.example.harmonyvibelab` **0.0%** CPU（TIME+ 0:00.36）；
- 压测中：应用进程升至 **164% / 104%**（两次采样），TIME+ 持续增长至 1:16.62；
- 压测后：应用进程回落 **0.0%**，`400%idle` 恢复空闲，TIME+ 定格 1:19.59。
- **4 线程并发的定量证据**：两轮压测 TIME+ 净增 ≈ 79s ≈ 2 轮 × 4 线程 × 10s——若无并发（单线程串行）仅能积累 ≈ 20s。结论：调度器把 4 个工作线程真正摊到了多个核上并行执行。
- 参考截图：`screenshots/reference_done_state.png`（完成态实拍，正式提交截图由本人重新采集）。

### 意外发现（记入任务 A 素材）
1. `top -n 1` 的进程 %CPU 瞬时值波动大（164%→104%），不如 **TIME+ 累计值的差分**可靠——观测负载变化建议两次采样做差；
2. 总负载行 `400%idle` 在瞬时采样中不明显下降，但进程 TIME+ 与 %CPU 证实计算已在进行——模拟器虚拟 CPU 的统计口径与真机有差异；
3. `taskset -p <应用pid>` 与 `cat /proc/stat` 均报 **Permission denied**（模拟器仅允许查看自身 shell 进程的亲和掩码）——与课件"cpufreq/thermal 权限拒绝"同属虚拟化限制，输出已如实记录；
4. `ps -T -p <应用pid>` 可用：能看到应用进程的 IPC/GC/ace.bg 等线程列表，配合压测可观察工作线程出现。

### 结论
任务 C 最低要求（开始压测、4 并发线程、10 秒纯计算、倒计时、计算量、可再次触发）全部实现并验证；"基于第 2 周 HarmonyVibeLab 扩展"加分点成立（原任务卡保留、工程延续第 2 周 git 历史）。

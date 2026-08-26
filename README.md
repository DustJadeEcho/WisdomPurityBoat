# 星瞳智清舟 · 高原湖泊智慧水质监测系统

基于 **HarmonyOS（Stage 模型 / ArkTS）** 开发的高原湖泊水质监测与无人船控制系统。通过 MQTT 与船载 MCU 双向通信，实现水质多参数实时采集、GPS 轨迹追踪、无人船远程遥控，并内置支持流式输出、思维链展示、语音播报与语音输入的 AI water-quality 助手。

---

## 一、项目信息

| 项目 | 内容 |
|------|------|
| 应用名称 | 星瞳水质检测系统（WisdomPurityBoat） |
| Bundle Name | `com.example.wisdompurityboat` |
| 版本 | versionName `1.0.0` / versionCode `1000000` |
| 编译 SDK | `6.0.0(20)`（compatible & target 均为 6.0.0） |
| Runtime OS | HarmonyOS |
| 模型 | Stage 模型（`apiType: stageMode`） |
| 支持设备 | phone、tablet、2in1 |
| 开发工具 | DevEco Studio 6.0.2 |
| 主要技术 | ArkTS / ArkUI、@ohos/mqtt、ArkWeb (Web 组件)、RelationalStore、Preferences、CoreSpeechKit、AudioKit、NetworkKit (http/webSocket)、CryptoArchitectureKit |

---

## 二、整体架构

```
┌──────────────────────── 船载 MCU（C 固件） ─────────────────────────┐
│  水质传感器 → 64 字节数据帧(type=0x0001)                            │
│  GPS 模块  → 64 字节数据帧(type=0x0004)                             │
└───────────────────────────────┬────────────────────────────────────┘
                                │  MQTT（HEX 字符串载荷）
                 ┌──────────────┴───────────────┐
                 │   MQTT Broker (配置于           │
                 │   MQTTConfig.ets)              │
                 └──────────────┬───────────────┘
                                │
┌───────────────────────────────┴────────────────────────────────────┐
│                     HarmonyOS App（本项目）                         │
│                                                                     │
│  MQTTClient（单例，模块导入即连接）                                  │
│    ├─ 订阅 /your/water/topic → emitter EVENTID(1001)                │
│    ├─ 订阅 /your/gps/topic   → emitter GPS_EVENTID(1002)            │
│    └─ 发布 /your/pub/topic   ← 16 字节控制帧                        │
│                        │                                            │
│        ┌───────────────┼────────────────┐                          │
│        ▼               ▼                ▼                          │
│  MonitoringPage    MapPage         ControlPage                     │
│  (水质解析/展示)  (GPS/高德地图/轨迹)  (方向遥控)                    │
│                                                                     │
│  AIPage ──► AIChatController（模块级单例，跨页面存活）              │
│              ├─ AIChatService     SSE 流式请求                      │
│              ├─ AIChatStore       会话/记忆/上下文压缩              │
│              ├─ AIChatPersistence RDB 多会话持久化                  │
│              ├─ TTSManager        CoreSpeechKit 流式朗读            │
│              └─ ASRManager        讯飞 WebSocket 流式听写           │
│                     │ runJavaScript / javaScriptProxy               │
│                     ▼                                               │
│              ai_chat.html（自绘 Markdown 渲染引擎）                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 三、功能模块

### 1. 实时水质监测（MonitoringPage）

- 订阅 MQTT 水质主题，收到 64 字节帧后由 `WaterDataParser` 解析
- 展示 **pH、浊度、ORP、TDS、水温** 五项参数，并显示原始 HEX 报文
- 状态判定：
  - pH < 6 → 酸性（珊瑚色）；pH > 8 → 碱性（金色）；否则正常（海草绿）
  - 浊度 > 8 → 浑浊；> 5 → 微浊；否则清澈
- 顶部总览卡根据是否收到报文显示「在线 / 待机」

### 2. 监测地图与轨迹（MapPage）

- 内嵌 `Web` 组件加载 `rawfile/map.html`，使用 **高德地图 JS API 2.0**
- 订阅 GPS 事件，由 `GPSDataParser` 解析出经纬度、速度、定位质量、卫星数
- 原生侧通过 `runJavaScript()` 调用网页函数：`updateBoatPosition()`、`updateBoatStatus()`、`centerOnBoat()`、`clearTrail()`、`showHistoryTrail()`
- 网页侧用 `AMap.convertFrom(..., 'gps', ...)` 将 WGS-84 坐标转为高德坐标系，避免偏移
- 工具栏四个操作：**定位 / 清除 / 历史 / 归档**
- 轨迹持久化由 `TrailStorage`（Preferences）承担：当前轨迹上限 500 点，历史按日期分组保留 7 天
- 地图上另有 4 个静态监测点标记（北岸 / 东岸 / 南岸 / 西岸）

### 3. 无人船远程控制（ControlPage）

- 四向按钮（前进 / 后退 / 左转 / 右转），支持前后与左右**组合**方向
- 按下后以 **200 ms** 周期持续下发控制帧，松开立即补发一帧方向为 0 的停止帧
- 实时显示当前动作文案（前进并左转、后退并右转、停泊 …）

### 4. AI 水质助手（AIPage）

这是本次更新中改动最大的模块，已从"单页面请求-展示"重构为**服务层 + WebView 渲染**架构。

**对话能力**
- 流式（SSE）输出，边生成边渲染
- **思维链展示**：单独渲染 `reasoning` 增量，带计时器，生成结束后自动折叠
- 多会话管理：新建、切换、重命名、删除、清空
- 草稿保存：输入框内容随会话持久化
- 生成中可点击「停止」中断

**记忆系统**（`AIChatStore`）
- **长期记忆**：用户消息命中触发词（喜欢、偏好、记住、习惯、我是、我叫、请记住、不喜欢、讨厌、我的）时自动抽取摘要（≤120 字）
- **压缩上下文**：当会话总字符数 > 6000 且消息数 > 8 时，将较早消息压缩成一段摘要，仅保留最近 8 条
- 两类记忆均以 `system` 消息注入后续请求，且可在「对话记忆」面板中手动删除

**语音能力**
- **TTS 朗读**（`TTSManager` / CoreSpeechKit）：流式生成时按句边界分段入队朗读；支持朗读 / 暂停 / 继续 / 停止、全局静音；朗读前会清洗 Markdown 格式符号与表情，避免把 `**`、`|` 等读出来；用 `playEpoch` 轮次守卫忽略被打断的旧回调
- **ASR 按住说话**（`ASRManager` / 讯飞流式听写）：自采 16 kHz/16 bit/单声道 PCM，经 WebSocket 上传；录音与建连并行、建连期音频先缓存后补发，避免吞掉开头；支持 `wpgs` 动态修正；**松手自动发送，上滑取消**

**渲染层**（`rawfile/ai_chat.html`）
- 纯手写、零依赖的 Markdown 渲染器：标题、粗斜体、删除线、行内/围栏代码、有序无序嵌套列表、任务清单、表格、引用、脚注、分隔线
- 内置轻量语法高亮，代码块带语言标签
- 支持「跳到底部」悬浮按钮与跟随滚动策略（用户上滑后暂停自动跟随）
- 通过 `javaScriptProxy` 暴露 `arkBridge`，网页可回调原生：`onExampleTap`、`onReadAloud`

**跨页面存活**
`AIChatController` 是模块级单例。离开 AI 页面时仅解绑 WebView 与停止朗读，**流式生成仍在后台继续累积**；返回页面时由 `onWebReady()` 整屏补推全部状态。

### 5. 阈值设置（SettingsPage）

pH 范围、浊度警告阈值、溶解氧最低值、TDS 阈值、温度范围的展示与校准入口。

### 6. MQTT 调试页（MQTTPage）

收发消息的调试界面。

---

## 四、通信协议

### 4.1 帧总览

所有帧均为 **小端序**，帧头 `0x5A5A`，帧尾 `0x6B6B`，MQTT 载荷为空格分隔的十六进制字符串（如 `5A 5A 40 00 ...`）。

`MQTTClient` 按 **topic + 帧内类型字段（偏移 8-9）** 双重判定路由：

| 类型值 | 含义 | 事件 ID | 长度 |
|--------|------|---------|------|
| `0x0001` | 水质数据 MEASURED_DATA | `EVENTID` = 1001 | 64 B |
| `0x0004` | GPS 数据 GPS_DATA | `GPS_EVENTID` = 1002 | 64 B |
| `0x0005` | 船体控制指令（下行） | — | 16 B |

### 4.2 水质数据帧（64 字节，上行）

| 参数 | 偏移 | 类型 | 换算公式 |
|------|------|------|----------|
| 温度 | 10-11 | uint16 | `(raw / 10) × 0.625` ℃ |
| pH | 12-15 | uint32 | `raw / 100` |
| ORP | 16-19 | uint32 | `raw / 100` mV |
| TDS | 20-23 | uint32 | `raw / 100` ppm |
| 浊度 | 24-27 | uint32 | `raw / 100` NTU |

### 4.3 GPS 数据帧（64 字节，上行）

对应 MCU 侧 `BoatHullGpsDataFrame` 结构体，关键字段：

| 字段 | 偏移 | 类型 | 换算 |
|------|------|------|------|
| type | 8-9 | uint16 | 固定 `0x0004` |
| speedKmhX100 | 14-15 | uint16 | `raw / 100` km/h |
| latitude | 16-19 | int32 | `raw / 1000000` 度 |
| longitude | 20-23 | int32 | `raw / 1000000` 度 |
| altitude | 24-27 | int32 | 米 |
| fixQuality | 38 | uint8 | 0=无信号 1=GPS 2=DGPS |
| numSatellites | 39 | uint8 | 卫星数 |
| isValid | 40 | uint8 | 数据有效性 |
| crc16 | 60-61 | uint16 | CRC 校验 |

解析器会校验帧头、帧尾、类型，并进行有效性判定：`isValid > 0 && fixQuality > 0 && 纬度∈[-90,90] && 经度∈[-180,180] && 非 (0,0)`。

> 更详细的 GPS 联调说明见 [`GPS数据接入说明.md`](./GPS数据接入说明.md)。

### 4.4 船体控制帧（16 字节，下行）

```
偏移  0-1    2-3      4-7           8-11        12-13    14-15
     5A 5A  长度(16)  类型(0x05)    方向掩码     CRC16    6B 6B
```

- 方向位掩码：前进 `0x08`、后退 `0x10`、左转 `0x03`、右转 `0x04`（前后与左右可按位或组合）
- CRC16 为 **CCITT-FALSE**（多项式 `0x1021`，初值 `0xFFFF`），校验范围为帧首至倒数第 4 字节

---

## 五、目录结构

```
WisdomPurityBoat/
├── AppScope/
│   ├── app.json5                     # 应用级配置（bundleName / 版本 / 图标）
│   └── resources/                     # 应用级图标与字符串
├── entry/src/
│   ├── main/
│   │   ├── module.json5              # 模块配置、权限、Ability 声明
│   │   ├── ets/
│   │   │   ├── entryability/
│   │   │   │   └── EntryAbility.ets           # 注册字体 + 沉浸式状态栏 + 加载首页
│   │   │   ├── entrybackupability/
│   │   │   │   └── EntryBackupAbility.ets     # 备份恢复扩展
│   │   │   ├── pages/
│   │   │   │   └── Index.ets                  # @Entry，液态玻璃底部导航 + 页面分发
│   │   │   ├── views/                          # 业务页面
│   │   │   │   ├── HomePage.ets               # 首页
│   │   │   │   ├── MonitoringPage.ets         # 实时监测
│   │   │   │   ├── MapPage.ets                # 地图 + GPS + 轨迹
│   │   │   │   ├── ControlPage.ets            # 无人船遥控
│   │   │   │   ├── AIPage.ets                 # AI 助手（WebView + 抽屉 + 语音）
│   │   │   │   ├── SettingsPage.ets           # 阈值设置
│   │   │   │   └── MQTTPage.ets               # MQTT 调试
│   │   │   ├── services/                       # AI 会话服务层
│   │   │   │   ├── AIChatController.ets       # 单例总控：流式/TTS/持久化/WebView 桥
│   │   │   │   ├── AIChatService.ets          # SSE 流式 HTTP 请求
│   │   │   │   ├── AIChatStore.ets            # 会话状态、记忆抽取、上下文压缩
│   │   │   │   └── AIChatPersistence.ets      # RDB 多会话持久化
│   │   │   ├── utils/
│   │   │   │   ├── MQTTClient.ets             # MQTT 单例封装 + 帧路由分发
│   │   │   │   ├── MQTTConfig.ets             # 连接配置（导入即连接）
│   │   │   │   ├── WaterDataParser.ets        # 水质帧解析
│   │   │   │   ├── GPSDataParser.ets          # GPS 帧解析
│   │   │   │   ├── FrameUtils.ets             # 控制帧构建 + CRC16
│   │   │   │   ├── TrailStorage.ets           # 轨迹持久化（Preferences）
│   │   │   │   ├── TTSManager.ets             # 语音合成
│   │   │   │   └── ASRManager.ets             # 语音识别
│   │   │   ├── common/
│   │   │   │   ├── Types.ets                  # 通用类型（含 GPSData）
│   │   │   │   ├── AIChatTypes.ets            # AI 会话相关类型
│   │   │   │   └── Theme.ets                  # 液态玻璃海洋主题系统
│   │   │   └── constants/
│   │   │       └── AIPrompts.ets              # 系统提示词 + 示例问题池
│   │   └── resources/
│   │       ├── base/{element,media,profile}/  # 颜色、图标、页面路由配置
│   │       ├── dark/element/                   # 深色模式配色
│   │       └── rawfile/
│   │           ├── map.html                    # 高德地图页
│   │           ├── ai_chat.html                # AI 对话渲染页（自绘 Markdown）
│   │           └── fonts/LXGWWenKai.ttf        # 霞鹜文楷字体
│   ├── test/                                   # 本地单元测试
│   ├── ohosTest/                               # 设备端测试
│   └── mock/                                   # Mock 配置
├── build-profile.json5                         # 工程级构建配置
├── oh-package.json5                            # 依赖声明
├── code-linter.json5                           # 代码检查规则
└── GPS数据接入说明.md                          # GPS 协议与联调文档
```

---

## 六、设计系统

`common/Theme.ets` 定义了统一的「液态玻璃 · 海洋」主题，灵感来自 Liquid Glass 与 HarmonyOS 光效：

- **OceanPalette**：从深渊蓝 `#002244` 到浪花白 `#F7FBFD` 的 10 级海洋色阶，另含玻璃面板色（不同 alpha 的白）、强调色（珊瑚 / 金 / 海草绿 / 危险红）、文字色与光晕色
- **OceanGradients**：页面背景、标题栏、主/强调/成功/禁用按钮、玻璃高光、导航栏等预设渐变
- **OceanFont / OceanRadius**：字号（28/22/18/16/14/12）与圆角（20/16/24/14）规范
- **字体**：全局使用**霞鹜文楷 LXGW WenKai**，由 `EntryAbility.onWindowStageCreate()` 通过 `font.registerFont()` 注册为 `LXGWWenKai`

视觉实现要点：底部导航与卡片大量使用 `backgroundBlurStyle()` 毛玻璃 + 半透明白底 + 高光描边 + 彩色投影；首页背景叠加三个高斯模糊光斑模拟水下阳光。

---

## 七、快速开始

### 1. 环境准备

1. 安装 **DevEco Studio 6.0.2** 或更高版本
2. 配置 HarmonyOS SDK **6.0.0(API 20)**
3. 克隆项目后用 DevEco Studio 打开，等待 `ohpm` 依赖同步完成

### 2. 字体文件

`rawfile/fonts/LXGWWenKai.ttf` 已包含在仓库中。若需替换，从 [LXGW WenKai Releases](https://github.com/lxgw/LxgwWenKai/releases) 下载 TTF 并重命名为 `LXGWWenKai.ttf` 放回原位（SIL OFL 1.1 协议，可免费商用）。

### 3. 配置 MQTT

编辑 `entry/src/main/ets/utils/MQTTConfig.ets`：

```typescript
const MQTTOption: MQTTOptionsType = {
  url: 'mqtt://your-broker-host:1883',
  clientId: '/your/client/id',
  userName: 'username',
  password: 'password',
  pubTopicName: '/your/pub/topic',      // 下发控制指令
  subTopicName: '/your/water/topic',    // 订阅水质数据
  gubTopicName: '/your/gps/topic',      // 订阅 GPS 数据
  qos: 0
};
```

> 该文件被 `pages/Index.ets` 导入，**应用启动即自动建立连接并订阅**，无需手动调用。

### 4. 配置 AI 服务

编辑 `entry/src/main/ets/services/AIChatService.ets`（接口兼容 OpenAI Chat Completions 格式，需支持 `stream: true`）：

```typescript
const API_URL = 'https://your-api-host/v1/chat/completions'
const API_KEY = 'sk-your-api-key'
const MODEL_NAME = 'your-model-name'
```

系统提示词与示例问题可在 `entry/src/main/ets/constants/AIPrompts.ets` 中调整。

### 5. 配置语音识别

编辑 `entry/src/main/ets/utils/ASRManager.ets`，填入[讯飞开放平台](https://www.xfyun.cn/doc/asr/voicedictation/API.html)语音听写（流式版）的凭据：

```typescript
const XUNFEI_APPID = 'your-appid'
const XUNFEI_API_KEY = 'your-api-key'
const XUNFEI_API_SECRET = 'your-api-secret'
```

### 6. 配置地图

编辑 `entry/src/main/resources/rawfile/map.html`，替换高德地图 Web 端 Key 与安全密钥：

```html
<script>
  window._AMapSecurityConfig = { securityJsCode: 'your-security-code' };
</script>
<script src="https://webapi.amap.com/maps?v=2.0&key=your-amap-key"></script>
```

### 7. 运行

连接真机或启动模拟器，点击运行。首次使用语音输入时会弹出麦克风授权请求。

> ⚠️ **语音合成 / 语音识别 / 地图 依赖真机能力与网络**，模拟器上可能无法完整验证。

---

## 八、权限说明

| 权限 | 用途 | 授权方式 |
|------|------|----------|
| `ohos.permission.INTERNET` | MQTT 通信、AI 接口请求、地图加载、ASR WebSocket | 安装即授予 |
| `ohos.permission.MICROPHONE` | AI 助手「按住说话」语音输入 | 运行时动态申请（首次按住麦克风时） |

---

## 九、数据持久化

| 存储 | 载体 | 位置 | 内容 |
|------|------|------|------|
| AI 多会话 | RelationalStore | `AIChatDB.db` | `ai_chat_session` 表按会话存整段 JSON；`ai_chat_meta` 表记录当前激活会话 ID。含旧库 `ALTER TABLE` 兼容逻辑 |
| 船只轨迹 | Preferences | `boat_trail_storage` | 当前轨迹（≤500 点）与按日期分组的历史轨迹（保留 7 天） |
| 水质历史 | RelationalStore | `WaterQualityDB.db` | `sensor_data` 表结构已定义（pH / 浊度 / ORP / 溶解氧 / TDS / 电导率 / 温度 / 时间戳） |

---

## 十、依赖

```json5
{
  "dependencies": {
    "@ohos/mqtt": "^2.0.26"        // MQTT 客户端（含 arm64-v8a / armeabi-v7a / x86_64 native 库）
  },
  "devDependencies": {
    "@ohos/hypium": "1.0.24",      // 单元测试框架
    "@ohos/hamock": "1.0.0"        // Mock 框架
  }
}
```

系统 Kit 依赖：`@kit.AbilityKit`、`@kit.ArkUI`、`@kit.ArkWeb`、`@kit.ArkData`、`@kit.ArkTS`、`@kit.NetworkKit`、`@kit.AudioKit`、`@kit.CoreSpeechKit`、`@kit.CryptoArchitectureKit`、`@kit.BasicServicesKit`、`@kit.PerformanceAnalysisKit`。

---

## 十一、页面路由

应用为**单 Entry 页 + 状态分发**结构，`pages/Index.ets` 通过 `currentPage` 状态切换视图，各子页面通过 `navigate: NavigationFunc` 回调返回或跳转：

| 索引 | 页面 | 底部导航 |
|------|------|----------|
| 0 | HomePage 首页 | ✅ 首页 |
| 1 | MonitoringPage 实时监测 | ✅ 监测 |
| 2 | MapPage 监测地图 | ✅ 地图 |
| 3 | SettingsPage 阈值设置 | — |
| 5 | MQTTPage MQTT 调试 | — |
| 6 | ControlPage 小船控制 | ✅ 控制 |
| 7 | AIPage AI 助手 | ✅ AI |

---

## 十二、已知问题与待办

以下为当前代码中确实存在的未完成项，供后续迭代参考：

- **水质历史数据未落库**：`MonitoringPage` 中的 `initDatabase()` 与 `saveSensorData()` 已实现但**没有任何调用点**，`WaterQualityDB.db` 实际不会写入数据；首页「历史数据」入口指向 `navigate(4)`，而 `Index.ets` 中**没有 `currentPage === 4` 的分支**，点击后页面区域为空。
- **MQTTPage 未接线**：接收框、发送按钮、连接按钮均为静态 UI，未绑定 `MQTTInstance` 的收发逻辑；且该页（索引 5）没有任何导航入口可达。
- **SettingsPage 阈值未生效**：阈值仅为页面内 `@State`，未持久化，也未参与 `MonitoringPage` 的状态判定；「校准」按钮仅弹 Toast。
- **监测页 UI 未展示溶解氧与电导率**：`dissolvedOxygen`、`conductivity` 状态已声明但协议帧中无对应字段，恒为 0。
- **`emitter.off()` 粒度偏粗**：`MonitoringPage` / `MapPage` 的 `aboutToDisappear()` 中按 eventId 整体注销，会移除该事件上的所有监听者，多页面同时监听同一事件时需注意。
- **历史轨迹「删除」行为不符预期**：`MapPage` 历史列表中单条记录的删除按钮调用的是 `clearAllHistory()`，会清空全部历史而非该条。
- **凭据硬编码**：MQTT 账号密码、AI API Key、讯飞密钥、高德 Key 均硬编码在源码中，**生产环境请迁移至安全存储或服务端代理**。
- **空文件**：`ets/types/WaterQuality.ets` 为 0 字节的遗留占位文件。
- **未使用资源**：`ic_dashboard.png`、`ic_empty.png`、`ic_history.png`、`ic_mqtt.png`、`ic_settings.png` 当前未被代码引用。
- **`MapPage` 中残留少量乱码注释**（GBK/UTF-8 转换遗留），不影响功能。

---

## 十三、测试

```
entry/src/test/       # 本地单元测试（LocalUnit.test.ets）
entry/src/ohosTest/   # 设备端测试（Ability.test.ets）
```

当前均为 Hypium 模板用例，尚未针对 `WaterDataParser`、`GPSDataParser`、`FrameUtils`（CRC16）等纯函数编写实质断言 —— 这几个模块无副作用、易于测试，建议优先补充。

---

## 十四、版本记录

**v1.0.0（当前）** — 升级至 HarmonyOS 6.0.2 / API 20，并完成以下重构与新增：

- ✨ 新增 GPS 数据链路：`GPSDataParser`、双主题订阅、帧类型路由、地图实时定位
- ✨ 新增轨迹系统：`TrailStorage` 实时记录、历史归档、按日期查看
- ✨ 新增地图页：高德地图 JS API 2.0 + GPS 坐标系转换
- ✨ AI 模块重构为服务层架构：`AIChatController` / `Service` / `Store` / `Persistence` 四层拆分，单例跨页面存活
- ✨ AI 新增流式输出、思维链展示、多会话管理、长期记忆与上下文压缩
- ✨ 新增语音能力：`TTSManager` 流式朗读、`ASRManager` 按住说话
- ✨ 渲染层从 ArkTS `MarkdownParser` 迁移至 WebView 自绘 Markdown 引擎（支持表格、脚注、任务清单、代码高亮）
- 🎨 全新「液态玻璃 · 海洋」主题系统 + 霞鹜文楷全局字体 + 沉浸式状态栏
- 🔧 MQTT 客户端支持多主题订阅（`subscribeMany`）与自动重连

---

## 十五、开发者

星瞳智巡团队

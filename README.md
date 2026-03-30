# 青海湖智清舟 - 智慧水质监测系统

基于 **OpenHarmony** 开发的智能水质监测与无人船控制系统，实现水质数据实时采集、MQTT 通信、远程控制及 AI 智能分析。

## 项目信息

- **项目名称**：WisdomPurityBoat（青海湖智清舟）
- **开发环境**：DevEco Studio 6.0.2
- **运行平台**：OpenHarmony 4.0+
- **技术栈**：ArkTS、ArkUI、MQTT、HTTP 网络请求、关系型数据库

## 功能模块

### 1. 核心功能

- **实时水质监测**：pH、浊度、ORP、TDS、温度等多参数显示
- **无人船远程控制**：前进、后退、左转、右转，支持组合方向控制
- **MQTT 通信**：数据订阅下发、指令发送、心跳保持
- **监测点地图**：可视化展示监测区域与设备分布
- **阈值设置**：水质参数预警阈值配置
- **AI 智能问答**：基于 TokenSpark API 提供青海湖水质咨询服务

### 2. 页面结构

plaintext

```
首页 (HomePage)
├─ 实时监测 (MonitoringPage) - 水质数据展示
├─ AI 问答 (AIPage) - 智能分析与咨询
├─ 监测地图 (MapPage) - 监测点分布
├─ 小船控制 (ControlPage) - 远程遥控
└─ 系统设置 (SettingsPage) - 参数配置
```

## 目录结构

plaintext

```
WisdomPurityBoat/
├── entry/src/main/ets/
│   ├── entryability/        # 应用入口能力
│   ├── pages/               # 主页面路由
│   ├── views/               # 业务页面组件
│   ├── common/              # 公共类型定义
│   ├── utils/               # 工具类
│   │   ├── MQTTClient.ets        # MQTT 客户端封装
│   │   ├── MQTTConfig.ets        # MQTT 配置与单例
│   │   ├── WaterDataParser.ets   # 水质数据帧解析
│   │   ├── FrameUtils.ets        # 指令帧构建、CRC 校验
│   │   └── MarkdownParser.ets    # AI 回复 Markdown 渲染
│   └── types/               # 数据类型定义
└── 配置文件
```

## 核心技术实现

### 1. MQTT 通信

- 采用 `@ohos/mqtt` 三方库实现稳定连接
- 全局单例模式，应用启动自动连接
- 主题：订阅 `/qhmu/lly/mcu`，发布 `/qhmu/lly/hsetting`
- 数据解析：HEX 帧转水质参数，支持异常处理

### 2. 无人船控制协议

- 自定义 16 字节控制帧：`5A 5A + 长度 + 指令类型 + 方向 + CRC16 + 6B 6B`
- 方向位掩码：前进 (0x08)、后退 (0x10)、左转 (0x03)、右转 (0x04)
- 长按连续发送，松开自动停止，防丢包设计

### 3. AI 问答系统

- 对接 TokenSpark API（兼容 OpenAI 格式）
- 强制校验：提问必须包含 “青海” 关键词
- Markdown 转 HTML 富文本展示，支持标题、列表、代码块

### 4. 数据持久化

- 关系型数据库存储历史监测数据
- 自动保存：pH、浊度、温度、时间戳等字段

## 快速开始

### 1. 环境配置

1. 安装 DevEco Studio 6.0.2
2. 配置 OpenHarmony SDK 4.0 及以上
3. 导入项目，等待依赖同步完成

### 2. MQTT 配置（可选）

修改 `utils/MQTTConfig.ets`：

typescript

运行

```
const MQTTOption = {
  url: 'mqtt://xxx.xxx.xxx.xxx:1883',    // MQTT 服务器地址
  clientId: 'your-client-id',
  userName: 'username',
  password: 'password',
  pubTopicName: 'your-pub-topic',
  subTopicName: 'your-sub-topic',
  qos: 0
};
```

### 3. AI 配置（可选）

修改 `views/AIPage.ets`：

typescript

运行

```
const API_URL = 'https://your-api-url';
const API_KEY = 'your-api-key';
const MODEL_NAME = 'your-model-name';
```

### 4. 运行项目

1. 连接真机或启动模拟器
2. 点击运行按钮，自动编译安装
3. 授权网络权限，即可正常使用

## 权限说明

json

```
"requestPermissions": [
  { "name": "ohos.permission.INTERNET" }    // 网络通信
]
```

## 依赖库

- `@ohos/mqtt: 2.0.26` - MQTT 客户端
- `@ohos/hypium: 1.0.24` - 测试框架
- `@ohos/hamock: 1.0.0` - 模拟数据

## 版本说明

- **v0.0.1**：基础功能完成，支持水质监测、MQTT 通信、小船控制、AI 问答
- 架构优化：页面拆分、工具类抽离、响应式更新、内存泄漏修复

## 开发者

青海湖智清舟开发团队

# GPS 数据接入说明

> 本文档描述船载 MCU 的 GPS 数据如何经 MQTT 抵达 HarmonyOS 端，并最终在地图上呈现。
> 代码位置：`GPSDataParser.ets`、`MQTTClient.ets`、`MapPage.ets`、`TrailStorage.ets`、`rawfile/map.html`。

---

## 一、数据流程概览

```
GPS 模块 → 单片机（组帧 BoatHullGpsDataFrame）
              ↓ 蓝牙 SLE
          单片机 MQTT 客户端
              ↓ 发布到 /your/gps/topic（64 字节二进制载荷）
          MQTT Broker（地址配置于 MQTTConfig.ets）
              ↓ 订阅
      MQTTClient.messageArrived()
        · payloadBinary → 空格分隔 HEX 字符串
        · 按 topic + 帧类型双重判定路由
              ↓ emitter.emit(GPS_EVENTID = 1002)
          MapPage.onGPSEvent()
              ↓ parseGPSData(hex)
        ┌─────┴─────┐
        ▼           ▼
   状态卡 UI    TrailStorage.addPoint()   （持久化轨迹）
        ▼
   webCtrl.runJavaScript()
        ↓
   map.html · updateBoatPosition() / updateBoatStatus()
        ↓ AMap.convertFrom(..., 'gps', ...)  WGS-84 → GCJ-02
   高德地图船只标记 + 轨迹折线
```

---

## 二、数据格式定义

### 2.1 GPS 数据帧（`BoatHullGpsDataFrame`，64 字节，小端序）

| 字段 | 偏移 | 类型 | 说明 | 示例值 |
|------|------|------|------|--------|
| head | 0-1 | uint16 | 帧头，固定 `0x5A5A` | `5A 5A` |
| length | 2-3 | uint16 | 帧长度 | 64 |
| clientId | 4-5 | uint16 | 客户端 ID | - |
| serverId | 6-7 | uint16 | 服务端 ID | - |
| **type** | **8-9** | **uint16** | **数据类型，GPS 固定 `0x0004`** | `04 00` |
| utcYear | 10-11 | uint16 | UTC 年份 | 2026 |
| bjYear | 12-13 | uint16 | 北京时间年份 | 2026 |
| **speedKmhX100** | **14-15** | **uint16** | **速度 × 100** | 150 → 1.50 km/h |
| **latitude** | **16-19** | **int32** | **纬度 × 1000000** | 36585737 → 36.585737° |
| **longitude** | **20-23** | **int32** | **经度 × 1000000** | 101818773 → 101.818773° |
| altitude | 24-27 | int32 | 海拔（米） | 3200 |
| utcMonth | 28 | uint8 | UTC 月 | 6 |
| utcDay | 29 | uint8 | UTC 日 | 16 |
| utcHour | 30 | uint8 | UTC 时 | 8 |
| utcMinute | 31 | uint8 | UTC 分 | 30 |
| utcSecond | 32 | uint8 | UTC 秒 | 45 |
| bjMonth | 33 | uint8 | 北京时间月 | 6 |
| bjDay | 34 | uint8 | 北京时间日 | 16 |
| bjHour | 35 | uint8 | 北京时间时 | 16 |
| bjMinute | 36 | uint8 | 北京时间分 | 30 |
| bjSecond | 37 | uint8 | 北京时间秒 | 45 |
| **fixQuality** | **38** | **uint8** | **定位质量：0=无信号 1=GPS 2=DGPS** | 1 |
| **numSatellites** | **39** | **uint8** | **可见卫星数** | 8 |
| **isValid** | **40** | **uint8** | **数据有效性：1=有效 0=无效** | 1 |
| ret[19] | 41-59 | uint8[] | 保留字段 | 全 0 |
| crc16 | 60-61 | uint16 | CRC 校验 | - |
| end | 62-63 | uint16 | 帧尾，固定 `0x6B6B` | `6B 6B` |

> ⚠️ **类型值必须是 `0x0004`**。
> `0x0001` 是水质数据（MEASURED_DATA），`0x0005` 是下行的船体控制指令。
> 见 `MQTTClient.ets` 中的 `GPS_DATA_TYPE = 0x0004`、`MEASURED_DATA_TYPE = 0x0001`。

### 2.2 与水质帧的对比

两类上行帧长度都是 64 字节、帧头帧尾一致，**仅靠偏移 8-9 的类型字段区分**：

| | 水质帧 | GPS 帧 |
|---|---|---|
| type (8-9) | `0x0001` | `0x0004` |
| MQTT 主题 | `/your/water/topic` | `/your/gps/topic` |
| 事件 ID | `EVENTID` = 1001 | `GPS_EVENTID` = 1002 |
| 解析器 | `parseWaterData()` | `parseGPSData()` |
| 消费页面 | `MonitoringPage` | `MapPage` |

### 2.3 MQTT 传输格式

- **主题**：GPS 使用**独立主题** `gubTopicName`（配置于 `MQTTConfig.ets`，当前为 `/your/gps/topic`），与水质主题分离
- **载荷**：**64 字节原始二进制**，不是十六进制文本
- **App 内部表示**：`MQTTClient` 收到后将 `payloadBinary` 转为空格分隔的小写 HEX 字符串，再随 emitter 事件下发；解析器内部会 `toUpperCase()` 后处理，故大小写不敏感

订阅由 `subscribeMany()` 一次性完成，水质与 GPS 两个主题同时订阅（若两者配置相同则自动去重）。

**帧示例**（十六进制表示，实际传输为二进制）：
```
5A 5A 40 00 01 00 02 00 04 00 ... 6B 6B      ← 共 64 字节
└头─┘ └长┘ └客户┘ └服务┘ └类型┘        └尾┘
```

---

## 三、HarmonyOS 端接收流程

### 3.1 MQTT 接收与路由（`MQTTClient.ets`）

```typescript
this.mqttClient.messageArrived((err: Error, data: MqttMessage) => {
  const raw = new Uint8Array(data.payloadBinary);
  const hexStr = Array.from(raw)
    .map((b: number): string => b.toString(16).padStart(2, '0'))
    .join(' ');
  const frameType = this.getFrameType(raw);   // 读取偏移 8-9（小端）

  // GPS：主题匹配 或 类型匹配，任一命中即路由
  if (data.topic === this.gubTopicName || frameType === GPS_DATA_TYPE) {
    this.emitMessage(GPS_EVENTID, hexStr);    // eventId = 1002
    return;
  }
  // 水质
  if (data.topic === this.subTopicName || frameType === MEASURED_DATA_TYPE) {
    MQTTClient.latestWaterMessage = hexStr;
    this.emitMessage(EVENTID, hexStr);        // eventId = 1001
    return;
  }
  console.warn('MQTT received message from unknown topic: ' + data.topic);
});
```

**路由是「主题 OR 类型」双条件**，因此：
- 主题配置正确 → 即使 MCU 的 type 字段写错也能进入 GPS 分支（但随后会被 `parseGPSData` 的类型校验拦下）
- 主题配错但 type 正确 → 仍能正确路由

### 3.2 GPS 解析（`GPSDataParser.ets`）

`parseGPSData(hexString)` 的校验与解析顺序：

1. 非空、按空白切分后 **token 数 ≥ 64**
2. 每个 token 必须匹配 `/^[0-9A-F]{2}$/`
3. 帧头 == `0x5A5A`
4. 帧尾（偏移 62-63）== `0x6B6B`
5. 类型（偏移 8-9）== `0x0004`
6. 提取字段并换算：

```typescript
const latitude  = rawLat / 1_000_000;      // int32 → 度
const longitude = rawLng / 1_000_000;      // int32 → 度
const speed     = rawSpeed / 100;          // uint16 → km/h
```

7. 有效性综合判定（写入 `GPSData.isValid`）：

```typescript
const valid = isValid > 0
  && fixQuality > 0
  && latitude  >= -90  && latitude  <= 90
  && longitude >= -180 && longitude <= 180
  && !(latitude === 0 && longitude === 0);
```

返回结构 `GPSData`（`common/Types.ets`）：

```typescript
interface GPSData {
  latitude: number;    // 纬度（°）
  longitude: number;   // 经度（°）
  fixStatus: number;   // 0=无信号 1=GPS 2=DGPS
  satellites: number;  // 可见卫星数
  speed: number;       // km/h
  isValid: boolean;    // 综合有效性
}
```

> **两点实现现状**（非缺陷，但接入时需知晓）：
> - **CRC16 未校验**：偏移 60-61 的 CRC 字段目前仅在注释中说明，`parseGPSData` 不做校验。数据完整性依赖帧头/帧尾/类型三重判定。
> - **海拔未输出**：`ALTITUDE_OFFSET = 24` 已定义，但 `GPSData` 无 `altitude` 字段，海拔当前被丢弃。若需要海拔，须同时扩展 `GPSData` 与解析逻辑。

### 3.3 页面处理（`MapPage.ets`）

```typescript
aboutToAppear(): void {
  emitter.on({ eventId: GPS_EVENTID }, this.gpsCallback);
  this.initTrailStorage();     // TrailStorage 需 UIAbilityContext
  this.loadHistoryTrails();
}

private onGPSEvent(evt: emitter.EventData): void {
  const raw: string = evt.data?.content as string ?? '';
  if (!raw.trim()) return;

  const gps: GPSData | null = parseGPSData(raw);
  if (!gps || !gps.isValid) return;          // 无效帧直接丢弃

  this.boatLat = gps.latitude;
  this.boatLng = gps.longitude;
  this.boatSpeed = gps.speed;
  this.gpsFix = gps.fixStatus;
  this.satellites = gps.satellites;
  this.boatStatusText = gps.fixStatus > 0 ? '定位正常' : '搜索卫星中…';
  this.lastUpdate = /* HH:mm:ss */;

  if (this.isMapReady) {                     // 等 Web onPageEnd 后才推送
    this.pushToMap(this.autoCenterMap);
  }
  if (gps.fixStatus > 0) {
    this.trailStorage.addPoint(gps.latitude, gps.longitude, gps.speed);
  }
}
```

`pushToMap()` 通过 `runJavaScript()` 依次调用网页三个函数：

| 调用 | 作用 |
|------|------|
| `updateBoatPosition(lat, lng)` | 移动船只标记，追加显示轨迹 |
| `updateBoatStatus(json)` | 更新点击标记时弹出的信息窗内容 |
| `centerOnBoat()` | 仅当 `autoCenterMap` 为真时调用，地图平移到船位 |

### 3.4 坐标系转换（`map.html`）—— 关键

高德地图使用 **GCJ-02**，而 GPS 模块输出 **WGS-84**，直接投点会有百米级偏移。`map.html` 中所有落图坐标都先经过转换：

```javascript
function toLngLatFromGps(lat, lng, callback) {
  if (!lat || !lng || (lat === 0 && lng === 0)) return;
  AMap.convertFrom([lng, lat], 'gps', function (status, result) {
    if (status === 'complete' && result.locations && result.locations.length > 0) {
      callback(result.locations[0]);
    } else {
      callback(new AMap.LngLat(lng, lat));   // 转换失败则退回原始坐标
    }
  });
}
```

- **单点**：`toLngLatFromGps()`，用于船位与静态监测点
- **路径**：`convertPathFromGps()`，历史轨迹按 **40 点一批**分块转换（高德接口有单次数量上限），全部完成后回调
- 转换是**异步**的，`updateBoatPosition` 用 `boatUpdateSeq` 序号守卫丢弃过期回调，避免高频推送时标记位置回跳

### 3.5 轨迹存储（`TrailStorage.ets`）

基于 **Preferences**（`boat_trail_storage`）：

| 项 | 值 |
|---|---|
| 当前轨迹上限 | 500 点（超出丢弃最旧点） |
| 历史保留 | 7 天（按 `YYYY-MM-DD` 分组，归档时清理过期） |
| 轨迹点结构 | `{ lat, lng, timestamp, speed }` |

地图上**显示**的实时轨迹另有独立上限 200 点（`map.html` 中的 `boatTrail`），与持久化的 500 点无关。

地图工具栏四个按钮：

| 按钮 | 行为 |
|------|------|
| 定位 | 开启自动居中并平移到当前船位 |
| 清除 | `clearTrail()` + 清空当前持久化轨迹 |
| 历史 | 打开历史轨迹面板（按日期倒序） |
| 归档 | 将当前轨迹并入今日历史记录，随后清空当前轨迹 |

历史轨迹展示为红色虚线折线，起点绿圆、终点红圆，并自动 `setFitView` 缩放到合适视野。

---

## 四、测试验证步骤

### 步骤 1：验证单片机 GPS 数据发送

在单片机串口输出中查看（参考固件调试代码）：

```c
printf("[CTRL-R] GPS UTC: %s\r\n", g_boat_gps_utc);
printf("[CTRL-R] GPS BJT: %s\r\n", g_boat_gps_bj);
printf("[CTRL-R] GPS Lat: %d Lon: %d Alt: %d Speed:%d.%02d Sat:%d Fix:%d Valid:%d\r\n",
    g_boat_gps_latitude, g_boat_gps_longitude, g_boat_gps_altitude,
    g_boat_gps_speed_x100 / 100, g_boat_gps_speed_x100 % 100,
    g_boat_gps_satellites, g_boat_gps_fix_quality, g_boat_gps_valid);
```

**预期输出**：
```
[CTRL-R] GPS UTC: 2026-06-16 08:30:45
[CTRL-R] GPS BJT: 2026-06-16 16:30:45
[CTRL-R] GPS Lat: 36585737 Lon: 101818773 Alt: 3200 Speed:1.50 Sat:8 Fix:1 Valid:1
```

### 步骤 2：验证订阅是否建立

App 启动时（`MQTTConfig.ets` 被 `Index.ets` 导入即自动连接）应看到：

```
MQTT Server URL: mqtt://your-broker-host:1883
Water Subscribe Topic: /your/water/topic
GPS Subscribe Topic: /your/gps/topic
MQTT connect success: ...
MQTT subscribe success: ["/your/water/topic","/your/gps/topic"] ...
```

### 步骤 3：验证 MQTT 接收与路由

```
MQTT receive topic=/your/gps/topic, type=0x4, hex=5a 5a 40 00 01 00 02 00 04 00 ...
```

重点确认 **`type=0x4`**。若显示 `type=0x3` 或其它值，说明 MCU 组帧的类型字段有误。

### 步骤 4：验证 GPS 解析

```
[GPSParser] 解析成功: {lat: "36.585737", lng: "101.818773", speed: "1.50", fix: 1, sat: 8, valid: true}
```

### 步骤 5：验证 MapPage 事件注册

进入地图页时应看到：

```
[MapPage] 注册 GPS 事件, eventId = 1002
```

### 步骤 6：验证地图显示

- **GPS 状态角标**：由红色「GPS 未定位」变为绿色「GPS 已定位」
- **智清舟状态卡**：显示真实经纬度（6 位小数）、速度、卫星数、最后更新时间
- **地图标记**：🚢 图标出现在真实坐标，首次定位自动 `setZoomAndCenter(13, ...)`
- **轨迹**：蓝色虚线折线随移动延伸
- **监测点列表**：「智清舟」条目状态由「离线」变「在线」

---

## 五、常见问题排查

### 问题 1：日志无 `[GPSParser]` 输出

**说明帧根本没进解析器，或在前置校验就被拦下。** 按顺序排查：

| 现象 | 原因 | 处理 |
|---|---|---|
| 无 `MQTT receive` 日志 | 未连上 Broker / 未订阅成功 | 检查步骤 2 日志、网络与账号密码 |
| 有 `MQTT receive` 但走了 `unknown topic` 警告 | 主题与 `subTopicName`/`gubTopicName` 都不匹配，且类型字段也不匹配 | 核对 `MQTTConfig.ets` 主题与 MCU 发布主题 |
| `[GPSParser] 帧长度不足` | 载荷不足 64 字节 | 检查 MCU 组帧长度与 MQTT 是否截断 |
| `[GPSParser] 帧头错误` | 帧头不是 `0x5A5A` | 确认小端写入顺序 |
| `[GPSParser] 帧尾错误` | 偏移 62-63 不是 `0x6B6B` | 检查保留字段与 CRC 是否越界覆盖帧尾 |
| `[GPSParser] 非GPS帧，类型: 0x...` | 类型字段不是 `0x0004` | **最常见**，见问题 3 |

### 问题 2：解析成功但地图不显示坐标

**原因**：`isValid` 综合判定失败，`MapPage` 直接 `return`。检查解析日志中的 `valid` 字段，逐项核对：

1. `isValid` 字段 > 0
2. `fixQuality` > 0（室内无信号时为 0，需到户外或接外置天线）
3. 纬度 ∈ [-90, 90]、经度 ∈ [-180, 180]
4. 坐标不为 (0, 0)

### 问题 3：GPS 帧被当成水质帧

**原因**：类型字段不是 `0x0004`。

若 MCU 仍在发 `0x0003`（旧版本约定），会出现两种情况：
- 发布到 GPS 专属主题 → 路由进 GPS 分支，但被 `parseGPSData` 的类型校验拦下，日志出现「非GPS帧」
- 发布到水质主题 → 被水质分支吞掉，`parseWaterData` 按水质偏移错误解析出乱数

**处理**：将 MCU 的 `type` 字段改为 `0x0004`；或同步修改 `GPSDataParser.ets:52` 与 `MQTTClient.ets:15` 的 `GPS_DATA_TYPE` 常量（两处必须一致）。

### 问题 4：坐标偏移约 100～500 米

**原因**：坐标系不匹配（WGS-84 vs GCJ-02），而非解析错误。

**排查**：确认 `map.html` 中的高德 Key 与 `securityJsCode` 有效。若 `AMap.convertFrom` 因鉴权失败或配额耗尽而不可用，代码会**静默退回原始 WGS-84 坐标**，表现就是稳定的整体偏移。可在网页控制台确认 `AMap.convertFrom` 是否存在及其回调 `status`。

### 问题 5：坐标数量级明显错误

**原因**：字节序或换算倍率错误。

**处理**：确认全部字段使用**小端序**（`getInt32(offset, true)`），经纬度除以 1000000，速度除以 100。

### 问题 6：地图不更新 / 首次定位丢失

| 原因 | 处理 |
|---|---|
| `emitter` 未注册 | 确认进入地图页时打印了 `[MapPage] 注册 GPS 事件, eventId = 1002` |
| 事件 ID 不一致 | `MQTTClient` 发的与 `MapPage` 监听的都必须是 `GPS_EVENTID`（1002） |
| Web 尚未加载完 | `isMapReady` 由 `Web.onPageEnd()` 置真，此前的 GPS 数据只更新 UI 不推图；`onPageEnd` 中会用已有坐标补推一次 |
| 地图不再跟随船只 | `autoCenterMap` 仅在点击「定位」时置真，平时不强制居中，属预期行为 |

### 问题 7：多页面监听时事件丢失

`MonitoringPage` 与 `MapPage` 的 `aboutToDisappear()` 调用的是 `emitter.off(EVENTID)` / `emitter.off(GPS_EVENTID)`，**按事件 ID 整体注销，会移除该事件上的所有监听者**。当前两页分用不同 eventId 故无冲突；若后续新增页面监听同一 eventId，需改为按回调精确注销。

---

## 六、参考坐标数据

### 6.1 地图初始视野

```
中心点: [100.15, 36.88]   // 高德 API 为 [lng, lat] 顺序
缩放级别: 10
```

### 6.2 静态监测点（硬编码于 `map.html`）

| 名称 | 纬度 | 经度 | 位置 |
|------|------|------|------|
| 1号监测点 | 37.05 | 100.15 | 高原湖泊北岸 |
| 2号监测点 | 36.88 | 100.55 | 高原湖泊东岸 |
| 3号监测点 | 36.62 | 100.15 | 高原湖泊南岸 |
| 4号监测点 | 36.88 | 99.75 | 高原湖泊西岸 |

### 6.3 单片机端测试值（int32 格式）

```c
g_boat_gps_latitude    = 36585737;   // 36.585737°
g_boat_gps_longitude   = 101818773;  // 101.818773°
g_boat_gps_altitude    = 3200;       // 海拔 3200 米（App 端当前不使用）
g_boat_gps_speed_x100  = 250;        // 2.50 km/h
g_boat_gps_satellites  = 8;
g_boat_gps_fix_quality = 1;          // GPS 定位
g_boat_gps_valid       = 1;
```

---

## 七、代码关键位置

| 文件 | 关键符号 | 说明 |
|------|----------|------|
| MCU `dataExc.c` | `BoatHullGpsDataFrame` | GPS 数据帧结构体 |
| MCU `dataExc.c` | `g_boat_gps_*` | GPS 数据全局变量 |
| MCU `mqtt_connect.c` | `Mqtt_Send_Msgqueue_Write()` | MQTT 发送队列 |
| `utils/MQTTConfig.ets` | `gubTopicName` | GPS 订阅主题配置 |
| `utils/MQTTClient.ets` | `GPS_EVENTID = 1002` | GPS 事件 ID |
| `utils/MQTTClient.ets` | `GPS_DATA_TYPE = 0x0004` | GPS 帧类型常量 |
| `utils/MQTTClient.ets` | `getFrameType()` | 读取偏移 8-9 的类型字段 |
| `utils/GPSDataParser.ets` | `parseGPSData()` | GPS 帧解析与有效性校验 |
| `common/Types.ets` | `GPSData` | GPS 数据类型定义 |
| `views/MapPage.ets` | `onGPSEvent()` | GPS 事件处理 |
| `views/MapPage.ets` | `pushToMap()` | 向 WebView 推送位置与状态 |
| `utils/TrailStorage.ets` | `addPoint()` / `archiveCurrentTrail()` | 轨迹记录与归档 |
| `rawfile/map.html` | `toLngLatFromGps()` | WGS-84 → GCJ-02 单点转换 |
| `rawfile/map.html` | `convertPathFromGps()` | 路径分块转换（40 点/批） |
| `rawfile/map.html` | `updateBoatPosition()` | 更新船只标记与实时轨迹 |

---

## 八、接入检查清单

MCU 侧只要满足以下条件，App 端**无需改动代码**即可显示真实 GPS 数据：

- [ ] 按 `BoatHullGpsDataFrame` 组帧，总长 **64 字节**
- [ ] 帧头 `0x5A5A`、帧尾 `0x6B6B`，全部字段**小端序**
- [ ] 类型字段（偏移 8-9）为 **`0x0004`**
- [ ] 经纬度为 `度 × 1000000` 的 int32，速度为 `km/h × 100` 的 uint16
- [ ] `fixQuality > 0` 且 `isValid = 1`（否则 App 会主动丢弃）
- [ ] 发布到 `MQTTConfig.ets` 中 `gubTopicName` 配置的主题
- [ ] MQTT 载荷为**原始二进制**，不要自行转成十六进制文本再发

App 端在满足上述条件后会自动完成：实时更新船只位置 → 记录并持久化轨迹 → 展示速度/卫星数/定位状态 → 支持历史轨迹回看与归档。

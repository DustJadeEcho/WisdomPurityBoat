/**
 * 监测点分布图页
 * —— 真实地图（Leaflet + OpenStreetMap）
 * —— MQTT GPS 实时定位 + 航迹
 * —— 小船状态动态监测列表
 */
import { webview } from '@kit.ArkWeb';
import { emitter } from '@kit.BasicServicesKit';
import { NavigationFunc, GPSData } from '../common/Types';
import { GPS_EVENTID } from '../utils/MQTTClient';
import { parseGPSData } from '../utils/GPSDataParser';

@Component
export struct MapPage {
  navigate: NavigationFunc = () => {};

  // ===== Web 地图控制器 =====
  private webCtrl: webview.WebviewController = new webview.WebviewController();

  // ===== GPS 状态（@State 驱动 UI 刷新） =====
  @State boatLat: number = 0;
  @State boatLng: number = 0;
  @State boatSpeed: number = 0;
  @State gpsFix: number = 0;
  @State satellites: number = 0;
  @State boatStatusText: string = '等待GPS信号…';
  @State lastUpdate: string = '--:--:--';
  @State isMapReady: boolean = false;

  // ===== emitter 回调（保存引用，用于精确 off） =====
  private gpsCallback: (evt: emitter.EventData) => void = (evt) => this.onGPSEvent(evt);

  // ===== 生命周期 =====
  aboutToAppear(): void {
    console.info('[MapPage] 注册 GPS 事件, eventId =', GPS_EVENTID);
    emitter.on({ eventId: GPS_EVENTID }, this.gpsCallback);
  }

  aboutToDisappear(): void {
    emitter.off(GPS_EVENTID);
  }

  // ===== MQTT GPS 事件处理 =====
  private onGPSEvent(evt: emitter.EventData): void {
    try {
      const raw: string = evt.data?.content as string ?? '';
      if (!raw.trim()) return;

      const gps: GPSData | null = parseGPSData(raw);
      if (!gps || !gps.isValid) return;

      // 更新 @State
      this.boatLat = gps.latitude;
      this.boatLng = gps.longitude;
      this.boatSpeed = gps.speed;
      this.gpsFix = gps.fixStatus;
      this.satellites = gps.satellites;
      this.boatStatusText = gps.fixStatus > 0 ? '定位正常' : '搜索卫星中…';

      const now = new Date();
      this.lastUpdate =
        `${now.getHours().toString().padStart(2, '0')}:` +
          `${now.getMinutes().toString().padStart(2, '0')}:` +
          `${now.getSeconds().toString().padStart(2, '0')}`;

      // 推送到地图
      if (this.isMapReady) {
        this.pushToMap();
      }
    } catch (e) {
      console.error('[MapPage] GPS 事件处理异常:', e);
    }
  }

  // ===== 调用 Web 端 JS 更新地图 =====
  private pushToMap(): void {
    try {
      // 更新位置
      this.webCtrl.runJavaScript(
        `updateBoatPosition(${this.boatLat}, ${this.boatLng})`
      );
      // 更新弹窗状态
      const statusJSON = JSON.stringify({
        lat: this.boatLat,
        lng: this.boatLng,
        speed: this.boatSpeed,
        satellites: this.satellites,
        state: this.boatStatusText
      });
      this.webCtrl.runJavaScript(
        `updateBoatStatus('${statusJSON.replace(/'/g, "\\'")}')`
      );
    } catch (e) {
      console.error('[MapPage] runJavaScript 失败:', e);
    }
  }

  // ===== UI =====
  build() {
    Column() {
      // ───── 顶部导航 ─────
      Row() {
        Image($r('app.media.ic_back'))
          .width(24).height(24)
          .onClick(() => this.navigate(0))
        Text('监测点分布图')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .layoutWeight(1).textAlign(TextAlign.Center).margin({ left: 10 })
      }
      .padding(15).width('100%').backgroundColor('#1890FF')

      // ───── 地图区域（固定高度，不放进 Scroll 以免手势冲突） ─────
      Stack() {
        Web({ src: $rawfile('map.html'), controller: this.webCtrl })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onlineImageAccess(true)
          .width('100%')
          .height('100%')
          .onPageEnd(() => {
            this.isMapReady = true;
            console.info('[MapPage] 地图加载完成');
            // 若已有坐标，立即推送
            if (this.boatLat !== 0 && this.boatLng !== 0) {
              this.pushToMap();
            }
          })

        // GPS 状态角标
        Row() {
          Circle().width(8).height(8)
            .fill(this.gpsFix > 0 ? '#52C41A' : '#FF4D4F')
            .margin({ right: 6 })
          Text(this.gpsFix > 0 ? 'GPS 已定位' : 'GPS 未定位')
            .fontSize(12).fontColor(Color.White)
        }
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .borderRadius(12)
        .backgroundColor('#00000088')
        .position({ x: 10, y: 10 })
      }
      .width('95%')
      .height(300)
      .borderRadius(12)
      .clip(true)
      .margin({ top: 12 })

      // ───── 地图操作按钮 ─────
      Row({ space: 12 }) {
        Button('定位小船')
          .fontSize(14).height(34).borderRadius(8)
          .fontColor(Color.White).backgroundColor('#1890FF')
          .onClick(() => {
            if (this.isMapReady) this.webCtrl.runJavaScript('centerOnBoat()');
          })
        Button('清除轨迹')
          .fontSize(14).height(34).borderRadius(8)
          .fontColor('#1890FF').backgroundColor('#E6F7FF')
          .onClick(() => {
            if (this.isMapReady) this.webCtrl.runJavaScript('clearTrail()');
          })
      }
      .margin({ top: 10 })

      // ───── 下半部分可滚动 ─────
      Scroll() {
        Column() {
          // ── 小船状态卡片 ──
          Column() {
            Row() {
              Text('🚢 智清舟状态')
                .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1890FF')
              Blank()
              Text(this.lastUpdate).fontSize(13).fontColor('#999999')
            }.width('100%').margin({ bottom: 10 })

            Row() {
              this.buildInfoCell('纬度', this.boatLat !== 0 ? this.boatLat.toFixed(6) : '--')
              this.buildInfoCell('经度', this.boatLng !== 0 ? this.boatLng.toFixed(6) : '--')
            }.width('100%').justifyContent(FlexAlign.SpaceBetween)

            Row() {
              this.buildInfoCell('速度', this.boatSpeed > 0 ? `${this.boatSpeed.toFixed(1)} km/h` : '--')
              this.buildInfoCell('卫星数', this.satellites > 0 ? `${this.satellites}` : '--')
            }.width('100%').justifyContent(FlexAlign.SpaceBetween).margin({ top: 8 })

            Row() {
              Circle().width(10).height(10)
                .fill(this.gpsFix > 0 ? '#52C41A' : '#FF4D4F')
                .margin({ right: 8 })
              Text(this.boatStatusText)
                .fontSize(16).fontColor(this.gpsFix > 0 ? '#52C41A' : '#FF4D4F')
            }.margin({ top: 12 })
          }
          .width('90%').padding(15)
          .backgroundColor(Color.White).borderRadius(12)
          .margin({ top: 15 })
          .shadow({ radius: 8, color: '#1890FF22', offsetX: 2, offsetY: 4 })

          // ── 监测点列表标题 ──
          Text('监测点列表')
            .fontSize(18).fontColor('#333333')
            .margin({ top: 20, bottom: 12 })

          // ── 监测点列表 ──
          Column() {
            // 小船（动态条目）
            this.buildBoatListItem()
            // 固定监测点
            this.buildMonitorPoint('1号监测点', '青海湖北岸', '状态正常')
            this.buildMonitorPoint('2号监测点', '青海湖东岸', '状态正常')
            this.buildMonitorPoint('3号监测点', '青海湖南岸', '维护中')
            this.buildMonitorPoint('4号监测点', '青海湖西岸', '状态正常')
          }
          .width('90%').padding(10)
          .backgroundColor(Color.White).borderRadius(12)
          .margin({ bottom: 20 })
        }
        .width('100%').alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollable(ScrollDirection.Vertical)
    }
    .width('100%').height('100%')
    .backgroundColor('#F0F5FF')
  }

  // ───── Builder：小船列表条目 ─────
  @Builder
  buildBoatListItem() {
    Row() {
      Column() {
        Row() {
          Text('🚢').fontSize(16).margin({ right: 6 })
          Text('智清舟').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1890FF')
        }
        if (this.boatLat !== 0 && this.boatLng !== 0) {
          Text(`${this.boatLat.toFixed(4)}°N, ${this.boatLng.toFixed(4)}°E`)
            .fontSize(13).fontColor('#666666').margin({ top: 4 })
        } else {
          Text('等待定位数据…').fontSize(13).fontColor('#999999').margin({ top: 4 })
        }
      }.layoutWeight(1)

      Column() {
        Row() {
          Circle().width(8).height(8)
            .fill(this.gpsFix > 0 ? '#52C41A' : '#FAAD14')
            .margin({ right: 6 })
          Text(this.gpsFix > 0 ? '在线' : '离线')
            .fontSize(14).fontColor(this.gpsFix > 0 ? '#52C41A' : '#FAAD14')
        }
        if (this.lastUpdate !== '--:--:--') {
          Text(this.lastUpdate).fontSize(12).fontColor('#999999').margin({ top: 3 })
        }
      }
    }
    .padding(15)
    .backgroundColor('#E6F7FF')
    .borderRadius(8)
    .margin({ bottom: 4 })
  }

  // ───── Builder：信息小格子 ─────
  @Builder
  buildInfoCell(label: string, value: string) {
    Column() {
      Text(label).fontSize(13).fontColor('#999999')
      Text(value).fontSize(16).fontColor('#333333').margin({ top: 4 })
    }
    .width('48%').padding(8)
    .backgroundColor('#F6F9FF').borderRadius(8)
  }

  // ───── Builder：监测点列表条目 ─────
  @Builder
  buildMonitorPoint(name: string, location: string, status: string) {
    Row() {
      Column() {
        Text(name).fontSize(18).fontColor('#333333')
        Text(location).fontSize(14).fontColor('#666666')
      }.layoutWeight(1)

      Text(status).fontSize(16)
        .fontColor(status === '维护中' ? '#FAAD14' : '#52C41A')
    }
    .padding(15)
    .border({ width: { bottom: 1 }, color: '#F0F0F0' })
  }
}
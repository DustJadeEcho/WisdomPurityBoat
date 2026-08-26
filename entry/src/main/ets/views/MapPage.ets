/**
 * 监测点分布图页面 - 海洋主题
 */
import { webview } from '@kit.ArkWeb';
import { emitter } from '@kit.BasicServicesKit';
import { NavigationFunc, GPSData } from '../common/Types';
import { GPS_EVENTID } from '../utils/MQTTClient';
import { parseGPSData } from '../utils/GPSDataParser';
import TrailStorage, { TrailPoint, TrailRecord } from '../utils/TrailStorage';
import { common } from '@kit.AbilityKit';
import { LXGW_FONT, OceanPalette, OceanGradients, OceanFont, OceanRadius, GradientOption } from '../common/Theme';

@Component
export struct MapPage {
  navigate: NavigationFunc = () => {};

  private webCtrl: webview.WebviewController = new webview.WebviewController();

  @State boatLat: number = 0;
  @State boatLng: number = 0;
  @State boatSpeed: number = 0;
  @State gpsFix: number = 0;
  @State satellites: number = 0;
  @State boatStatusText: string = '等待GPS信号…';
  @State lastUpdate: string = '--:--:--';
  @State isMapReady: boolean = false;
  @State autoCenterMap: boolean = true;

  private trailStorage: TrailStorage = TrailStorage.getInstance();
  @State historyTrails: TrailRecord[] = [];
  @State showHistoryDialog: boolean = false;

  private gpsCallback: (evt: emitter.EventData) => void = (evt) => this.onGPSEvent(evt);

  aboutToAppear(): void {
      console.info('[MapPage] 注册 GPS 事件, eventId =', GPS_EVENTID);
    emitter.on({ eventId: GPS_EVENTID }, this.gpsCallback);
    this.initTrailStorage();
    this.loadHistoryTrails();
  }

  private async initTrailStorage(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      await this.trailStorage.init(context);
    } catch (e) {
      console.error('[MapPage] 轨迹存储初始化失败', e);
    }
  }

  private async loadHistoryTrails(): Promise<void> {
    this.historyTrails = await this.trailStorage.getHistoryTrails();
  }

  aboutToDisappear(): void {
    emitter.off(GPS_EVENTID);
  }

  private onGPSEvent(evt: emitter.EventData): void {
    try {
      const raw: string = evt.data?.content as string ?? '';
      if (!raw.trim()) return;

      const gps: GPSData | null = parseGPSData(raw);
      if (!gps || !gps.isValid) return;

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

      if (this.isMapReady) {
        this.pushToMap(this.autoCenterMap);
      }

      if (gps.fixStatus > 0) {
        this.trailStorage.addPoint(gps.latitude, gps.longitude, gps.speed);
      }
    } catch (e) {
      console.error('[MapPage] GPS 事件处理异常:', e);
    }
  }

  private pushToMap(center: boolean = false): void {
    try {
      this.webCtrl.runJavaScript(
        `updateBoatPosition(${this.boatLat}, ${this.boatLng})`
      );
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
      if (center) {
        this.webCtrl.runJavaScript('centerOnBoat()');
      }
    } catch (e) {
      console.error('[MapPage] runJavaScript 失败:', e);
    }
  }

  private locateLatestPosition(): void {
    this.autoCenterMap = true;
    if (this.boatLat === 0 || this.boatLng === 0) {
      this.boatStatusText = '等待GPS定位数据';
      return;
    }
    if (this.isMapReady) {
      this.pushToMap(true);
    }
  }


  build() {
    Column() {
      // 顶部栏
      Row() {
        Image($r('app.media.ic_back'))
          .width(24).height(24)
          .fillColor(OceanPalette.TEXT_WHITE)
          .onClick(() => this.navigate(0))
        Text('监测点分布图')
          .fontSize(OceanFont.HEADING)
          .fontWeight(FontWeight.Bold)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_WHITE)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ left: 10, right: 34 })
      }
      .padding({ left: 18, right: 18, top: 52, bottom: 14 })
      .width('100%')
      .backgroundColor('#33002244')
      .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK, {
        colorMode: ThemeColorMode.DARK,
        adaptiveColor: AdaptiveColor.DEFAULT
      })

      // 地图区域（带玻璃描边+角标）
      Stack() {
        Web({ src: $rawfile('map.html'), controller: this.webCtrl })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onlineImageAccess(true)
          .width('100%').height('100%')
          .onPageEnd(() => {
            this.isMapReady = true;
            if (this.boatLat !== 0 && this.boatLng !== 0) {
              this.pushToMap(true);
            }
          })

        // GPS 状态角标
        Row() {
          Circle().width(8).height(8)
            .fill(this.gpsFix > 0 ? OceanPalette.ACCENT_KELP : OceanPalette.ACCENT_CORAL)
            .shadow({
              radius: 8,
              color: this.gpsFix > 0 ? OceanPalette.ACCENT_KELP : OceanPalette.ACCENT_CORAL,
              offsetX: 0, offsetY: 0
            })
            .margin({ right: 6 })
          Text(this.gpsFix > 0 ? 'GPS 已定位' : 'GPS 未定位')
            .fontSize(OceanFont.MICRO)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_WHITE)
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(16)
        .backgroundColor('#66002244')
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
        .border({ width: 1, color: OceanPalette.GLASS_BORDER })
        .position({ x: 12, y: 12 })
      }
      .width('95%')
      .height(300)
      .borderRadius(OceanRadius.CARD)
      .clip(true)
      .border({ width: 1, color: OceanPalette.GLASS_BORDER })
      .shadow({ radius: 30, color: '#550077B6', offsetX: 0, offsetY: 8 })
      .margin({ top: 14 })

      // 玻璃按钮工具栏
      Row({ space: 8 }) {
        this.buildToolBtn('定位', OceanGradients.BUTTON_PRIMARY, () => {
          this.locateLatestPosition();
        })
        this.buildToolBtn('清除', OceanGradients.BUTTON_ACCENT, async () => {
          if (this.isMapReady) this.webCtrl.runJavaScript('clearTrail()');
          await this.trailStorage.clearCurrentTrail();
        })
        this.buildToolBtn('历史', OceanGradients.BUTTON_SUCCESS, async () => {
          await this.loadHistoryTrails();
          this.showHistoryDialog = true;
        })
        this.buildToolBtn('归档', OceanGradients.BUTTON_ACCENT, async () => {
          await this.trailStorage.archiveCurrentTrail();
          if (this.isMapReady) this.webCtrl.runJavaScript('clearTrail()');
        })
      }
      .margin({ top: 12 })

      // 涓嬪崐閮ㄥ彲婊氬姩
      Scroll() {
        Column() {
          // 鏅烘竻鑸熺姸鎬佸崱
          Column() {
            Row() {
              Text('🚢 智清舟状态')
                .fontSize(OceanFont.SUBHEAD)
                .fontWeight(FontWeight.Bold)
                .fontFamily(LXGW_FONT)
                .fontColor(OceanPalette.TEXT_ON_GLASS)
              Blank()
              Text(this.lastUpdate)
                .fontSize(OceanFont.MICRO)
                .fontFamily(LXGW_FONT)
                .fontColor(OceanPalette.TEXT_MUTED)
            }.width('100%').margin({ bottom: 12 })

            Row() {
              Column() {
                Text('纬度')
                  .fontSize(OceanFont.MICRO)
                  .fontFamily(LXGW_FONT)
                  .fontColor(OceanPalette.TEXT_MUTED)
                Text(this.boatLat !== 0 ? this.boatLat.toFixed(6) : '--')
                  .fontSize(OceanFont.BODY)
                  .fontFamily(LXGW_FONT)
                  .fontColor(OceanPalette.TEXT_ON_GLASS)
                  .margin({ top: 4 })
              }
              .width('48%').padding(10)
              .alignItems(HorizontalAlign.Start)
              .backgroundColor('#80EAF6FB')
              .borderRadius(12)
              .border({ width: 0.5, color: '#66FFFFFF' })

              Column() {
                Text('经度')
                  .fontSize(OceanFont.MICRO)
                  .fontFamily(LXGW_FONT)
                  .fontColor(OceanPalette.TEXT_MUTED)
                Text(this.boatLng !== 0 ? this.boatLng.toFixed(6) : '--')
                  .fontSize(OceanFont.BODY)
                  .fontFamily(LXGW_FONT)
                  .fontColor(OceanPalette.TEXT_ON_GLASS)
                  .margin({ top: 4 })
              }
              .width('48%').padding(10)
              .alignItems(HorizontalAlign.Start)
              .backgroundColor('#80EAF6FB')
              .borderRadius(12)
              .border({ width: 0.5, color: '#66FFFFFF' })
            }.width('100%').justifyContent(FlexAlign.SpaceBetween)

            Row() {
              Column() {
                Text('速度')
                  .fontSize(OceanFont.MICRO)
                  .fontFamily(LXGW_FONT)
                  .fontColor(OceanPalette.TEXT_MUTED)
                Text(this.boatLat !== 0 ? `${this.boatSpeed.toFixed(1)} km/h` : '--')
                  .fontSize(OceanFont.BODY)
                  .fontFamily(LXGW_FONT)
                  .fontColor(OceanPalette.TEXT_ON_GLASS)
                  .margin({ top: 4 })
              }
              .width('48%').padding(10)
              .alignItems(HorizontalAlign.Start)
              .backgroundColor('#80EAF6FB')
              .borderRadius(12)
              .border({ width: 0.5, color: '#66FFFFFF' })

              Column() {
                Text('卫星')
                  .fontSize(OceanFont.MICRO)
                  .fontFamily(LXGW_FONT)
                  .fontColor(OceanPalette.TEXT_MUTED)
                Text(this.satellites > 0 ? `${this.satellites}` : '--')
                  .fontSize(OceanFont.BODY)
                  .fontFamily(LXGW_FONT)
                  .fontColor(OceanPalette.TEXT_ON_GLASS)
                  .margin({ top: 4 })
              }
              .width('48%').padding(10)
              .alignItems(HorizontalAlign.Start)
              .backgroundColor('#80EAF6FB')
              .borderRadius(12)
              .border({ width: 0.5, color: '#66FFFFFF' })
            }.width('100%').justifyContent(FlexAlign.SpaceBetween).margin({ top: 8 })

            Row() {
              Circle().width(10).height(10)
                .fill(this.gpsFix > 0 ? OceanPalette.ACCENT_KELP : OceanPalette.ACCENT_CORAL)
                .shadow({
                  radius: 8,
                  color: this.gpsFix > 0 ? OceanPalette.ACCENT_KELP : OceanPalette.ACCENT_CORAL,
                  offsetX: 0, offsetY: 0
                })
                .margin({ right: 8 })
              Text(this.boatStatusText)
                .fontSize(OceanFont.BODY)
                .fontFamily(LXGW_FONT)
                .fontColor(this.gpsFix > 0 ? OceanPalette.ACCENT_KELP : OceanPalette.ACCENT_CORAL)
            }.margin({ top: 14 })
          }
          .width('90%').padding(18)
          .backgroundColor(OceanPalette.GLASS_WHITE)
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .borderRadius(OceanRadius.CARD)
          .border({ width: 1, color: OceanPalette.GLASS_BORDER })
          .shadow({ radius: 24, color: '#440077B6', offsetX: 0, offsetY: 8 })
          .margin({ top: 16 })

          // 监测点列表
          Text('监测点列表')
            .fontSize(OceanFont.SUBHEAD)
            .fontWeight(FontWeight.Medium)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_WHITE)
            .margin({ top: 22, bottom: 10, left: 22 })
            .alignSelf(ItemAlign.Start)

          Column() {
            this.buildBoatListItem()
            this.buildMonitorPoint('1号监测点', '高原湖泊北岸', '状态正常')
            this.buildMonitorPoint('2号监测点', '高原湖泊东岸', '状态正常')
            this.buildMonitorPoint('3号监测点', '高原湖泊南岸', '维护中')
            this.buildMonitorPoint('4号监测点', '高原湖泊西岸', '状态正常')
          }
          .width('90%').padding(10)
          .backgroundColor(OceanPalette.GLASS_WHITE)
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .borderRadius(OceanRadius.CARD)
          .border({ width: 1, color: OceanPalette.GLASS_BORDER })
          .shadow({ radius: 24, color: '#330077B6', offsetX: 0, offsetY: 8 })
          .margin({ bottom: 22 })
        }
        .width('100%').alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('100%')
    .bindSheet($$this.showHistoryDialog, this.buildHistorySheet(), {
      height: 500,
      dragBar: true,
      backgroundColor: '#F7FBFD'
    })
  }

  @Builder
  buildToolBtn(label: string, grad: GradientOption, onTap: () => void) {
    Text(label)
      .fontSize(OceanFont.CAPTION)
      .fontFamily(LXGW_FONT)
      .fontColor(OceanPalette.TEXT_WHITE)
      .fontWeight(FontWeight.Medium)
      .height(36)
      .padding({ left: 18, right: 18 })
      .borderRadius(18)
      .linearGradient(grad)
      .shadow({ radius: 12, color: OceanPalette.HALO_BLUE, offsetX: 0, offsetY: 4 })
      .onClick(onTap)
  }

  @Builder
  buildBoatListItem() {
    Row() {
      Column() {
        Row() {
          Text('🚢').fontSize(18).margin({ right: 6 })
          Text('智清舟')
            .fontSize(OceanFont.SUBHEAD)
            .fontWeight(FontWeight.Bold)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.OCEAN)
        }
        if (this.boatLat !== 0 && this.boatLng !== 0) {
          Text(`${this.boatLat.toFixed(4)}°N, ${this.boatLng.toFixed(4)}°E`)
            .fontSize(OceanFont.MICRO)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_SECONDARY)
            .margin({ top: 4 })
        } else {
          Text('等待定位数据…')
            .fontSize(OceanFont.MICRO)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_MUTED)
            .margin({ top: 4 })
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      Column() {
        Row() {
          Circle().width(8).height(8)
            .fill(this.gpsFix > 0 ? OceanPalette.ACCENT_KELP : OceanPalette.ACCENT_GOLD)
            .shadow({
              radius: 6,
              color: this.gpsFix > 0 ? OceanPalette.ACCENT_KELP : OceanPalette.ACCENT_GOLD,
              offsetX: 0, offsetY: 0
            })
            .margin({ right: 6 })
          Text(this.gpsFix > 0 ? '在线' : '离线')
            .fontSize(OceanFont.CAPTION)
            .fontFamily(LXGW_FONT)
            .fontColor(this.gpsFix > 0 ? OceanPalette.ACCENT_KELP : OceanPalette.ACCENT_GOLD)
        }
        if (this.lastUpdate !== '--:--:--') {
          Text(this.lastUpdate)
            .fontSize(OceanFont.MICRO)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_MUTED)
            .margin({ top: 3 })
        }
      }.alignItems(HorizontalAlign.End)
    }
    .padding(14)
    .backgroundColor('#99CAF0F8')
    .borderRadius(OceanRadius.BUTTON)
    .border({ width: 1, color: '#B3FFFFFF' })
    .margin({ bottom: 6 })
  }

  @Builder
  buildInfoCell(label: string, value: string) {
    Column() {
      Text(label)
        .fontSize(OceanFont.MICRO)
        .fontFamily(LXGW_FONT)
        .fontColor(OceanPalette.TEXT_MUTED)
      Text(value)
        .fontSize(OceanFont.BODY)
        .fontFamily(LXGW_FONT)
        .fontColor(OceanPalette.TEXT_ON_GLASS)
        .margin({ top: 4 })
    }
    .width('48%').padding(10)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#80EAF6FB')
    .borderRadius(12)
    .border({ width: 0.5, color: '#66FFFFFF' })
  }

  @Builder
  buildMonitorPoint(name: string, location: string, status: string) {
    Row() {
      Column() {
        Text(name)
          .fontSize(OceanFont.BODY)
          .fontWeight(FontWeight.Medium)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_ON_GLASS)
        Text(location)
          .fontSize(OceanFont.MICRO)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_SECONDARY)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      Text(status)
        .fontSize(OceanFont.CAPTION)
        .fontFamily(LXGW_FONT)
        .fontColor(status === '维护中' ? OceanPalette.ACCENT_GOLD : OceanPalette.ACCENT_KELP)
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor('#E6FFFFFF')
        .borderRadius(10)
    }
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .border({ width: { bottom: 0.5 }, color: '#66CAF0F8' })
  }

  @Builder
  buildHistorySheet() {
    Column() {
      Text('历史轨迹记录')
        .fontSize(OceanFont.HEADING)
        .fontWeight(FontWeight.Bold)
        .fontFamily(LXGW_FONT)
        .fontColor(OceanPalette.TEXT_ON_GLASS)
        .margin({ top: 22, bottom: 16 })

      if (this.historyTrails.length === 0) {
        Column() {
          Text('暂无历史轨迹')
            .fontSize(OceanFont.BODY)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_MUTED)
        }
        .width('100%').height(200)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.historyTrails, (record: TrailRecord) => {
              this.buildHistoryItem(record);
            })
          }
          .width('90%')
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }

      Text('关闭')
        .fontSize(OceanFont.BODY)
        .fontFamily(LXGW_FONT)
        .fontColor(OceanPalette.TEXT_WHITE)
        .fontWeight(FontWeight.Medium)
        .height(46).width('90%')
        .textAlign(TextAlign.Center)
        .linearGradient(OceanGradients.BUTTON_PRIMARY)
        .borderRadius(OceanRadius.BUTTON)
        .shadow({ radius: 16, color: OceanPalette.HALO_BLUE, offsetX: 0, offsetY: 4 })
        .margin({ top: 16, bottom: 20 })
        .onClick(() => {
          this.showHistoryDialog = false;
        })
    }
    .width('100%').height('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildHistoryItem(record: TrailRecord) {
    Column() {
      Row() {
        Text(record.date)
          .fontSize(OceanFont.SUBHEAD)
          .fontWeight(FontWeight.Bold)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.OCEAN)
        Blank()
        Text(`${record.points.length} 个点`)
          .fontSize(OceanFont.CAPTION)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_MUTED)
      }.width('100%')

      Row({ space: 8 }) {
        Text('查看轨迹')
          .fontSize(OceanFont.CAPTION)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_WHITE)
          .height(32).padding({ left: 14, right: 14 })
          .borderRadius(12)
          .linearGradient(OceanGradients.BUTTON_SUCCESS)
          .onClick(async () => {
            await this.showTrailOnMap(record.points);
            this.showHistoryDialog = false;
          })
        Text('删除')
          .fontSize(OceanFont.CAPTION)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.ACCENT_DANGER)
          .height(32).padding({ left: 14, right: 14 })
          .borderRadius(12)
          .backgroundColor('#FFECEE')
          .border({ width: 1, color: OceanPalette.ACCENT_DANGER + '66' })
          .onClick(async () => {
            await this.trailStorage.clearAllHistory();
            await this.loadHistoryTrails();
          })
      }
      .margin({ top: 12 })
    }
    .width('100%').padding(15)
    .backgroundColor('#CCEAF6FB')
    .borderRadius(OceanRadius.CARD)
    .border({ width: 1, color: '#99FFFFFF' })
  }

  private async showTrailOnMap(points: TrailPoint[]): Promise<void> {
    if (!this.isMapReady || points.length === 0) return;

    this.webCtrl.runJavaScript('clearTrail()');

    const coords = points.map(p => `[${p.lat},${p.lng}]`).join(',');
    this.webCtrl.runJavaScript(`showHistoryTrail([${coords}])`);

    const centerLat = points[Math.floor(points.length / 2)].lat;
    const centerLng = points[Math.floor(points.length / 2)].lng;
    this.webCtrl.runJavaScript(`map.setView([${centerLat},${centerLng}], 13)`);
  }
}

/**
 * 实时监测页 —— 展示 MQTT 推送的水质数据
 */
import relationalStore from '@ohos.data.relationalStore';
import { Context } from '@ohos.abilityAccessCtrl';
import { emitter } from '@kit.BasicServicesKit';
import { NavigationFunc, StatusResult } from '../common/Types';
import { EVENTID } from '../utils/MQTTClient';
import { parseWaterData } from '../utils/WaterDataParser';
import { LXGW_FONT, OceanPalette, OceanFont, OceanRadius } from '../common/Theme';

@Component
export struct MonitoringPage {
  @State phValue: number = 0;
  @State turbidity: number = 0;
  @State orpValue: number = 0;
  @State dissolvedOxygen: number = 0;
  @State tdsValue: number = 0;
  @State conductivity: number = 0;
  @State temperature: number = 0;
  @State subMsg: string = '';

  navigate: NavigationFunc = () => {};

  private rdbStore: relationalStore.RdbStore | null = null;
  private readonly DB_CONFIG: relationalStore.StoreConfig = {
    name: 'WaterQualityDB.db',
    securityLevel: relationalStore.SecurityLevel.S1
  };
  private readonly TABLE_NAME: string = 'sensor_data';
  private context: Context = getContext(this) as Context;
  timerID: number = 0;

  // ===== 生命周期 =====
  private waterCallback: (evt: emitter.EventData) => void = (evt) => {
    // 把原来 aboutToAppear 里 emitter.on 的回调体搬到这里
    try {
      const rawData: string = evt.data?.content as string ?? '';
      this.subMsg = rawData;
      if (!rawData.trim()) return;

      const result = parseWaterData(rawData);
      if (result) {
        this.temperature = result.tempVal;
        this.phValue     = result.phVal;
        this.turbidity   = result.turbVal;
        this.orpValue    = result.orpVal;
        this.tdsValue    = result.tdsVal;
      }
    } catch (error) {
      console.error('处理水质数据时发生异常:', error);
    }
  };

  // ② aboutToAppear 简化
  aboutToAppear(): void {
    emitter.on({ eventId: EVENTID }, this.waterCallback);
  }

  // ③ aboutToDisappear 精确注销
  aboutToDisappear(): void {
    clearInterval(this.timerID);
    emitter.off(EVENTID);      // 仍可用，因为 GPS 已走独立 eventId
  }

  // ===== 数据库操作 =====
  async initDatabase() {
    try {
      this.rdbStore = await relationalStore.getRdbStore(this.context, this.DB_CONFIG);
      await this.rdbStore.executeSql(
        `CREATE TABLE IF NOT EXISTS ${this.TABLE_NAME} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ph REAL, turbidity REAL, orp REAL, oxygen REAL,
          tds REAL, conductivity REAL, temperature REAL,
          timestamp INTEGER
        )`
      );
    } catch (err) {
      console.error(`Database init failed: ${err}`);
    }
  }

  async saveSensorData() {
    if (!this.rdbStore) return;
    const valueBucket: relationalStore.ValuesBucket = {
      'ph': this.phValue, 'turbidity': this.turbidity,
      'orp': this.orpValue, 'oxygen': this.dissolvedOxygen,
      'tds': this.tdsValue, 'conductivity': this.conductivity,
      'temperature': this.temperature, 'timestamp': new Date().getTime()
    };
    try {
      await this.rdbStore.insert(this.TABLE_NAME, valueBucket);
    } catch (err) {
      console.error(`数据保存失败: ${err}`);
    }
  }

  // ===== 状态判定 =====
  private getPHStatus(value: number): StatusResult {
    if (value < 6) return { status: '酸性', color: 0xFFFF7A8A };
    if (value > 8) return { status: '碱性', color: 0xFFFFD166 };
    return { status: '正常', color: 0xFF3DDC97 };
  }

  private getTurbidityStatus(value: number): StatusResult {
    if (value > 8) return { status: '浑浊', color: 0xFFFF7A8A };
    if (value > 5) return { status: '微浊', color: 0xFFFFD166 };
    return { status: '清澈', color: 0xFF3DDC97 };
  }

  private hasLiveData(): boolean {
    return this.subMsg.trim().length > 0;
  }

  // ===== UI =====
  build() {
    Column() {
      this.buildTopBar()

      Scroll() {
        Column() {
          this.buildOverviewCard()

          Text('水质参数')
            .fontSize(OceanFont.SUBHEAD)
            .fontWeight(FontWeight.Medium)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_WHITE)
            .margin({ top: 22, bottom: 12, left: 22 })
            .alignSelf(ItemAlign.Start)

          Column() {
            this.buildPHMetricRow()
            this.buildTurbidityMetricRow()
            this.buildORPMetricRow()
            this.buildTDSMetricRow()
            this.buildTemperatureMetricRow()
          }
          .width('90%')
          .padding(6)
          .backgroundColor(OceanPalette.GLASS_WHITE)
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .borderRadius(OceanRadius.CARD)
          .border({ width: 1, color: OceanPalette.GLASS_BORDER })
          .shadow({ radius: 28, color: '#330077B6', offsetX: 0, offsetY: 8 })

          if (this.hasLiveData()) {
            this.buildMessageCard()
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 20, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('100%')
  }

  @Builder
  buildTopBar() {
    Row() {
      Image($r('app.media.ic_back'))
        .width(24).height(24)
        .fillColor(OceanPalette.TEXT_WHITE)
        .onClick(() => this.navigate(0))
      Text('实时监测')
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
  }

  @Builder
  buildOverviewCard() {
    Column() {
      Row() {
        Column() {
          Text('星瞳水质')
            .fontSize(OceanFont.HEADING)
            .fontWeight(FontWeight.Bold)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_ON_GLASS)
          Text(this.hasLiveData() ? '数据接收中' : '等待水质数据')
            .fontSize(OceanFont.CAPTION)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_SECONDARY)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row() {
          Circle().width(9).height(9)
            .fill(this.hasLiveData() ? OceanPalette.ACCENT_KELP : OceanPalette.ACCENT_GOLD)
            .shadow({
              radius: 8,
              color: this.hasLiveData() ? OceanPalette.ACCENT_KELP : OceanPalette.ACCENT_GOLD,
              offsetX: 0,
              offsetY: 0
            })
            .margin({ right: 6 })
          Text(this.hasLiveData() ? '在线' : '待机')
            .fontSize(OceanFont.CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontFamily(LXGW_FONT)
            .fontColor(this.hasLiveData() ? OceanPalette.ACCENT_KELP : OceanPalette.ACCENT_GOLD)
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(16)
        .backgroundColor('#E6FFFFFF')
      }
      .width('100%')

      Row() {
        Column() {
          Text('PH')
            .fontSize(OceanFont.MICRO)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_MUTED)
          Text(`${this.phValue.toFixed(2)}`)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontFamily(LXGW_FONT)
            .fontColor(this.getPHStatus(this.phValue).color)
            .margin({ top: 4 })
          Text(this.getPHStatus(this.phValue).status)
            .fontSize(OceanFont.CAPTION)
            .fontFamily(LXGW_FONT)
            .fontColor(this.getPHStatus(this.phValue).color)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column() {
          Text('温度')
            .fontSize(OceanFont.MICRO)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_MUTED)
          Row() {
            Text(`${this.temperature.toFixed(2)}`)
              .fontSize(32)
              .fontWeight(FontWeight.Bold)
              .fontFamily(LXGW_FONT)
              .fontColor(OceanPalette.OCEAN)
            Text(' ℃')
              .fontSize(OceanFont.CAPTION)
              .fontFamily(LXGW_FONT)
              .fontColor(OceanPalette.TEXT_SECONDARY)
              .margin({ bottom: 5 })
          }
          .alignItems(VerticalAlign.Bottom)
          .margin({ top: 4 })
          Text('当前水温')
            .fontSize(OceanFont.CAPTION)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_SECONDARY)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .margin({ top: 18 })
    }
    .width('90%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(OceanPalette.GLASS_WHITE)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(OceanRadius.CARD)
    .border({ width: 1, color: OceanPalette.GLASS_BORDER })
    .shadow({ radius: 28, color: '#330077B6', offsetX: 0, offsetY: 8 })
  }

  @Builder
  buildPHMetricRow() {
    Row() {
      Column() {
        Text('🧪')
          .fontSize(18)
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor('#E6FFFFFF')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text('PH值')
          .fontSize(OceanFont.CAPTION)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_SECONDARY)
        Row() {
          Text(`${this.phValue.toFixed(2)}`)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_ON_GLASS)
          Text('pH')
            .fontSize(OceanFont.MICRO)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_MUTED)
            .margin({ left: 5, bottom: 3 })
        }
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.getPHStatus(this.phValue).status)
        .fontSize(OceanFont.CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontFamily(LXGW_FONT)
        .fontColor(this.getPHStatus(this.phValue).color)
        .padding({ left: 12, right: 12, top: 5, bottom: 5 })
        .backgroundColor('#E6FFFFFF')
        .borderRadius(14)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .border({ width: { bottom: 0.5 }, color: '#66CAF0F8' })
  }

  @Builder
  buildTurbidityMetricRow() {
    Row() {
      Column() {
        Text('💧')
          .fontSize(18)
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor('#E6FFFFFF')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text('浊度')
          .fontSize(OceanFont.CAPTION)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_SECONDARY)
        Row() {
          Text(`${this.turbidity.toFixed(2)}`)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_ON_GLASS)
          Text('NTU')
            .fontSize(OceanFont.MICRO)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_MUTED)
            .margin({ left: 5, bottom: 3 })
        }
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.getTurbidityStatus(this.turbidity).status)
        .fontSize(OceanFont.CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontFamily(LXGW_FONT)
        .fontColor(this.getTurbidityStatus(this.turbidity).color)
        .padding({ left: 12, right: 12, top: 5, bottom: 5 })
        .backgroundColor('#E6FFFFFF')
        .borderRadius(14)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .border({ width: { bottom: 0.5 }, color: '#66CAF0F8' })
  }

  @Builder
  buildORPMetricRow() {
    Row() {
      Column() {
        Text('⚡')
          .fontSize(18)
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor('#E6FFFFFF')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text('ORP')
          .fontSize(OceanFont.CAPTION)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_SECONDARY)
        Row() {
          Text(`${this.orpValue.toFixed(2)}`)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_ON_GLASS)
          Text('mV')
            .fontSize(OceanFont.MICRO)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_MUTED)
            .margin({ left: 5, bottom: 3 })
        }
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .border({ width: { bottom: 0.5 }, color: '#66CAF0F8' })
  }

  @Builder
  buildTDSMetricRow() {
    Row() {
      Column() {
        Text('🧂')
          .fontSize(18)
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor('#E6FFFFFF')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text('TDS')
          .fontSize(OceanFont.CAPTION)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_SECONDARY)
        Row() {
          Text(`${this.tdsValue.toFixed(2)}`)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_ON_GLASS)
          Text('ppm')
            .fontSize(OceanFont.MICRO)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_MUTED)
            .margin({ left: 5, bottom: 3 })
        }
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .border({ width: { bottom: 0.5 }, color: '#66CAF0F8' })
  }

  @Builder
  buildTemperatureMetricRow() {
    Row() {
      Column() {
        Text('🌡️')
          .fontSize(18)
      }
      .width(38)
      .height(38)
      .borderRadius(19)
      .backgroundColor('#E6FFFFFF')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text('温度')
          .fontSize(OceanFont.CAPTION)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_SECONDARY)
        Row() {
          Text(`${this.temperature.toFixed(2)}`)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_ON_GLASS)
          Text('℃')
            .fontSize(OceanFont.MICRO)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_MUTED)
            .margin({ left: 5, bottom: 3 })
        }
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 14, bottom: 14 })
    .border({ width: 0 })
  }

  @Builder
  buildMessageCard() {
    Column() {
      Row() {
        Text('📡')
          .fontSize(18)
          .margin({ right: 8 })
        Text('最新报文')
          .fontSize(OceanFont.SUBHEAD)
          .fontWeight(FontWeight.Medium)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_ON_GLASS)
      }
      .width('100%')
      .margin({ bottom: 10 })

      Text(this.subMsg)
        .fontSize(OceanFont.CAPTION)
        .fontFamily(LXGW_FONT)
        .fontColor(OceanPalette.TEXT_SECONDARY)
        .lineHeight(20)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('90%')
    .padding(18)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(OceanPalette.GLASS_WHITE)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(OceanRadius.CARD)
    .border({ width: 1, color: OceanPalette.GLASS_BORDER })
    .shadow({ radius: 24, color: '#330077B6', offsetX: 0, offsetY: 8 })
    .margin({ top: 18, bottom: 4 })
  }
}

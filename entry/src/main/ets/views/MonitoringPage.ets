/**
 * 实时监测页 —— 展示 MQTT 推送的水质数据
 */
import relationalStore from '@ohos.data.relationalStore';
import { Context } from '@ohos.abilityAccessCtrl';
import { emitter } from '@kit.BasicServicesKit';
import { NavigationFunc, StatusResult } from '../common/Types';
import { EVENTID } from '../utils/MQTTClient';
import { parseWaterData } from '../utils/WaterDataParser';

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
    if (value < 6) return { status: '酸性', color: 0xFFFF4500 };
    if (value > 8) return { status: '碱性', color: 0xFFFFA500 };
    return { status: '正常', color: 0xFF52C41A };
  }

  private getTurbidityStatus(value: number): StatusResult {
    if (value > 8) return { status: '浑浊', color: 0xFFFF4500 };
    if (value > 5) return { status: '微浊', color: 0xFFFFA500 };
    return { status: '清澈', color: 0xFF52C41A };
  }

  // ===== UI =====
  build() {
    Column() {
      // 顶部导航
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24).onClick(() => this.navigate(0))
        Text('实时监测')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .layoutWeight(1).textAlign(TextAlign.Center).margin({ left: 10 })
      }
      .padding(15).width('100%').backgroundColor('#1890FF')

      // 欢迎标题
      Column() {
        Text('欢迎来到').fontSize(24).fontColor('#333333')
        Text('青海湖智清舟')
          .fontSize(28).fontWeight(FontWeight.Bold).fontColor('#1890FF')
          .margin({ top: 5, bottom: 20 })
      }
      .width('100%').margin({ top: 20 })

      // ★ 参数卡片 —— 直接内联引用 this.xxx，确保 @State 响应式刷新
      Column() {
        // PH值
        Row() {
          Text('PH值：').fontSize(20).fontColor('#333333')
          Text(`${this.phValue.toFixed(2)}`)
            .fontSize(20).fontColor('#1890FF').margin({ left: 5, right: 10 })
          Text(this.getPHStatus(this.phValue).status)
            .fontSize(20).fontColor(this.getPHStatus(this.phValue).color).margin({ right: 10 })
          Text('pH').fontSize(20).fontColor('#666666')
        }
        .padding(15).width('100%').border({ width: { bottom: 1 }, color: '#F0F0F0' })

        // 浊度
        Row() {
          Text('浊度：').fontSize(20).fontColor('#333333')
          Text(`${this.turbidity.toFixed(2)}`)
            .fontSize(20).fontColor('#1890FF').margin({ left: 5, right: 10 })
          Text(this.getTurbidityStatus(this.turbidity).status)
            .fontSize(20).fontColor(this.getTurbidityStatus(this.turbidity).color).margin({ right: 10 })
          Text('NTU').fontSize(20).fontColor('#666666')
        }
        .padding(15).width('100%').border({ width: { bottom: 1 }, color: '#F0F0F0' })

        // ORP
        Row() {
          Text('ORP：').fontSize(20).fontColor('#333333')
          Text(`${this.orpValue.toFixed(2)}`)
            .fontSize(20).fontColor('#1890FF').margin({ left: 5, right: 10 })
          Text('mV').fontSize(20).fontColor('#666666')
        }
        .padding(15).width('100%').border({ width: { bottom: 1 }, color: '#F0F0F0' })

        // TDS
        Row() {
          Text('TDS：').fontSize(20).fontColor('#333333')
          Text(`${this.tdsValue.toFixed(2)}`)
            .fontSize(20).fontColor('#1890FF').margin({ left: 5, right: 10 })
          Text('ppm').fontSize(20).fontColor('#666666')
        }
        .padding(15).width('100%').border({ width: { bottom: 1 }, color: '#F0F0F0' })

        // 温度
        Row() {
          Text('温度：').fontSize(20).fontColor('#333333')
          Text(`${this.temperature.toFixed(2)}`)
            .fontSize(20).fontColor('#1890FF').margin({ left: 5, right: 10 })
          Text('℃').fontSize(20).fontColor('#666666')
        }
        .padding(15).width('100%')
      }
      .width('90%')
      .backgroundColor(Color.White)
      .borderRadius(12)
      .shadow({ radius: 8, color: '#1890FF22', offsetX: 2, offsetY: 4 })
      .margin({ top: 20, bottom: 30 })
    }
    .width('100%').height('100%').backgroundColor('#F0F5FF')
  }
}
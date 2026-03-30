/**
 * 阈值设置页
 */
import promptAction from '@ohos.promptAction';
import { NavigationFunc } from '../common/Types';

@Component
export struct SettingsPage {
  @State phMin: number = 6.0;
  @State phMax: number = 8.0;
  @State turbidityWarning: number = 5.0;
  @State turbidityCritical: number = 8.0;
  @State dissolvedOxygenMin: number = 5.0;
  @State tdsThreshold: number = 500;
  @State tempMin: number = 10;
  @State tempMax: number = 30;

  navigate: NavigationFunc = () => {};

  build() {
    Column() {
      // 顶部导航
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24).onClick(() => this.navigate(0))
        Text('阈值设置')
          .fontSize(20).fontWeight(FontWeight.Bold)
          .layoutWeight(1).textAlign(TextAlign.Center).margin({ left: 10 })
      }
      .padding(15).width('100%').backgroundColor('#1890FF')

      Scroll() {
        Column() {
          Text('参数阈值设置')
            .fontSize(18).fontColor('#333333')
            .margin({ top: 20, bottom: 15, left: 15 })

          this.buildThresholdItem('PH值范围',
            `${this.phMin.toFixed(1)} - ${this.phMax.toFixed(1)}`, () => {})
          this.buildThresholdItem('浊度警告阈值',
            `${this.turbidityWarning.toFixed(1)}`, () => {})
          this.buildThresholdItem('溶解氧最低值',
            `${this.dissolvedOxygenMin.toFixed(1)}`, () => {})
          this.buildThresholdItem('TDS阈值',
            `${this.tdsThreshold}`, () => {})
          this.buildThresholdItem('温度范围',
            `${this.tempMin} - ${this.tempMax}`, () => {})

          Button('校准', { type: ButtonType.Capsule })
            .width('80%').height(50).fontSize(18)
            .fontColor(Color.White).backgroundColor('#1890FF')
            .margin({ top: 30, bottom: 10 })
            .onClick(() => {
              promptAction.showToast({ message: '校准成功', duration: 2000 });
            })
        }
        .width('100%').alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)

      Row() {
        Button('首页', { type: ButtonType.Capsule })
          .width('45%').height(50).fontSize(18)
          .fontColor('#1890FF').backgroundColor('#E6F7FF')
          .onClick(() => this.navigate(0))
        Button('设置', { type: ButtonType.Capsule })
          .width('45%').height(50).fontSize(18)
          .fontColor(Color.White).backgroundColor('#1890FF')
          .onClick(() => this.navigate(3))
      }
      .width('90%').margin({ bottom: 20 }).justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%').height('100%').backgroundColor('#F0F5FF')
  }

  @Builder
  buildThresholdItem(label: string, value: string, onClick: () => void) {
    Row() {
      Text(label).fontSize(18).fontColor('#333333').layoutWeight(1)
      Text(value).fontSize(18).fontColor('#1890FF').margin({ right: 15 })
      Image($r('app.media.ic_edit')).width(20).height(20).onClick(onClick)
    }
    .padding(15).width('90%').margin({ bottom: 10 })
    .backgroundColor('#E6F7FF').borderRadius(12)
  }
}
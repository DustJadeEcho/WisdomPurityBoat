/**
 * 阈值设置页 —— 液态玻璃 · 海洋主题
 */
import promptAction from '@ohos.promptAction';
import { NavigationFunc } from '../common/Types';
import { LXGW_FONT, OceanPalette, OceanGradients, OceanFont, OceanRadius } from '../common/Theme';

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
      // 玻璃顶栏
      Row() {
        Image($r('app.media.ic_back'))
          .width(24).height(24)
          .fillColor(OceanPalette.TEXT_WHITE)
          .onClick(() => this.navigate(0))
        Text('阈值设置')
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

      Scroll() {
        Column() {
          // 分组标题
          Row() {
            Text('⚙️')
              .fontSize(18)
              .margin({ right: 8 })
            Text('参数阈值设置')
              .fontSize(OceanFont.SUBHEAD)
              .fontWeight(FontWeight.Medium)
              .fontFamily(LXGW_FONT)
              .fontColor(OceanPalette.TEXT_WHITE)
          }
          .width('90%')
          .margin({ top: 20, bottom: 14 })
          .alignSelf(ItemAlign.Start)
          .padding({ left: 20 })

          // 阈值卡片组
          Column() {
            this.buildThresholdItem('🧪', 'PH值范围',
              `${this.phMin.toFixed(1)} - ${this.phMax.toFixed(1)}`, true, () => {})
            this.buildThresholdItem('💧', '浊度警告阈值',
              `${this.turbidityWarning.toFixed(1)}`, true, () => {})
            this.buildThresholdItem('🫧', '溶解氧最低值',
              `${this.dissolvedOxygenMin.toFixed(1)}`, true, () => {})
            this.buildThresholdItem('🧂', 'TDS 阈值',
              `${this.tdsThreshold}`, true, () => {})
            this.buildThresholdItem('🌡️', '温度范围',
              `${this.tempMin} - ${this.tempMax}`, false, () => {})
          }
          .width('90%')
          .padding(6)
          .backgroundColor(OceanPalette.GLASS_WHITE)
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .borderRadius(OceanRadius.CARD)
          .border({ width: 1, color: OceanPalette.GLASS_BORDER })
          .shadow({ radius: 28, color: '#330077B6', offsetX: 0, offsetY: 8 })
          .margin({ bottom: 20 })

          // 校准按钮
          Text('校 准')
            .width('80%').height(52)
            .fontSize(OceanFont.SUBHEAD)
            .fontWeight(FontWeight.Medium)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_WHITE)
            .textAlign(TextAlign.Center)
            .letterSpacing(6)
            .linearGradient(OceanGradients.BUTTON_PRIMARY)
            .borderRadius(26)
            .shadow({ radius: 20, color: OceanPalette.HALO_BLUE, offsetX: 0, offsetY: 6 })
            .margin({ top: 10, bottom: 14 })
            .onClick(() => {
              promptAction.showToast({ message: '校准成功', duration: 2000 });
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 底部操作按钮
      Row({ space: 12 }) {
        Text('返回首页')
          .layoutWeight(1)
          .height(48)
          .fontSize(OceanFont.BODY)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.OCEAN)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .backgroundColor(OceanPalette.GLASS_WHITE_STRONG)
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .borderRadius(24)
          .border({ width: 1, color: OceanPalette.GLASS_BORDER })
          .onClick(() => this.navigate(0))

        Text('保存设置')
          .layoutWeight(1)
          .height(48)
          .fontSize(OceanFont.BODY)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_WHITE)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .linearGradient(OceanGradients.BUTTON_PRIMARY)
          .borderRadius(24)
          .shadow({ radius: 16, color: OceanPalette.HALO_BLUE, offsetX: 0, offsetY: 4 })
          .onClick(() => this.navigate(3))
      }
      .width('90%')
      .margin({ bottom: 16 })
    }
    .width('100%').height('100%')
  }

  @Builder
  buildThresholdItem(emoji: string, label: string, value: string, divider: boolean, onClick: () => void) {
    Row() {
      Text(emoji).fontSize(18).margin({ right: 10 })
      Text(label)
        .fontSize(OceanFont.BODY)
        .fontFamily(LXGW_FONT)
        .fontColor(OceanPalette.TEXT_ON_GLASS)
        .layoutWeight(1)
      Text(value)
        .fontSize(OceanFont.BODY)
        .fontWeight(FontWeight.Medium)
        .fontFamily(LXGW_FONT)
        .fontColor(OceanPalette.OCEAN)
        .margin({ right: 12 })
      Image($r('app.media.ic_edit'))
        .width(18).height(18)
        .fillColor(OceanPalette.TEXT_SECONDARY)
        .onClick(onClick)
    }
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .width('100%')
    .border(divider ? { width: { bottom: 0.5 }, color: '#66CAF0F8' } : { width: 0 })
  }
}

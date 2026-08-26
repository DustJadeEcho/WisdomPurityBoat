/**
 * 首页 —— 液态玻璃 · 海洋主题
 */
import { NavigationFunc } from '../common/Types';
import { LXGW_FONT, OceanPalette, OceanGradients, OceanFont, OceanRadius } from '../common/Theme';

@Component
export struct HomePage {
  navigate: NavigationFunc = () => {};

  build() {
    Scroll() {
      Column() {
        // ===== 顶部标题区 =====
        Column() {
          Text('星瞳水质检测系统')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_WHITE)
            .shadow({ radius: 16, color: '#80002244', offsetX: 0, offsetY: 2 })
            .margin({ top: 56, bottom: 8 })

          Text('Wisdom · Purity · Boat')
            .fontSize(OceanFont.CAPTION)
            .fontFamily(LXGW_FONT)
            .fontColor('#CCFFFFFF')
            .letterSpacing(3)
            .margin({ bottom: 18 })

          // 副标题玻璃胶囊
          Text('智慧水质监测系统')
            .fontSize(OceanFont.BODY)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_WHITE)
            .padding({ left: 18, right: 18, top: 8, bottom: 8 })
            .backgroundColor(OceanPalette.GLASS_WHITE_SOFT)
            .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
            .borderRadius(OceanRadius.CHIP)
            .border({ width: 1, color: OceanPalette.GLASS_BORDER })
            .margin({ bottom: 26 })
        }
        .width('100%')

        // ===== 系统简介卡片 =====
        Column() {
          Row() {
            Text('🌊').fontSize(22).margin({ right: 8 })
            Text('关于系统')
              .fontSize(OceanFont.SUBHEAD)
              .fontWeight(FontWeight.Bold)
              .fontFamily(LXGW_FONT)
              .fontColor(OceanPalette.TEXT_ON_GLASS)
          }
          .width('100%')
          .margin({ bottom: 10 })

          Text('实时监测高原湖泊水域水质参数，为生态保护提供数据支撑；支持实时监测、历史分析与监测点地图三大能力。')
            .fontSize(OceanFont.CAPTION)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_SECONDARY)
            .lineHeight(24)
        }
        .width('90%')
        .padding(20)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(OceanPalette.GLASS_WHITE)
        .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
        .borderRadius(OceanRadius.CARD)
        .border({ width: 1, color: OceanPalette.GLASS_BORDER })
        .shadow({ radius: 30, color: '#330077B6', offsetX: 0, offsetY: 8 })
        .margin({ bottom: 22 })

        // ===== 功能入口卡片 =====
        Row({ space: 14 }) {
          this.buildFeatureCard('🌡️', '实时监测', OceanPalette.LAGOON, () => this.navigate(1))
          this.buildFeatureCard('📊', '历史数据', OceanPalette.ACCENT_GOLD, () => this.navigate(4))
          this.buildFeatureCard('🗺️', '监测地图', OceanPalette.ACCENT_KELP, () => this.navigate(2))
        }
        .width('90%')
        .margin({ bottom: 22 })

        // ===== 状态小卡片（2列） =====
        Row({ space: 14 }) {
          // 系统状态
          Column() {
            Row() {
              Text('系统状态')
                .fontSize(OceanFont.CAPTION)
                .fontFamily(LXGW_FONT)
                .fontColor(OceanPalette.TEXT_SECONDARY)
              Blank()
              Circle({ width: 10, height: 10 })
                .fill(OceanPalette.ACCENT_KELP)
                .shadow({ radius: 8, color: OceanPalette.ACCENT_KELP, offsetX: 0, offsetY: 0 })
            }
            .width('100%')
            .margin({ bottom: 8 })
            Text('运行正常')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontFamily(LXGW_FONT)
              .fontColor(OceanPalette.ACCENT_KELP)
          }
          .layoutWeight(1)
          .padding(18)
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(OceanPalette.GLASS_WHITE)
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .borderRadius(OceanRadius.CARD)
          .border({ width: 1, color: OceanPalette.GLASS_BORDER })
          .shadow({ radius: 20, color: '#333DDC97', offsetX: 0, offsetY: 6 })

          // 今日数据
          Column() {
            Row() {
              Text('今日数据')
                .fontSize(OceanFont.CAPTION)
                .fontFamily(LXGW_FONT)
                .fontColor(OceanPalette.TEXT_SECONDARY)
              Blank()
              Text('↑')
                .fontSize(14)
                .fontColor(OceanPalette.OCEAN)
            }
            .width('100%')
            .margin({ bottom: 8 })
            Row() {
              Text('128')
                .fontSize(26)
                .fontWeight(FontWeight.Bold)
                .fontFamily(LXGW_FONT)
                .fontColor(OceanPalette.OCEAN)
              Text(' 条')
                .fontSize(OceanFont.CAPTION)
                .fontFamily(LXGW_FONT)
                .fontColor(OceanPalette.TEXT_SECONDARY)
            }.alignItems(VerticalAlign.Bottom)
          }
          .layoutWeight(1)
          .padding(18)
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(OceanPalette.GLASS_WHITE)
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .borderRadius(OceanRadius.CARD)
          .border({ width: 1, color: OceanPalette.GLASS_BORDER })
          .shadow({ radius: 20, color: OceanPalette.HALO_CYAN, offsetX: 0, offsetY: 6 })
        }
        .width('90%')
        .margin({ bottom: 30 })
      }
      .width('100%')
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
  }

  @Builder
  buildFeatureCard(emoji: string, label: string, haloColor: string, onTap: () => void) {
    Column() {
      // 图标圆饼（带光晕）
      Column() {
        Text(emoji).fontSize(30)
      }
      .width(56).height(56)
      .borderRadius(28)
      .backgroundColor('#E6FFFFFF')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .shadow({ radius: 16, color: haloColor + '99', offsetX: 0, offsetY: 4 })
      .margin({ bottom: 10 })

      Text(label)
        .fontSize(OceanFont.BODY)
        .fontWeight(FontWeight.Medium)
        .fontFamily(LXGW_FONT)
        .fontColor(OceanPalette.TEXT_ON_GLASS)
    }
    .layoutWeight(1)
    .padding({ top: 18, bottom: 18 })
    .backgroundColor(OceanPalette.GLASS_WHITE)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(OceanRadius.CARD)
    .border({ width: 1, color: OceanPalette.GLASS_BORDER })
    .shadow({ radius: 24, color: '#330077B6', offsetX: 0, offsetY: 8 })
    .onClick(onTap)
  }
}

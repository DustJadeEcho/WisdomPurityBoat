/**
 * 应用入口 —— 海洋液态玻璃风格 · 底部导航
 */
import { HomePage } from '../views/HomePage';
import { MonitoringPage } from '../views/MonitoringPage';
import { ControlPage } from '../views/ControlPage';
import { MapPage } from '../views/MapPage';
import { SettingsPage } from '../views/SettingsPage';
import { MQTTPage } from '../views/MQTTPage';
import { AIPage } from '../views/AIPage';
import { LXGW_FONT, OceanPalette, OceanGradients, OceanFont, OceanRadius } from '../common/Theme';
// 导入以确保 MQTT 连接在应用启动时建立
import { MQTTInstance } from '../utils/MQTTConfig';

@Entry
@Component
struct WaterQualityApp {
  @State currentPage: number = 0;
  // 0=首页  1=实时监测  2=地图  3=设置  6=小船控制  7=AI

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // ===== 层1：海洋渐变背景（铺满全屏） =====
      Column()
        .width('100%')
        .height('100%')
        .linearGradient(OceanGradients.PAGE_BG)

      // ===== 层2：装饰光斑（模拟水下光晕） =====
      this.buildLightOrbs()

      // ===== 层3：页面内容 =====
      Column() {
        Column() {
          if (this.currentPage === 0) {
            HomePage({ navigate: (page) => this.currentPage = page })
          } else if (this.currentPage === 1) {
            MonitoringPage({ navigate: (page) => this.currentPage = page })
          } else if (this.currentPage === 2) {
            MapPage({ navigate: (page) => this.currentPage = page })
          } else if (this.currentPage === 3) {
            SettingsPage({ navigate: (page) => this.currentPage = page })
          } else if (this.currentPage === 5) {
            MQTTPage({ navigate: (page) => this.currentPage = page })
          } else if (this.currentPage === 6) {
            ControlPage({ navigate: (page) => this.currentPage = page })
          } else if (this.currentPage === 7) {
            AIPage({ navigate: (page) => this.currentPage = page })
          }
        }
        .layoutWeight(1)
        .width('100%')

        // 预留底部导航栏空间
        Column().height(92).width('100%')
      }
      .width('100%')
      .height('100%')

      // ===== 层4：液态玻璃底部导航栏（浮于内容之上） =====
      this.buildBottomNav()
    }
    .width('100%')
    .height('100%')
  }

  /** HarmonyOS 6 光晕装饰：两个模糊光斑模拟水下阳光 */
  @Builder
  buildLightOrbs() {
    Stack() {
      // 左上青色光晕
      Column()
        .width(320).height(320)
        .borderRadius(160)
        .backgroundColor('#6648CAE4')
        .position({ x: -90, y: -40 })
        .blur(80)

      // 右下金色光晕
      Column()
        .width(260).height(260)
        .borderRadius(130)
        .backgroundColor('#55FFD166')
        .position({ x: '65%', y: '70%' })
        .blur(90)

      // 右上白色高光
      Column()
        .width(200).height(200)
        .borderRadius(100)
        .backgroundColor('#55FFFFFF')
        .position({ x: '70%', y: -20 })
        .blur(60)
    }
    .width('100%').height('100%')
    .hitTestBehavior(HitTestMode.None)
  }

  /** 液态玻璃底部导航 */
  @Builder
  buildBottomNav() {
    Row() {
      this.buildNavItem($r('app.media.ic_home'),    '首页',    0)
      this.buildNavItem($r('app.media.ic_monitor'), '监测',    1)
      this.buildNavItem($r('app.media.ic_control'), 'AI',      7)
      this.buildNavItem($r('app.media.ic_map'),     '地图',    2)
      this.buildNavItem($r('app.media.ic_control'), '控制',    6)
    }
    .width('92%')
    .padding({ left: 8, right: 8, top: 10, bottom: 10 })
    .margin({ bottom: 18 })
    .justifyContent(FlexAlign.SpaceAround)
    .backgroundColor(OceanPalette.GLASS_WHITE_SOFT)
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK, {
      colorMode: ThemeColorMode.LIGHT,
      adaptiveColor: AdaptiveColor.DEFAULT
    })
    .borderRadius(32)
    .border({ width: 1, color: OceanPalette.GLASS_BORDER })
    .shadow({ radius: 40, color: '#660077B6', offsetX: 0, offsetY: 10 })
  }

  @Builder
  buildNavItem(icon: Resource, label: string, pageIndex: number) {
    Column() {
      Image(icon)
        .width(26).height(26)
        .margin({ bottom: 3 })
        .fillColor(this.currentPage === pageIndex ? OceanPalette.DEEP_OCEAN : OceanPalette.TEXT_SECONDARY)
      Text(label)
        .fontSize(OceanFont.MICRO)
        .fontFamily(LXGW_FONT)
        .fontColor(this.currentPage === pageIndex ? OceanPalette.DEEP_OCEAN : OceanPalette.TEXT_SECONDARY)
        .fontWeight(this.currentPage === pageIndex ? FontWeight.Bold : FontWeight.Normal)
    }
    .padding({ top: 10, bottom: 10, left: 8, right: 8 })
    .layoutWeight(1)
    .borderRadius(OceanRadius.BUTTON)
    .backgroundColor(this.currentPage === pageIndex ? OceanPalette.GLASS_WHITE_STRONG : Color.Transparent)
    .shadow({
      radius: this.currentPage === pageIndex ? 16 : 0,
      color: OceanPalette.HALO_CYAN,
      offsetX: 0,
      offsetY: this.currentPage === pageIndex ? 2 : 0
    })
    .onClick(() => this.currentPage = pageIndex)
    .animation({ duration: 260, curve: Curve.EaseInOut })
  }
}

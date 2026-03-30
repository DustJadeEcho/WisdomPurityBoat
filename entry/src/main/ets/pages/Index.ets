/**
 * 应用入口 —— 页面路由 + 底部导航栏
 */
import { HomePage } from '../views/HomePage';
import { MonitoringPage } from '../views/MonitoringPage';
import { ControlPage } from '../views/ControlPage';
import { MapPage } from '../views/MapPage';
import { SettingsPage } from '../views/SettingsPage';
import { MQTTPage } from '../views/MQTTPage';
import { AIPage } from '../views/AIPage';
// 导入以确保 MQTT 连接在应用启动时建立
import { MQTTInstance } from '../utils/MQTTConfig';

@Entry
@Component
struct WaterQualityApp {
  @State currentPage: number = 0;
  // 0=首页  1=实时监测  2=地图  3=设置  4=历史数据  5=MQTT测试  6=小船控制

  build() {
    Column() {
      // ===== 页面内容区 =====
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

      // ===== 底部导航栏 =====
      this.buildBottomNav()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F5FF')
  }

  @Builder
  buildBottomNav() {
    Row() {
      this.buildNavItem($r('app.media.ic_home'),    '首页',     0)
      this.buildNavItem($r('app.media.ic_monitor'), '实时监测',  1)
      this.buildNavItem($r('app.media.ic_control'), 'AI',      7)
      this.buildNavItem($r('app.media.ic_map'),     '监测地图',  2)
      this.buildNavItem($r('app.media.ic_control'), '小船控制',  6)
    }
    .width('100%')
    .padding(10)
    .justifyContent(FlexAlign.SpaceAround)
    .backgroundColor(Color.White)
    .border({ width: { top: 1 }, color: '#E8E8E8' })
  }

  @Builder
  buildNavItem(icon: Resource, label: string, pageIndex: number) {
    Column() {
      Image(icon).width(28).height(28).margin({ bottom: 4 })
      Text(label).fontSize(14)
    }
    .padding(10)
    .backgroundColor(this.currentPage === pageIndex ? '#E6F7FF' : 'transparent')
    .borderRadius(16)
    .onClick(() => this.currentPage = pageIndex)
  }
}
/**
 * 首页 —— 功能入口 + 系统状态
 */
import { NavigationFunc } from '../common/Types';

@Component
export struct HomePage {
  navigate: NavigationFunc = () => {};

  build() {
    Scroll() {
      Column() {
        // ===== 顶部标题 =====
        Text('青海湖智清舟')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1890FF')
          .margin({ top: 30, bottom: 20 })

        Text('智慧水质监测系统')
          .fontSize(20)
          .fontColor('#333333')
          .margin({ bottom: 40 })

        Text('本系统实时监测青海湖水域水质参数，为环境保护提供数据支持。系统包含实时监测、历史数据分析和监测点地图功能。')
          .fontSize(16)
          .fontColor('#666666')
          .padding(20)
          .textAlign(TextAlign.Center)
          .margin({ bottom: 40 })

        // ===== 功能卡片 =====
        Grid() {
          GridItem() {
            this.buildFeatureCard($r('app.media.ic_monitor'), '实时监测', () => this.navigate(1))
          }
          GridItem() {
            this.buildFeatureCard($r('app.media.ic_history'), '历史数据', () => this.navigate(4))
          }
          GridItem() {
            this.buildFeatureCard($r('app.media.ic_map'), '监测地图', () => this.navigate(2))
          }
        }
        .columnsTemplate('1fr 1fr 1fr')
        .rowsGap(20)
        .columnsGap(20)
        .width('90%')
        .margin({ bottom: 40 })

        // ===== 状态卡片 =====
        Grid() {
          GridItem() {
            Column() {
              Text('系统状态').fontSize(18).fontColor('#333333').margin({ bottom: 10 })
              Row() {
                Circle({ width: 12, height: 12 }).fill('#52C41A').margin({ right: 8 })
                Text('运行正常').fontSize(16).fontColor('#666666')
              }
            }
            .padding(20).backgroundColor(Color.White).borderRadius(12)
          }

          GridItem() {
            Column() {
              Text('今日数据').fontSize(18).fontColor('#333333').margin({ bottom: 10 })
              Text('128条').fontSize(24).fontColor('#1890FF')
            }
            .padding(20).backgroundColor(Color.White).borderRadius(12)
          }
        }
        .columnsTemplate('1fr 1fr')
        .rowsGap(20)
        .columnsGap(20)
        .width('90%')
      }
      .width('100%')
    }
    .scrollable(ScrollDirection.Vertical)
  }

  @Builder
  buildFeatureCard(icon: Resource, label: string, onTap: () => void) {
    Column() {
      Image(icon).width(60).height(60).margin({ bottom: 10 })
      Text(label).fontSize(18).fontColor('#1890FF')
    }
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 8, color: '#1890FF22', offsetX: 2, offsetY: 4 })
    .onClick(onTap)
  }
}
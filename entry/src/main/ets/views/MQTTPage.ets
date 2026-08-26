/**
 * MQTT 通信测试页 —— 液态玻璃 · 海洋主题
 */
import { NavigationFunc } from '../common/Types';
import { LXGW_FONT, OceanPalette, OceanGradients, OceanFont, OceanRadius } from '../common/Theme';

@Component
export struct MQTTPage {
  @State receiveMsg: string = '';
  @State sendMsg: string = '';

  navigate: NavigationFunc = () => {};

  build() {
    Column({ space: 18 }) {
      // 玻璃顶栏
      Row() {
        Image($r('app.media.ic_back'))
          .width(24).height(24)
          .fillColor(OceanPalette.TEXT_WHITE)
          .onClick(() => this.navigate(0))
        Text('MQTT通信')
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
          // 标题横幅
          Column() {
            Text('高原湖泊水质监测系统')
              .fontSize(OceanFont.HEADING)
              .fontWeight(FontWeight.Bold)
              .fontFamily(LXGW_FONT)
              .fontColor(OceanPalette.TEXT_WHITE)
              .shadow({ radius: 12, color: '#80002244', offsetX: 0, offsetY: 2 })
            Text('MQTT 通信测试')
              .fontSize(OceanFont.BODY)
              .fontFamily(LXGW_FONT)
              .fontColor('#E6FFFFFF')
              .margin({ top: 6 })
          }
          .width('100%').margin({ top: 6, bottom: 24 })

          // 接收消息卡
          Column() {
            Row() {
              Text('📥')
                .fontSize(18)
                .margin({ right: 8 })
              Text('接收到的消息')
                .fontSize(OceanFont.SUBHEAD)
                .fontWeight(FontWeight.Medium)
                .fontFamily(LXGW_FONT)
                .fontColor(OceanPalette.TEXT_ON_GLASS)
            }
            .width('100%')
            .margin({ bottom: 10 })

            Text(this.receiveMsg || '(暂无消息)')
              .fontSize(OceanFont.CAPTION)
              .fontFamily(LXGW_FONT)
              .fontColor(this.receiveMsg ? OceanPalette.TEXT_ON_GLASS : OceanPalette.TEXT_MUTED)
              .width('100%').height(84)
              .padding(12)
              .borderRadius(OceanRadius.BUTTON)
              .backgroundColor('#80EAF6FB')
              .border({ width: 1, color: OceanPalette.GLASS_BORDER })
              .textAlign(TextAlign.Start)
          }
          .width('90%')
          .padding(18)
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(OceanPalette.GLASS_WHITE)
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .borderRadius(OceanRadius.CARD)
          .border({ width: 1, color: OceanPalette.GLASS_BORDER })
          .shadow({ radius: 24, color: '#330077B6', offsetX: 0, offsetY: 8 })
          .margin({ bottom: 18 })

          // 发送消息卡
          Column() {
            Row() {
              Text('📤')
                .fontSize(18)
                .margin({ right: 8 })
              Text('发送消息')
                .fontSize(OceanFont.SUBHEAD)
                .fontWeight(FontWeight.Medium)
                .fontFamily(LXGW_FONT)
                .fontColor(OceanPalette.TEXT_ON_GLASS)
            }
            .width('100%')
            .margin({ bottom: 10 })

            TextInput({ text: $$this.sendMsg, placeholder: '输入要发送的消息' })
              .width('100%').height(46)
              .padding({ left: 14, right: 14 })
              .borderRadius(OceanRadius.BUTTON)
              .fontFamily(LXGW_FONT)
              .fontSize(OceanFont.CAPTION)
              .fontColor(OceanPalette.TEXT_ON_GLASS)
              .placeholderColor(OceanPalette.TEXT_MUTED)
              .placeholderFont({ size: OceanFont.CAPTION, family: LXGW_FONT })
              .backgroundColor('#CCFFFFFF')
              .border({ width: 1, color: OceanPalette.GLASS_BORDER })
              .margin({ bottom: 12 })

            Text('发送消息')
              .width('100%').height(46)
              .fontSize(OceanFont.BODY)
              .fontFamily(LXGW_FONT)
              .fontWeight(FontWeight.Medium)
              .fontColor(OceanPalette.TEXT_WHITE)
              .textAlign(TextAlign.Center)
              .linearGradient(OceanGradients.BUTTON_PRIMARY)
              .borderRadius(OceanRadius.BUTTON)
              .shadow({ radius: 14, color: OceanPalette.HALO_BLUE, offsetX: 0, offsetY: 4 })
          }
          .width('90%')
          .padding(18)
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(OceanPalette.GLASS_WHITE)
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .borderRadius(OceanRadius.CARD)
          .border({ width: 1, color: OceanPalette.GLASS_BORDER })
          .shadow({ radius: 24, color: '#330077B6', offsetX: 0, offsetY: 8 })
          .margin({ bottom: 18 })

          // 连接按钮
          Text('连接服务')
            .width('50%').height(46)
            .fontSize(OceanFont.BODY)
            .fontFamily(LXGW_FONT)
            .fontWeight(FontWeight.Medium)
            .fontColor(OceanPalette.TEXT_WHITE)
            .textAlign(TextAlign.Center)
            .linearGradient(OceanGradients.BUTTON_SUCCESS)
            .borderRadius(OceanRadius.BUTTON)
            .shadow({ radius: 16, color: '#663DDC97', offsetX: 0, offsetY: 4 })
            .onClick(() => {})
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('100%')
  }
}

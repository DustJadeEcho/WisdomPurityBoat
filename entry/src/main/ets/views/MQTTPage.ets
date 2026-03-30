/**
 * MQTT 通信测试页
 */
import { NavigationFunc } from '../common/Types';

@Component
export struct MQTTPage {
  @State receiveMsg: string = '';
  @State sendMsg: string = '';

  navigate: NavigationFunc = () => {};

  build() {
    Column({ space: 24 }) {
      // 顶部导航
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24).onClick(() => this.navigate(0))
        Text('MQTT通信')
          .fontSize(20).fontWeight(FontWeight.Bold)
          .layoutWeight(1).textAlign(TextAlign.Center).margin({ left: 10 })
      }
      .padding(15).width('100%').backgroundColor('#1890FF')

      Column() {
        Text('青海湖水质监测系统')
          .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#1890FF')
          .margin({ bottom: 20 })
        Text('MQTT通信测试')
          .fontSize(20).fontColor('#333333').margin({ bottom: 30 })

        // 接收消息
        Column() {
          Text('接收到的消息：').fontSize(18).fontColor('#333333').margin({ bottom: 10 })
          Text(this.receiveMsg)
            .fontSize(16).fontColor('#666666').width('100%').height(80)
            .padding(10).borderRadius(8)
            .border({ width: 1, color: '#1890FF' }).backgroundColor('#E6F7FF')
        }
        .width('90%').margin({ bottom: 20 })

        // 发送消息
        Column() {
          Text('发送消息：').fontSize(18).fontColor('#333333').margin({ bottom: 10 })
          TextInput({ text: $$this.sendMsg, placeholder: '输入要发送的消息' })
            .width('100%').height(40).padding(10).borderRadius(8)
            .border({ width: 1, color: '#1890FF' }).backgroundColor(Color.White)
            .margin({ bottom: 10 })
          Button('发送消息')
            .width('100%').height(40).fontSize(16)
            .fontColor(Color.White).backgroundColor('#1890FF')
        }
        .width('90%').margin({ bottom: 20 })

        Row({ space: 20 }) {
          Button('连接服务')
            .width('40%').height(40).fontSize(16)
            .fontColor(Color.White).backgroundColor('#52C41A')
            .onClick(() => {})
        }
        .justifyContent(FlexAlign.Center).width('100%').margin({ top: 10 })
      }
      .layoutWeight(1).width('100%').padding(20).backgroundColor('#F0F5FF')
    }
    .width('100%').height('100%').backgroundColor('#F0F5FF')
  }
}
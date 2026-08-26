/**
 * 小船运动控制页 —— 液态玻璃 · 海洋主题
 */
import { NavigationFunc } from '../common/Types';
import { MQTTInstance } from '../utils/MQTTConfig';
import { createBoatCtrlFrame, arrayBufferToHexString } from '../utils/FrameUtils';
import { LXGW_FONT, OceanPalette, OceanGradients, OceanFont, OceanRadius } from '../common/Theme';

@Component
export struct ControlPage {
  @State forwardPressed: boolean = false;
  @State backwardPressed: boolean = false;
  @State leftPressed: boolean = false;
  @State rightPressed: boolean = false;
  @State lastSentFrame: string = '';

  navigate: NavigationFunc = () => {};

  private timerID: number | null = null;
  private sendInterval: number = 200;

  aboutToDisappear(): void {
    this.stopSending();
  }

  private startSending(): void {
    if (this.timerID !== null) return;
    this.timerID = setInterval(() => {
      this.sendControlCommand();
    }, this.sendInterval);
    this.sendControlCommand();
  }

  private stopSending(): void {
    if (this.timerID !== null) {
      clearInterval(this.timerID);
      this.timerID = null;
      this.sendControlCommand(true);
    }
  }

  private sendControlCommand(stop: boolean = false): void {
    let direction = 0;
    if (!stop) {
      if (this.forwardPressed && !this.backwardPressed) direction |= 0x08;
      else if (this.backwardPressed && !this.forwardPressed) direction |= 0x10;
      if (this.leftPressed && !this.rightPressed) direction |= 0x03;
      else if (this.rightPressed && !this.leftPressed) direction |= 0x04;
    }

    const rawFrame = createBoatCtrlFrame(direction);
    const hexString = arrayBufferToHexString(rawFrame);
    this.lastSentFrame = hexString;
    MQTTInstance.pushMessage(hexString);
  }

  private handleButtonPress(dir: 'forward' | 'backward' | 'left' | 'right'): void {
    switch (dir) {
      case 'forward':  this.forwardPressed = true;  break;
      case 'backward': this.backwardPressed = true; break;
      case 'left':     this.leftPressed = true;     break;
      case 'right':    this.rightPressed = true;    break;
    }
    this.startSending();
  }

  private handleButtonRelease(dir: 'forward' | 'backward' | 'left' | 'right'): void {
    switch (dir) {
      case 'forward':  this.forwardPressed = false;  break;
      case 'backward': this.backwardPressed = false; break;
      case 'left':     this.leftPressed = false;     break;
      case 'right':    this.rightPressed = false;    break;
    }
    if (!this.forwardPressed && !this.backwardPressed &&
      !this.leftPressed && !this.rightPressed) {
      this.stopSending();
    } else {
      this.sendControlCommand();
    }
  }

  private getStatusText(): string {
    if (this.forwardPressed && this.leftPressed) return '前进并左转';
    if (this.forwardPressed && this.rightPressed) return '前进并右转';
    if (this.backwardPressed && this.leftPressed) return '后退并左转';
    if (this.backwardPressed && this.rightPressed) return '后退并右转';
    if (this.forwardPressed) return '前进';
    if (this.backwardPressed) return '后退';
    if (this.leftPressed) return '左转';
    if (this.rightPressed) return '右转';
    return '停泊';
  }

  build() {
    Column() {
      // 玻璃顶部导航
      Row() {
        Image($r('app.media.ic_back'))
          .width(24).height(24)
          .fillColor(OceanPalette.TEXT_WHITE)
          .onClick(() => this.navigate(0))
        Text('小船运动控制')
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

      // 状态显示卡
      Column() {
        Text('当前状态')
          .fontSize(OceanFont.CAPTION)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_SECONDARY)
        Text(this.getStatusText())
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontFamily(LXGW_FONT)
          .fontColor(this.getStatusText() === '停泊' ? OceanPalette.OCEAN : OceanPalette.ACCENT_KELP)
          .margin({ top: 6 })
          .shadow({
            radius: 12,
            color: this.getStatusText() === '停泊' ? OceanPalette.HALO_BLUE : '#663DDC97',
            offsetX: 0, offsetY: 2
          })
      }
      .width('90%')
      .padding(18)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(OceanPalette.GLASS_WHITE)
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
      .borderRadius(OceanRadius.CARD)
      .border({ width: 1, color: OceanPalette.GLASS_BORDER })
      .shadow({ radius: 24, color: '#330077B6', offsetX: 0, offsetY: 8 })
      .margin({ top: 20, bottom: 22 })

      Text('方向控制')
        .fontSize(OceanFont.SUBHEAD)
        .fontWeight(FontWeight.Medium)
        .fontFamily(LXGW_FONT)
        .fontColor(OceanPalette.TEXT_WHITE)
        .margin({ bottom: 20 })

      // 方向控制盘
      Column({ space: 22 }) {
        // 前进
        this.buildDirButton('前进', '↑', this.forwardPressed, 'forward')

        // 左右
        Row() {
          this.buildDirButton('左转', '←', this.leftPressed, 'left')
          Column().width(100).height(100)
          this.buildDirButton('右转', '→', this.rightPressed, 'right')
        }
        .width('80%')
        .justifyContent(FlexAlign.SpaceBetween)

        // 后退
        this.buildDirButton('后退', '↓', this.backwardPressed, 'backward')
      }
      .margin({ top: 6, bottom: 24 })

      // 提示
      Text('· 按住方向按钮以持续控制，松开即停 ·')
        .fontSize(OceanFont.MICRO)
        .fontFamily(LXGW_FONT)
        .fontColor('#CCFFFFFF')
        .margin({ top: 12 })
    }
    .width('100%').height('100%')
  }

  @Builder
  buildDirButton(label: string, arrow: string, pressed: boolean,
                 dir: 'forward' | 'backward' | 'left' | 'right') {
    Column() {
      Text(arrow)
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontFamily(LXGW_FONT)
        .fontColor(OceanPalette.TEXT_WHITE)
      Text(label)
        .fontSize(OceanFont.CAPTION)
        .fontFamily(LXGW_FONT)
        .fontColor('#E6FFFFFF')
        .margin({ top: 2 })
    }
    .width(100).height(100)
    .borderRadius(50)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .linearGradient(pressed ? OceanGradients.BUTTON_SUCCESS : OceanGradients.BUTTON_PRIMARY)
    .border({
      width: 2,
      color: pressed ? '#CCFFFFFF' : OceanPalette.GLASS_BORDER
    })
    .shadow({
      radius: pressed ? 28 : 18,
      color: pressed ? '#663DDC97' : OceanPalette.HALO_BLUE,
      offsetX: 0,
      offsetY: pressed ? 2 : 8
    })
    .scale({ x: pressed ? 0.94 : 1, y: pressed ? 0.94 : 1 })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) this.handleButtonPress(dir);
      else if (event.type === TouchType.Up) this.handleButtonRelease(dir);
    })
  }
}

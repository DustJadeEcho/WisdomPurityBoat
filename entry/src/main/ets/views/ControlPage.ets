/**
 * 小船运动控制页 —— 方向遥控 + MQTT 发送
 */
import { NavigationFunc } from '../common/Types';
import { MQTTInstance } from '../utils/MQTTConfig';
import { createBoatCtrlFrame, arrayBufferToHexString } from '../utils/FrameUtils';

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

  // ===== 指令发送控制 =====
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

  // ===== 按钮触摸事件 =====
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
    return '停止';
  }

  // ===== UI =====
  build() {
    Column() {
      // 顶部导航
      Row() {
        Image($r('app.media.ic_back'))
          .width(24)
          .height(24)
          .onClick(() => this.navigate(0))

        Text('小船运动控制')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ left: 10 })
      }
      .padding(15)
      .width('100%')
      .backgroundColor('#1890FF')

      Text('方向控制')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1890FF')
        .margin({ top: 30, bottom: 20 })

      // ★ 方向控制盘 —— 直接内联引用 this.xxxPressed，确保 @State 响应式刷新
      Column() {
        // 前进按钮
        Button('前进', { type: ButtonType.Circle })
          .width(100)
          .height(100)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(this.forwardPressed ? '#52C41A' : '#1890FF')
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.handleButtonPress('forward');
            } else if (event.type === TouchType.Up) {
              this.handleButtonRelease('forward');
            }
          })
          .margin({ bottom: 20 })

        // 左右按钮行
        Row() {
          // 左转按钮
          Button('左转', { type: ButtonType.Circle })
            .width(100)
            .height(100)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(this.leftPressed ? '#52C41A' : '#1890FF')
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.handleButtonPress('left');
              } else if (event.type === TouchType.Up) {
                this.handleButtonRelease('left');
              }
            })
            .margin({ right: 30 })

          // 空位占位
          Column()
            .width(100)
            .height(100)

          // 右转按钮
          Button('右转', { type: ButtonType.Circle })
            .width(100)
            .height(100)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(this.rightPressed ? '#52C41A' : '#1890FF')
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.handleButtonPress('right');
              } else if (event.type === TouchType.Up) {
                this.handleButtonRelease('right');
              }
            })
            .margin({ left: 30 })
        }
        .margin({ bottom: 20 })

        // 后退按钮
        Button('后退', { type: ButtonType.Circle })
          .width(100)
          .height(100)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor(this.backwardPressed ? '#52C41A' : '#1890FF')
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.handleButtonPress('backward');
            } else if (event.type === TouchType.Up) {
              this.handleButtonRelease('backward');
            }
          })
          .margin({ top: 20 })
      }
      .margin({ top: 20, bottom: 30 })

      // 操作提示
      Text('按住方向按钮控制小船运动，松开按钮停止')
        .fontSize(16)
        .fontColor('#666666')
        .margin({ top: 30 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F5FF')
  }
}
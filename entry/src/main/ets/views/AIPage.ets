import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { NavigationFunc } from '../common/Types';
import { aiChatController, AIChatController } from '../services/AIChatController';
import { ASRManager } from '../utils/ASRManager';
import type { SessionMeta, MemorySegment } from '../common/AIChatTypes';
import { LXGW_FONT, OceanPalette, OceanGradients, OceanFont, OceanRadius } from '../common/Theme';

/** 暴露给 WebView 的原生桥（网页 → 原生） */
class AIChatJsBridge {
  private controller: AIChatController;

  constructor(controller: AIChatController) {
    this.controller = controller;
  }

  onExampleTap(text: string): void {
    this.controller.bridgeExampleTap(text);
  }

  onReadAloud(id: string): void {
    this.controller.bridgeReadAloud(id);
  }
}

@Component
export struct AIPage {
  navigate: NavigationFunc = () => {};

  @State title: string = '新对话';
  @State isLoading: boolean = false;
  @State muted: boolean = false;
  @State inputText: string = '';
  @State inputHint: string = '请向高原水质监测助手提问…';
  @State sessions: SessionMeta[] = [];
  @State memories: MemorySegment[] = [];
  @State currentId: string = '';
  @State showDrawer: boolean = false;
  @State showSheet: boolean = false;
  @State sheetMode: number = 0; // 1=记忆 2=重命名
  @State renameTarget: string = '';
  @State renameText: string = '';
  @State isRecording: boolean = false;
  @State recordedText: string = '';
  @State cancelArmed: boolean = false;

  private controller: AIChatController = aiChatController;
  private webCtrl: webview.WebviewController = new webview.WebviewController();
  private jsBridge: AIChatJsBridge = new AIChatJsBridge(aiChatController);
  private asr: ASRManager = new ASRManager();
  private micGranted: boolean = false;
  private shouldSendOnFinal: boolean = false;
  private voiceSendTimer: number = -1;
  private touchStartY: number = 0;

  async aboutToAppear(): Promise<void> {
    this.controller.subscribe(() => this.syncFromController());
    this.controller.attachWeb(this.webCtrl);
    const ctx = getContext(this) as common.Context;
    await this.controller.init(ctx);
    this.syncFromController();
    this.inputText = this.controller.current.draftInput;
    // 预热语音识别引擎，消除首次按住说话的创建延迟
    this.asr.prepare();
  }

  aboutToDisappear(): void {
    // 离开页面：停止朗读（detachWeb 内处理），流式生成在后台继续
    this.asr.destroy();
    this.isRecording = false;
    this.recordedText = '';
    this.cancelArmed = false;
    this.shouldSendOnFinal = false;
    if (this.voiceSendTimer !== -1) {
      clearTimeout(this.voiceSendTimer);
      this.voiceSendTimer = -1;
    }
    this.controller.unsubscribe();
    this.controller.detachWeb();
    this.controller.saveNow();
  }

  private syncFromController(): void {
    this.title = this.controller.current.title;
    this.isLoading = this.controller.isLoading;
    this.muted = this.controller.muted;
    this.sessions = this.controller.sessions.slice(0);
    this.memories = this.controller.current.memories.slice(0);
    this.currentId = this.controller.current.id;
  }

  private doSend(): void {
    const q = this.inputText.trim();
    if (q.length === 0) {
      promptAction.showToast({ message: '请输入问题', duration: 1500 });
      return;
    }
    this.inputText = '';
    this.controller.send(q);
  }

  // ============ 按住说话（语音识别） ============
  private async ensureMicPermission(): Promise<boolean> {
    if (this.micGranted) {
      return true;
    }
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const ctx = getContext(this) as common.UIAbilityContext;
      const perms: Array<Permissions> = ['ohos.permission.MICROPHONE'];
      const res = await atManager.requestPermissionsFromUser(ctx, perms);
      this.micGranted = res.authResults.length > 0 && res.authResults[0] === 0;
      return this.micGranted;
    } catch (_e) {
      return false;
    }
  }

  private async startVoice(): Promise<void> {
    if (this.isRecording) {
      return;
    }
    this.isRecording = true;
    this.recordedText = '';
    this.shouldSendOnFinal = false;
    if (this.voiceSendTimer !== -1) {
      clearTimeout(this.voiceSendTimer);
      this.voiceSendTimer = -1;
    }
    const ok = await this.ensureMicPermission();
    if (!ok) {
      this.isRecording = false;
      promptAction.showToast({ message: '需要麦克风权限才能语音输入', duration: 1800 });
      return;
    }
    if (!this.isRecording) {
      return; // 权限弹窗期间已松手
    }
    // 朗读与录音会互相干扰，先停掉朗读
    this.controller.stopSpeaking();
    const started = await this.asr.start((text: string, isFinal: boolean) => {
      this.recordedText = text;
      if (isFinal) {
        this.flushVoiceSend();
      }
    });
    if (!started) {
      this.isRecording = false;
      promptAction.showToast({ message: '语音识别启动失败，请重试', duration: 1800 });
      return;
    }
    if (!this.isRecording) {
      this.asr.stop(); // 启动过程中已松手
    }
  }

  /** 松手：结束录音，并在拿到最终识别结果后直接发送 */
  private stopVoice(): void {
    if (!this.isRecording) {
      return;
    }
    this.isRecording = false;
    this.shouldSendOnFinal = true;
    this.asr.stop();
    // 兜底：若最终结果回调未触发，1.2s 后用已识别内容直接发送
    if (this.voiceSendTimer !== -1) {
      clearTimeout(this.voiceSendTimer);
    }
    this.voiceSendTimer = setTimeout(() => {
      this.voiceSendTimer = -1;
      this.flushVoiceSend();
    }, 800);
  }

  /** 上滑取消：丢弃识别结果，不发送 */
  private cancelVoice(): void {
    this.isRecording = false;
    this.shouldSendOnFinal = false;
    if (this.voiceSendTimer !== -1) {
      clearTimeout(this.voiceSendTimer);
      this.voiceSendTimer = -1;
    }
    this.recordedText = '';
    this.asr.cancel();
  }

  /** 识别完成后自动发送（只发一次） */
  private flushVoiceSend(): void {
    if (!this.shouldSendOnFinal) {
      return;
    }
    this.shouldSendOnFinal = false;
    if (this.voiceSendTimer !== -1) {
      clearTimeout(this.voiceSendTimer);
      this.voiceSendTimer = -1;
    }
    const q = this.recordedText.trim();
    this.recordedText = '';
    if (q.length === 0 || this.isLoading) {
      return; // 没识别到内容则不发送
    }
    this.controller.send(q);
  }

  private onVoiceTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.touchStartY = event.touches.length > 0 ? event.touches[0].windowY : 0;
      this.cancelArmed = false;
      this.startVoice();
    } else if (event.type === TouchType.Move) {
      if (event.touches.length > 0) {
        const dy = this.touchStartY - event.touches[0].windowY;
        this.cancelArmed = dy > 80;
      }
    } else if (event.type === TouchType.Up) {
      if (this.cancelArmed) {
        this.cancelVoice();
      } else {
        this.stopVoice();
      }
      this.cancelArmed = false;
    } else if (event.type === TouchType.Cancel) {
      this.cancelVoice();
      this.cancelArmed = false;
    }
  }

  private async onNewSession(): Promise<void> {
    await this.controller.newSession();
    this.inputText = '';
    this.showDrawer = false;
  }

  private async onSwitch(id: string): Promise<void> {
    await this.controller.switchSession(id);
    this.inputText = this.controller.current.draftInput;
    this.showDrawer = false;
  }

  private onDeleteSession(meta: SessionMeta): void {
    promptAction.showDialog({
      title: '删除对话',
      message: '确定删除「' + meta.title + '」吗？此操作不可恢复。',
      buttons: [
        { text: '取消', color: OceanPalette.TEXT_SECONDARY },
        { text: '删除', color: OceanPalette.ACCENT_DANGER }
      ]
    }).then((res) => {
      if (res.index === 1) {
        this.controller.deleteSession(meta.id);
      }
    });
  }

  private onClearCurrent(): void {
    promptAction.showDialog({
      title: '清空当前对话',
      message: '将清空当前对话的全部消息与记忆，确定继续？',
      buttons: [
        { text: '取消', color: OceanPalette.TEXT_SECONDARY },
        { text: '清空', color: OceanPalette.ACCENT_DANGER }
      ]
    }).then((res) => {
      if (res.index === 1) {
        this.controller.clearCurrent();
        this.inputText = '';
        this.showDrawer = false;
      }
    });
  }

  private openRename(id: string, title: string): void {
    this.renameTarget = id;
    this.renameText = title;
    this.sheetMode = 2;
    this.showSheet = true;
  }

  private openMemory(): void {
    this.sheetMode = 1;
    this.showSheet = true;
  }

  private confirmRename(): void {
    const t = this.renameText.trim();
    if (t.length === 0) {
      promptAction.showToast({ message: '名称不能为空', duration: 1500 });
      return;
    }
    this.controller.renameSession(this.renameTarget, t);
    this.showSheet = false;
  }

  private formatTime(ts: number): string {
    const d = new Date(ts);
    const mm = (d.getMonth() + 1).toString().padStart(2, '0');
    const dd = d.getDate().toString().padStart(2, '0');
    const hh = d.getHours().toString().padStart(2, '0');
    const mi = d.getMinutes().toString().padStart(2, '0');
    return mm + '-' + dd + ' ' + hh + ':' + mi;
  }

  private sessionKey(meta: SessionMeta): string {
    return meta.id + '_' + meta.updatedAt.toString() + '_' + meta.messageCount.toString();
  }

  private memoryKey(memory: MemorySegment): string {
    return memory.id;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.buildTopBar()

        Web({ src: $rawfile('ai_chat.html'), controller: this.webCtrl })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onlineImageAccess(true)
          .javaScriptProxy({
            object: this.jsBridge,
            name: 'arkBridge',
            methodList: ['onExampleTap', 'onReadAloud'],
            controller: this.webCtrl
          })
          .onPageEnd(() => { this.controller.onWebReady(); })
          .layoutWeight(1)
          .width('100%')
          .backgroundColor('#F4FAFD')

        this.buildInputBar()
      }
      .width('100%')
      .height('100%')

      if (this.showDrawer) {
        this.buildDrawer()
      }

      if (this.isRecording) {
        this.buildVoiceOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.showSheet, this.buildSheet(), {
      height: this.sheetMode === 2 ? 280 : 480,
      dragBar: true,
      backgroundColor: '#F7FBFD',
      showClose: false
    })
  }

  @Builder
  private buildTopBar() {
    Row() {
      Text('☰')
        .fontSize(22)
        .fontColor(OceanPalette.TEXT_WHITE)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.showDrawer = true; })

      Column() {
        Text(this.title)
          .fontSize(OceanFont.HEADING)
          .fontWeight(FontWeight.Bold)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_WHITE)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('高原水质监测助手 · 点此重命名')
          .fontSize(OceanFont.MICRO)
          .fontFamily(LXGW_FONT)
          .fontColor('#CCEAF6FB')
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => { this.openRename(this.currentId, this.title); })

      Text(this.muted ? '🔇' : '🔊')
        .fontSize(20)
        .width(38)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.controller.toggleMute(); })

      Text('＋')
        .fontSize(26)
        .fontColor(OceanPalette.TEXT_WHITE)
        .width(38)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.onNewSession(); })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 52, bottom: 12 })
    .backgroundColor('#33002244')
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK, {
      colorMode: ThemeColorMode.DARK,
      adaptiveColor: AdaptiveColor.DEFAULT
    })
  }

  @Builder
  private buildInputBar() {
    Row({ space: 8 }) {
      // 按住说话
      Text(this.isRecording ? '🔴' : '🎤')
        .width(46)
        .height(48)
        .textAlign(TextAlign.Center)
        .fontSize(20)
        .borderRadius(24)
        .backgroundColor(this.isRecording ? '#FFD9DD' : OceanPalette.GLASS_WHITE_STRONG)
        .border({ width: 1, color: this.isRecording ? OceanPalette.ACCENT_DANGER : OceanPalette.GLASS_BORDER })
        .onTouch((event: TouchEvent) => { this.onVoiceTouch(event); })

      TextInput({ placeholder: this.inputHint, text: this.inputText })
        .layoutWeight(1)
        .height(48)
        .fontFamily(LXGW_FONT)
        .fontSize(OceanFont.BODY)
        .fontColor(OceanPalette.TEXT_ON_GLASS)
        .placeholderColor(OceanPalette.TEXT_MUTED)
        .placeholderFont({ size: OceanFont.CAPTION, family: LXGW_FONT })
        .borderRadius(24)
        .backgroundColor(OceanPalette.GLASS_WHITE_STRONG)
        .border({ width: 1, color: OceanPalette.GLASS_BORDER })
        .enterKeyType(EnterKeyType.Send)
        .onChange((value: string) => {
          this.inputText = value;
          this.controller.updateDraft(value);
        })
        .onSubmit(() => { if (!this.isLoading) this.doSend(); })

      Text(this.isLoading ? '停止' : '发送')
        .height(48)
        .padding({ left: 18, right: 18 })
        .fontSize(OceanFont.BODY)
        .fontFamily(LXGW_FONT)
        .fontWeight(FontWeight.Medium)
        .fontColor(OceanPalette.TEXT_WHITE)
        .textAlign(TextAlign.Center)
        .linearGradient(this.isLoading ? OceanGradients.BUTTON_ACCENT : OceanGradients.BUTTON_PRIMARY)
        .borderRadius(24)
        .shadow({ radius: 14, color: OceanPalette.HALO_BLUE, offsetX: 0, offsetY: 4 })
        .onClick(() => {
          if (this.isLoading) {
            this.controller.abort();
          } else {
            this.doSend();
          }
        })
    }
    .width('100%')
    .padding({ left: 15, right: 15, top: 10, bottom: 14 })
    .backgroundColor('#66FFFFFF')
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: { top: 0.5 }, color: OceanPalette.GLASS_BORDER })
  }

  @Builder
  private buildVoiceOverlay() {
    Column() {
      Blank()
      Column() {
        Text(this.cancelArmed ? '🚫' : '🎙')
          .fontSize(40)
          .margin({ bottom: 10 })
        Text(this.recordedText.length > 0 ? this.recordedText : '请开始说话…')
          .fontSize(OceanFont.SUBHEAD)
          .fontFamily(LXGW_FONT)
          .fontColor(this.recordedText.length > 0 ? OceanPalette.TEXT_ON_GLASS : OceanPalette.TEXT_MUTED)
          .textAlign(TextAlign.Center)
          .lineHeight(26)
          .maxLines(6)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.cancelArmed ? '松开手指 · 取消发送' : '松手发送 · 上滑取消')
          .fontSize(OceanFont.CAPTION)
          .fontFamily(LXGW_FONT)
          .fontColor(this.cancelArmed ? OceanPalette.ACCENT_DANGER : OceanPalette.OCEAN)
          .margin({ top: 14 })
      }
      .width('80%')
      .padding(22)
      .backgroundColor(this.cancelArmed ? '#F2FFE9EC' : '#F2FFFFFF')
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
      .borderRadius(OceanRadius.CARD)
      .border({ width: 1, color: this.cancelArmed ? OceanPalette.ACCENT_DANGER : OceanPalette.GLASS_BORDER })
      .shadow({ radius: 30, color: '#550077B6', offsetX: 0, offsetY: 8 })
      .margin({ bottom: 96 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private buildDrawer() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#73001022')
        .onClick(() => { this.showDrawer = false; })
        .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))

      // 左侧面板
      Column() {
        Row() {
          Text('🗂 对话历史')
            .fontSize(OceanFont.HEADING)
            .fontWeight(FontWeight.Bold)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.OCEAN)
            .layoutWeight(1)
          Text('✕')
            .fontSize(18)
            .fontColor(OceanPalette.TEXT_SECONDARY)
            .width(32)
            .height(32)
            .textAlign(TextAlign.Center)
            .onClick(() => { this.showDrawer = false; })
        }
        .width('100%')
        .padding({ top: 54, left: 16, right: 12, bottom: 8 })

        Row({ space: 10 }) {
          Text('＋ 新建对话')
            .layoutWeight(1)
            .height(42)
            .textAlign(TextAlign.Center)
            .fontSize(OceanFont.BODY)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_WHITE)
            .linearGradient(OceanGradients.BUTTON_PRIMARY)
            .borderRadius(OceanRadius.BUTTON)
            .onClick(() => { this.onNewSession(); })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 4, bottom: 8 })

        Row() {
          Text('💭 本次对话记忆（' + this.memories.length.toString() + '）')
            .layoutWeight(1)
            .fontSize(OceanFont.CAPTION)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.ACCENT_KELP)
          Text('🧹 清空')
            .fontSize(OceanFont.CAPTION)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.ACCENT_DANGER)
            .onClick(() => { this.onClearCurrent(); })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 2, bottom: 8 })
        .onClick(() => { this.openMemory(); })

        Divider().color('#33708090').margin({ left: 14, right: 14 })

        Scroll() {
          Column() {
            ForEach(this.sessions, (meta: SessionMeta) => {
              this.buildSessionRow(meta)
            }, (meta: SessionMeta) => this.sessionKey(meta))
            if (this.sessions.length === 0) {
              Text('暂无历史对话')
                .fontSize(OceanFont.CAPTION)
                .fontFamily(LXGW_FONT)
                .fontColor(OceanPalette.TEXT_MUTED)
                .margin({ top: 30 })
            }
            Blank().height(20)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('80%')
      .height('100%')
      .backgroundColor('#F2F9FD')
      .shadow({ radius: 30, color: '#55002244', offsetX: 6, offsetY: 0 })
      .transition(TransitionEffect.move(TransitionEdge.START).animation({ duration: 240, curve: Curve.EaseOut }))
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildSessionRow(meta: SessionMeta) {
    Row() {
      Column() {
        Text(meta.title)
          .fontSize(OceanFont.BODY)
          .fontWeight(meta.id === this.currentId ? FontWeight.Bold : FontWeight.Normal)
          .fontFamily(LXGW_FONT)
          .fontColor(meta.id === this.currentId ? OceanPalette.OCEAN : OceanPalette.TEXT_ON_GLASS)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(this.formatTime(meta.updatedAt) + ' · ' + meta.messageCount.toString() + ' 条')
          .fontSize(OceanFont.MICRO)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_MUTED)
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => { this.onSwitch(meta.id); })

      Text('✎')
        .fontSize(16)
        .width(30)
        .height(30)
        .textAlign(TextAlign.Center)
        .fontColor(OceanPalette.TEXT_SECONDARY)
        .onClick(() => { this.openRename(meta.id, meta.title); })

      Text('🗑')
        .fontSize(15)
        .width(30)
        .height(30)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.onDeleteSession(meta); })
    }
    .width('100%')
    .padding({ left: 14, right: 10, top: 12, bottom: 12 })
    .margin({ left: 8, right: 8, top: 6 })
    .backgroundColor(meta.id === this.currentId ? '#CCE4F4FB' : '#99FFFFFF')
    .borderRadius(14)
    .border({ width: meta.id === this.currentId ? 1 : 0, color: OceanPalette.LAGOON })
  }

  @Builder
  private buildSheet() {
    if (this.sheetMode === 2) {
      this.buildRenameSheet()
    } else {
      this.buildMemorySheet()
    }
  }

  @Builder
  private buildRenameSheet() {
    Column() {
      Text('重命名对话')
        .fontSize(OceanFont.HEADING)
        .fontWeight(FontWeight.Bold)
        .fontFamily(LXGW_FONT)
        .fontColor(OceanPalette.TEXT_ON_GLASS)
        .margin({ top: 18, bottom: 16 })

      TextInput({ text: this.renameText, placeholder: '输入对话名称' })
        .width('88%')
        .height(48)
        .fontFamily(LXGW_FONT)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .border({ width: 1, color: OceanPalette.GLASS_BORDER })
        .onChange((v: string) => { this.renameText = v; })

      Row({ space: 12 }) {
        Text('取消')
          .layoutWeight(1)
          .height(46)
          .textAlign(TextAlign.Center)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_SECONDARY)
          .backgroundColor('#E8EEF3')
          .borderRadius(OceanRadius.BUTTON)
          .onClick(() => { this.showSheet = false; })
        Text('确定')
          .layoutWeight(1)
          .height(46)
          .textAlign(TextAlign.Center)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_WHITE)
          .linearGradient(OceanGradients.BUTTON_PRIMARY)
          .borderRadius(OceanRadius.BUTTON)
          .onClick(() => { this.confirmRename(); })
      }
      .width('88%')
      .margin({ top: 20 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildMemorySheet() {
    Column() {
      Text('💭 对话记忆')
        .fontSize(OceanFont.HEADING)
        .fontWeight(FontWeight.Bold)
        .fontFamily(LXGW_FONT)
        .fontColor(OceanPalette.TEXT_ON_GLASS)
        .margin({ top: 18, bottom: 6 })
      Text('长期记忆会被注入后续对话；压缩上下文用于在长对话中节省 token。可手动删除任意一段。')
        .fontSize(OceanFont.MICRO)
        .fontFamily(LXGW_FONT)
        .fontColor(OceanPalette.TEXT_MUTED)
        .textAlign(TextAlign.Center)
        .margin({ left: 24, right: 24, bottom: 12 })

      if (this.memories.length === 0) {
        Column() {
          Text('暂无记忆')
            .fontSize(OceanFont.BODY)
            .fontFamily(LXGW_FONT)
            .fontColor(OceanPalette.TEXT_MUTED)
        }
        .width('100%')
        .height(160)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.memories, (memory: MemorySegment) => {
              this.buildMemoryItem(memory)
            }, (memory: MemorySegment) => this.memoryKey(memory))
            Blank().height(20)
          }
          .width('92%')
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildMemoryItem(memory: MemorySegment) {
    Row() {
      Column() {
        Text(memory.kind === 'long_term' ? '长期记忆' : '压缩上下文')
          .fontSize(OceanFont.MICRO)
          .fontFamily(LXGW_FONT)
          .fontColor(memory.kind === 'long_term' ? OceanPalette.ACCENT_KELP : OceanPalette.ACCENT_GOLD)
          .margin({ bottom: 4 })
        Text(memory.summary)
          .fontSize(OceanFont.CAPTION)
          .fontFamily(LXGW_FONT)
          .fontColor(OceanPalette.TEXT_ON_GLASS)
          .lineHeight(20)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('删除')
        .fontSize(OceanFont.MICRO)
        .fontFamily(LXGW_FONT)
        .fontColor(OceanPalette.ACCENT_DANGER)
        .height(28)
        .padding({ left: 12, right: 12 })
        .borderRadius(14)
        .backgroundColor('#FFECEE')
        .border({ width: 1, color: OceanPalette.ACCENT_DANGER + '66' })
        .onClick(() => { this.controller.deleteMemory(memory.id); })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding(12)
    .margin({ top: 8 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: OceanPalette.GLASS_BORDER })
  }
}

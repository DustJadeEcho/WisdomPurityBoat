/**
 * TTSManager —— 基于 HarmonyOS CoreSpeechKit 的文字转语音管理器
 * 支持：整段朗读、流式队列追加、暂停、继续、停止
 */
import { textToSpeech } from '@kit.CoreSpeechKit';

type SpeakDoneCallback = () => void;

export class TTSManager {
  private ttsEngine: textToSpeech.TextToSpeechEngine | null = null;
  private isInitialized: boolean = false;
  private isPlaying: boolean = false;
  private isPaused: boolean = false;
  private muted: boolean = false;
  private onDoneCallback: SpeakDoneCallback | null = null;
  private segments: string[] = [];
  private currentSegIndex: number = 0;
  private currentSegmentText: string = '';
  private pendingRaw: string = '';
  private playEpoch: number = 0;

  /** 从 requestId 中解析所属播放轮次（seg_<epoch>_<index>） */
  private epochOf(utteranceId: string): number {
    const parts = utteranceId.split('_');
    if (parts.length >= 2) {
      const e = parseInt(parts[1], 10);
      return isNaN(e) ? -1 : e;
    }
    return -1;
  }

  private async init(): Promise<boolean> {
    if (this.isInitialized && this.ttsEngine !== null) return true;
    try {
      const initParams: textToSpeech.CreateEngineParams = {
        language: 'zh-CN',
        person: 0,
        online: 1
      };
      this.ttsEngine = await textToSpeech.createEngine(initParams);
      const speakListener: textToSpeech.SpeakListener = {
        onStart: (utteranceId: string, _response: textToSpeech.StartResponse) => {
          if (this.epochOf(utteranceId) !== this.playEpoch) return; // 忽略已被打断的旧轮次
          this.isPlaying = true;
        },
        onComplete: (utteranceId: string, _response: textToSpeech.CompleteResponse) => {
          if (this.epochOf(utteranceId) !== this.playEpoch) return;
          this.isPlaying = false;
          this.currentSegmentText = '';
          this.playNextSegment();
        },
        onStop: (utteranceId: string, _response: textToSpeech.StopResponse) => {
          if (this.epochOf(utteranceId) !== this.playEpoch) return;
          this.isPlaying = false;
          if (!this.isPaused) {
            this.resetQueue();
          }
        },
        onError: (utteranceId: string, _errorCode: number, _errorMessage: string) => {
          if (this.epochOf(utteranceId) !== this.playEpoch) return;
          this.isPlaying = false;
          this.currentSegmentText = '';
          this.playNextSegment();
        },
        onData: (_utteranceId: string, _audio: ArrayBuffer, _response: textToSpeech.SynthesisResponse) => {
        }
      };
      this.ttsEngine.setListener(speakListener);
      this.isInitialized = true;
      return true;
    } catch (_e) {
      this.isInitialized = false;
      this.ttsEngine = null;
      return false;
    }
  }

  /** 把 Markdown 文本清洗成适合朗读的纯文本（尽量去除所有格式符号） */
  private stripMarkdown(text: string): string {
    return text
      .replace(/```[\s\S]*?```/g, '，')                 // 围栏代码块
      .replace(/~~~[\s\S]*?~~~/g, '，')
      .replace(/`([^`]*)`/g, '$1')                       // 行内代码
      .replace(/!\[[^\]]*\]\([^)]*\)/g, '')               // 图片
      .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')           // 链接 → 取文字
      .replace(/^\s{0,3}#{1,6}\s+/gm, '')                 // 标题
      .replace(/^\s*>+\s?/gm, '')                         // 引用
      .replace(/^\s*[-*+]\s+\[[ xX]\]\s*/gm, '')          // 任务清单
      .replace(/^\s*[-*+]\s+/gm, '')                      // 无序列表标记
      .replace(/^\s*\d+\.\s+/gm, '')                      // 有序列表标记
      .replace(/^\s*\|?[-:\s|]+\|?\s*$/gm, '')            // 表格分隔行
      .replace(/\|/g, '，')                                // 表格单元格竖线 → 停顿
      .replace(/\*\*([^*]+)\*\*/g, '$1')                  // 粗体
      .replace(/\*([^*]+)\*/g, '$1')                       // 斜体
      .replace(/__([^_]+)__/g, '$1')
      .replace(/_([^_]+)_/g, '$1')
      .replace(/~~([^~]+)~~/g, '$1')                       // 删除线
      .replace(/==([^=]+)==/g, '$1')                       // 高亮
      .replace(/\[\^[^\]]+\]/g, '')                        // 脚注引用
      .replace(/[-*_]{3,}/g, '，')                          // 分隔线
      .replace(/[`*_~>#|=]/g, '')                          // 残留的格式符号
      .replace(/[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{2300}-\u{23FF}\u{FE00}-\u{FE0F}\u{200D}\u{20E3}\u{2122}\u{2139}]/gu, '') // 表情/图标
      .replace(/\n{2,}/g, '，')
      .replace(/\n/g, '，')
      .replace(/，{2,}/g, '，')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private splitText(text: string): string[] {
    const plain = this.stripMarkdown(text);
    const MAX_LEN = 120;
    const result: string[] = [];
    const sentenceReg = /[^。！？!?；;：:\n]+[。！？!?；;：:\n]*/g;
    let buf = '';
    let match: RegExpExecArray | null;
    while ((match = sentenceReg.exec(plain)) !== null) {
      const sentence = match[0].trim();
      if (sentence.length === 0) continue;
      if (buf.length + sentence.length > MAX_LEN) {
        if (buf.length > 0) result.push(buf.trim());
        buf = sentence;
      } else {
        buf += sentence;
      }
    }
    if (buf.trim().length > 0) result.push(buf.trim());
    if (result.length === 0) {
      for (let i = 0; i < plain.length; i += MAX_LEN) {
        result.push(plain.substring(i, i + MAX_LEN).trim());
      }
    }
    return result.filter(item => item.length > 0);
  }

  private resetQueue(): void {
    this.segments = [];
    this.currentSegIndex = 0;
    this.currentSegmentText = '';
    this.pendingRaw = '';
    this.isPaused = false;
  }

  private playNextSegment(): void {
    if (this.isPaused) return;
    if (this.currentSegIndex >= this.segments.length) {
      this.currentSegmentText = '';
      if (this.pendingRaw.length > 0) {
        const remainSegments = this.splitText(this.pendingRaw);
        this.pendingRaw = '';
        this.segments = remainSegments;
        this.currentSegIndex = 0;
      }
    }
    if (this.currentSegIndex >= this.segments.length) {
      this.segments = [];
      this.currentSegIndex = 0;
      if (this.onDoneCallback) {
        const cb = this.onDoneCallback;
        this.onDoneCallback = null;
        cb();
      }
      return;
    }
    const seg = this.segments[this.currentSegIndex++];
    this.currentSegmentText = seg;
    if (!this.ttsEngine) return;
    try {
      const speakParams: textToSpeech.SpeakParams = {
        requestId: 'seg_' + this.playEpoch.toString() + '_' + this.currentSegIndex.toString()
      };
      this.ttsEngine.speak(seg, speakParams);
    } catch (_e) {
      this.currentSegmentText = '';
      this.playNextSegment();
    }
  }

  /**
   * 把已积累的「原始 Markdown」按完整句子取出、清洗后入队。
   * 关键：清洗在「整句」上进行，这样跨增量拆分的格式符号（如 ** 加粗）也能被正确成对去除，
   * 不会把格式符号读出来。
   */
  private flushPendingByBoundary(force: boolean): void {
    if (this.pendingRaw.length === 0) return;

    let lastBoundary = -1;
    for (let i = 0; i < this.pendingRaw.length; i++) {
      const ch = this.pendingRaw.charAt(i);
      if (ch === '。' || ch === '！' || ch === '？' || ch === '!' || ch === '?' ||
        ch === '；' || ch === ';' || ch === '\n') {
        lastBoundary = i;
      }
    }

    let toProcess = '';
    if (lastBoundary >= 0) {
      toProcess = this.pendingRaw.substring(0, lastBoundary + 1);
      this.pendingRaw = this.pendingRaw.substring(lastBoundary + 1);
    }
    if (force && this.pendingRaw.trim().length > 0) {
      toProcess += this.pendingRaw;
      this.pendingRaw = '';
    }
    if (toProcess.trim().length === 0) return;

    const pieces = this.splitText(toProcess);
    if (pieces.length === 0) return;
    this.segments.push(...pieces);
    if (!this.isPlaying && !this.isPaused) {
      this.playNextSegment();
    }
  }

  async speak(text: string, onDone?: SpeakDoneCallback): Promise<void> {
    if (this.muted) {
      if (onDone) onDone();
      return;
    }
    const ready = await this.init();
    if (!ready) {
      if (onDone) onDone();
      return;
    }
    this.stop();
    this.onDoneCallback = onDone ?? null;
    this.segments = this.splitText(text);
    this.currentSegIndex = 0;
    this.pendingRaw = '';
    this.playNextSegment();
  }

  async enqueue(text: string, forceFlush: boolean = false): Promise<void> {
    if (this.muted) {
      return;
    }
    const ready = await this.init();
    if (!ready) {
      return;
    }
    // 累积「原始 Markdown」，清洗推迟到整句取出时进行
    this.pendingRaw += text;
    this.flushPendingByBoundary(forceFlush);
  }

  pause(): void {
    if (!this.ttsEngine || !this.isPlaying) return;
    this.isPaused = true;
    if (this.currentSegmentText.length > 0) {
      this.segments.splice(Math.max(this.currentSegIndex - 1, 0), 0, this.currentSegmentText);
      this.currentSegIndex = Math.max(this.currentSegIndex - 1, 0);
      this.currentSegmentText = '';
    }
    try {
      this.ttsEngine.stop();
    } catch (_e) {
      this.isPaused = false;
    }
  }

  resume(): void {
    if (!this.isPaused) return;
    this.isPaused = false;
    if (!this.isPlaying) {
      this.playNextSegment();
    }
  }

  stop(): void {
    // 进入新一轮：旧轮次的异步回调（onStop/onComplete）将被 epoch 守卫忽略，避免清掉新队列
    this.playEpoch++;
    // 无条件停止引擎：即使当前处于「已下发但尚未 onStart」的间隙，也要确保旧内容被打断
    if (this.ttsEngine) {
      try {
        this.ttsEngine.stop();
      } catch (_e) {
      }
    }
    this.isPlaying = false;
    this.onDoneCallback = null;
    this.resetQueue();
  }

  isCurrentlyPlaying(): boolean {
    return this.isPlaying;
  }

  isCurrentlyPaused(): boolean {
    return this.isPaused;
  }

  setMuted(muted: boolean): void {
    this.muted = muted;
    if (muted) {
      this.stop();
    }
  }

  isMuted(): boolean {
    return this.muted;
  }

  destroy(): void {
    this.stop();
    if (this.ttsEngine) {
      try {
        this.ttsEngine.shutdown();
      } catch (_e) {
      }
      this.ttsEngine = null;
    }
    this.isInitialized = false;
  }
}

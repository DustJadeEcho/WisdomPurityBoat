/**
 * ASRManager —— 基于讯飞开放平台「语音听写（流式版）」的「按住说话」语音识别管理器
 * 自行采集麦克风 PCM（16k/16bit/单声道），通过 WebSocket 流式上传，按住开始、松手结束。
 * 协议文档：https://www.xfyun.cn/doc/asr/voicedictation/API.html
 */
import { webSocket } from '@kit.NetworkKit';
import { audio } from '@kit.AudioKit';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';

// 讯飞开放平台「语音听写（流式版）」凭据，控制台获取后填入
const XUNFEI_APPID = 'your-appid';
const XUNFEI_API_KEY = 'your-api-key';
const XUNFEI_API_SECRET = 'your-api-secret';
const IAT_HOST = 'iat-api.xfyun.cn';
const IAT_PATH = '/v2/iat';
const AUDIO_FORMAT = 'audio/L16;rate=16000';

export type ASRTextCallback = (text: string, isFinal: boolean) => void;

interface IatCw {
  w: string;
}

interface IatWs {
  cw: IatCw[];
}

interface IatResult {
  sn: number;
  pgs?: string;
  rg?: number[];
  ws: IatWs[];
}

interface IatData {
  status: number;
  result?: IatResult;
}

interface IatResponse {
  code: number;
  message: string;
  data?: IatData;
}

interface IatCommon {
  app_id: string;
}

interface IatBusiness {
  language: string;
  domain: string;
  accent: string;
  vad_eos: number;
  dwa: string;
}

interface IatFrameData {
  status: number;
  format: string;
  encoding: string;
  audio: string;
}

interface IatFirstFrame {
  common: IatCommon;
  business: IatBusiness;
  data: IatFrameData;
}

interface IatAudioFrame {
  data: IatFrameData;
}

export class ASRManager {
  private ws: webSocket.WebSocket | null = null;
  private capturer: audio.AudioCapturer | null = null;
  private onText: ASRTextCallback | null = null;
  private listening: boolean = false;
  private wsOpen: boolean = false;
  private firstFrameSent: boolean = false;
  private awaitingFinal: boolean = false;
  private finalReported: boolean = false;
  private seq: number = 0;
  private pendingAudio: string[] = [];
  private resultMap: Map<number, string> = new Map();
  private finalTimer: number = -1;
  private base64: util.Base64Helper = new util.Base64Helper();

  /** 预热（保留接口兼容；讯飞方案按次建连，无需预创建引擎） */
  async prepare(): Promise<void> {
  }

  async start(onText: ASRTextCallback): Promise<boolean> {
    this.reset();
    const seq = ++this.seq;
    this.onText = onText;
    try {
      const url = await this.buildAuthUrl();
      // 录音与建连并行：建连期间的音频先缓存，连上后补发，避免吞掉开头字句
      const capPromise = this.createAndStartCapturer(seq);
      const wsPromise = this.connectWs(url, seq);
      const capOk = await capPromise;
      const wsOk = await wsPromise;
      if (!capOk || !wsOk || seq !== this.seq) {
        this.teardown();
        return false;
      }
      this.listening = true;
      return true;
    } catch (_e) {
      this.teardown();
      return false;
    }
  }

  /** 松手：结束录音，发送结束帧，等服务端返回最终结果后触发 onText(text, true) */
  stop(): void {
    if (!this.listening) {
      return;
    }
    this.listening = false;
    this.awaitingFinal = true;
    this.stopCapturer();
    this.trySendEnd(this.seq);
    // 兜底：结束帧发出后若迟迟拿不到最终结果，用已有内容收尾并断开
    if (this.finalTimer !== -1) {
      clearTimeout(this.finalTimer);
    }
    this.finalTimer = setTimeout(() => {
      this.finalTimer = -1;
      this.emitFinal();
      this.closeWs();
    }, 4000);
  }

  /** 取消（丢弃结果） */
  cancel(): void {
    this.seq++;
    this.reset();
  }

  isListening(): boolean {
    return this.listening;
  }

  destroy(): void {
    this.cancel();
  }

  // ─── 鉴权 ───────────────────────────────────────────────────────────

  private async buildAuthUrl(): Promise<string> {
    const date = new Date().toUTCString();
    const signatureOrigin = `host: ${IAT_HOST}\ndate: ${date}\nGET ${IAT_PATH} HTTP/1.1`;
    const signature = await this.hmacSha256Base64(signatureOrigin, XUNFEI_API_SECRET);
    const authOrigin =
      `api_key="${XUNFEI_API_KEY}", algorithm="hmac-sha256", headers="host date request-line", signature="${signature}"`;
    const authorization = this.base64.encodeToStringSync(this.strToBytes(authOrigin));
    return `wss://${IAT_HOST}${IAT_PATH}?authorization=${encodeURIComponent(authorization)}` +
      `&date=${encodeURIComponent(date)}&host=${IAT_HOST}`;
  }

  private async hmacSha256Base64(text: string, secret: string): Promise<string> {
    const keyGen = cryptoFramework.createSymKeyGenerator('HMAC');
    const keyBlob: cryptoFramework.DataBlob = { data: this.strToBytes(secret) };
    const symKey = await keyGen.convertKey(keyBlob);
    const mac = cryptoFramework.createMac('SHA256');
    await mac.init(symKey);
    const textBlob: cryptoFramework.DataBlob = { data: this.strToBytes(text) };
    await mac.update(textBlob);
    const out = await mac.doFinal();
    return this.base64.encodeToStringSync(out.data);
  }

  private strToBytes(s: string): Uint8Array {
    return new util.TextEncoder().encodeInto(s);
  }

  // ─── WebSocket ─────────────────────────────────────────────────────

  private async connectWs(url: string, seq: number): Promise<boolean> {
    const ws = webSocket.createWebSocket();
    this.ws = ws;
    ws.on('message', (_err: BusinessError, value: string | ArrayBuffer) => {
      if (seq === this.seq && typeof value === 'string') {
        this.handleMessage(value);
      }
    });
    ws.on('error', (_err: BusinessError) => {
      if (seq === this.seq) {
        this.wsOpen = false;
        if (this.awaitingFinal) {
          this.emitFinal();
        }
      }
    });
    ws.on('close', (_err: BusinessError, _value: webSocket.CloseResult) => {
      if (seq === this.seq) {
        this.wsOpen = false;
      }
    });
    try {
      const ok = await ws.connect(url);
      if (!ok || seq !== this.seq) {
        return false;
      }
      this.wsOpen = true;
      this.flushPending(seq);
      this.trySendEnd(seq);
      return true;
    } catch (_e) {
      return false;
    }
  }

  private handleMessage(text: string): void {
    let resp: IatResponse;
    try {
      resp = JSON.parse(text) as IatResponse;
    } catch (_e) {
      return;
    }
    if (resp.code !== 0) {
      // 服务端出错（鉴权/参数/超时等）：用已有内容收尾
      if (this.awaitingFinal) {
        this.emitFinal();
      }
      this.closeWs();
      return;
    }
    const data = resp.data;
    if (data === undefined) {
      return;
    }
    const result = data.result;
    if (result !== undefined) {
      let piece = '';
      for (const w of result.ws) {
        for (const cw of w.cw) {
          piece += cw.w;
        }
      }
      // wpgs 动态修正：pgs=rpl 时，rg 范围内的历史分片被本片替换
      if (result.pgs === 'rpl' && result.rg !== undefined && result.rg.length === 2) {
        for (let i = result.rg[0]; i <= result.rg[1]; i++) {
          this.resultMap.delete(i);
        }
      }
      this.resultMap.set(result.sn, piece);
      if (this.onText !== null && !this.finalReported) {
        this.onText(this.assemble(), false);
      }
    }
    if (data.status === 2) {
      this.emitFinal();
      this.closeWs();
    }
  }

  private assemble(): string {
    const keys: number[] = Array.from(this.resultMap.keys()).sort((a, b) => a - b);
    let full = '';
    for (const k of keys) {
      full += this.resultMap.get(k);
    }
    return full;
  }

  private emitFinal(): void {
    if (this.finalReported) {
      return;
    }
    this.finalReported = true;
    this.awaitingFinal = false;
    if (this.finalTimer !== -1) {
      clearTimeout(this.finalTimer);
      this.finalTimer = -1;
    }
    if (this.onText !== null) {
      this.onText(this.assemble(), true);
    }
  }

  // ─── 音频采集与帧发送 ───────────────────────────────────────────────

  private async createAndStartCapturer(seq: number): Promise<boolean> {
    try {
      const options: audio.AudioCapturerOptions = {
        streamInfo: {
          samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
          channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
          encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        },
        capturerInfo: {
          source: audio.SourceType.SOURCE_TYPE_VOICE_RECOGNITION,
          capturerFlags: 0
        }
      };
      const cap = await audio.createAudioCapturer(options);
      if (seq !== this.seq) {
        cap.release((_err: BusinessError) => {
        });
        return false;
      }
      this.capturer = cap;
      cap.on('readData', (buffer: ArrayBuffer) => {
        this.onAudioData(seq, buffer);
      });
      await cap.start();
      return seq === this.seq;
    } catch (_e) {
      return false;
    }
  }

  private onAudioData(seq: number, buffer: ArrayBuffer): void {
    if (seq !== this.seq) {
      return;
    }
    const b64 = this.base64.encodeToStringSync(new Uint8Array(buffer));
    if (!this.wsOpen) {
      if (this.pendingAudio.length < 200) {
        this.pendingAudio.push(b64);
      }
      return;
    }
    this.flushPending(seq);
    this.sendAudioFrame(seq, b64);
  }

  private flushPending(seq: number): void {
    while (this.pendingAudio.length > 0 && this.wsOpen && seq === this.seq) {
      const b64 = this.pendingAudio.shift();
      if (b64 !== undefined) {
        this.sendAudioFrame(seq, b64);
      }
    }
  }

  private sendAudioFrame(seq: number, b64: string): void {
    if (this.ws === null || !this.wsOpen || seq !== this.seq) {
      return;
    }
    let payload: string;
    if (!this.firstFrameSent) {
      this.firstFrameSent = true;
      const frame: IatFirstFrame = {
        common: { app_id: XUNFEI_APPID },
        business: {
          language: 'zh_cn',
          domain: 'iat',
          accent: 'mandarin',
          vad_eos: 6000,
          dwa: 'wpgs'
        },
        data: { status: 0, format: AUDIO_FORMAT, encoding: 'raw', audio: b64 }
      };
      payload = JSON.stringify(frame);
    } else {
      const frame: IatAudioFrame = {
        data: { status: 1, format: AUDIO_FORMAT, encoding: 'raw', audio: b64 }
      };
      payload = JSON.stringify(frame);
    }
    this.ws.send(payload, (_err: BusinessError) => {
    });
  }

  /** 松手后：把缓存音频发完并补上结束帧（status=2）；若建连尚未完成，连上后由 connectWs 再次触发 */
  private trySendEnd(seq: number): void {
    if (!this.awaitingFinal || !this.wsOpen || this.ws === null || seq !== this.seq) {
      return;
    }
    this.flushPending(seq);
    if (!this.firstFrameSent) {
      // 一帧音频都没发出去（极快的点按），直接收尾
      this.emitFinal();
      this.closeWs();
      return;
    }
    const frame: IatAudioFrame = {
      data: { status: 2, format: AUDIO_FORMAT, encoding: 'raw', audio: '' }
    };
    this.ws.send(JSON.stringify(frame), (_err: BusinessError) => {
    });
  }

  // ─── 清理 ───────────────────────────────────────────────────────────

  private stopCapturer(): void {
    const cap = this.capturer;
    this.capturer = null;
    if (cap !== null) {
      cap.stop((_err: BusinessError) => {
        cap.release((_err2: BusinessError) => {
        });
      });
    }
  }

  private closeWs(): void {
    const ws = this.ws;
    this.ws = null;
    this.wsOpen = false;
    if (ws !== null) {
      try {
        ws.close((_err: BusinessError) => {
        });
      } catch (_e) {
      }
    }
  }

  private teardown(): void {
    this.stopCapturer();
    this.closeWs();
    this.listening = false;
    this.firstFrameSent = false;
    this.awaitingFinal = false;
    this.pendingAudio = [];
  }

  private reset(): void {
    this.teardown();
    this.resultMap.clear();
    this.finalReported = false;
    if (this.finalTimer !== -1) {
      clearTimeout(this.finalTimer);
      this.finalTimer = -1;
    }
  }
}


/**
 * AI 智能问答页 —— 调用 TokenSpark API（OpenAI 兼容格式）
 */
import { http } from '@kit.NetworkKit';
import { promptAction } from '@kit.ArkUI';
import { NavigationFunc } from '../common/Types';
import { markdownToHtml } from '../utils/MarkdownParser';   // ← 新增导入

// ============ ↓↓↓ 在这里填你自己的配置 ↓↓↓ ============
//const API_URL = 'https://chat.tokenspark.net/api/v1/chat/completions';
//const API_KEY = 'sk-caecec7afaccc68873a391fac710a5ee768bc02a11e1ad22';   // ← 换成你的 API Key
//const MODEL_NAME = 'deepseek-v3.2';            // ← 换成你要用的模型名
const API_URL = 'https://openrouter.ai/api/v1/chat/completions';
const API_KEY = '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';
const MODEL_NAME = 'arcee-ai/trinity-mini:free';            // ← 换成你要用的模型名

/** ===== 请求体类型 ===== */
interface ChatMessageParam {
  role: string;
  content: string;
}

interface ChatRequestBody {
  model: string;
  messages: ChatMessageParam[];
  stream: boolean;
}

/** ===== 响应体类型 ===== */
interface ChatMessage {
  role: string;
  content: string;
}

interface ChatChoice {
  index: number;
  message: ChatMessage;
  finish_reason: string;
}

interface ChatResponse {
  id: string;
  choices: ChatChoice[];
}

interface ErrorDetail {
  message: string;
  type: string;
}

interface ErrorResponse {
  error: ErrorDetail;
}

@Component
export struct AIPage {
  @State inputHint: string = '请您提问，青海AI智能体解答...';
  @State inputText: string = '';
  @State isLoading: boolean = false;
  @State hasResult: boolean = false;
  @State resultText: string = '';
  @State resultHtml: string = '';    // ← 新增：存储转换后的 HTML

  navigate: NavigationFunc = () => {};

  /** 设置结果（同时生成 HTML） */
  private setResult(text: string): void {
    this.resultText = text;
    this.resultHtml = markdownToHtml(text);    // ← 新增：Markdown → HTML
    this.hasResult = true;
    this.isLoading = false;
  }

  /** 发送问题到 TokenSpark */
  private async sendQuestion(): Promise<void> {
    if (this.inputText.trim() === '') {
      promptAction.showToast({ message: '请输入问题', duration: 2000 });
      return;
    }

    if (this.inputText.indexOf('青海') < 0) {
      promptAction.showToast({ message: '提问中必须包含"青海"两个字', duration: 3000 });
      return;
    }

    this.hasResult = false;
    this.isLoading = true;

    const systemMsg: ChatMessageParam = {
      role: 'system',
      content: '你是青海湖水质监测智能助手，请用中文回答关于青海的问题。'
    };

    const userMsg: ChatMessageParam = {
      role: 'user',
      content: this.inputText
    };

    const body: ChatRequestBody = {
      model: MODEL_NAME,
      messages: [systemMsg, userMsg],
      stream: false
    };

    const requestBody: string = JSON.stringify(body);
    const httpRequest = http.createHttp();

    try {
      const response = await httpRequest.request(API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + API_KEY
        },
        extraData: requestBody,
        connectTimeout: 30000,
        readTimeout: 60000
      });

      const resultContent = response.result as string;

      if (response.responseCode !== 200) {
        if (resultContent && resultContent.trim().length > 0) {
          try {
            const errResp = JSON.parse(resultContent) as ErrorResponse;
            if (errResp.error && errResp.error.message) {
              this.setResult('接口错误: ' + errResp.error.message);
            } else {
              this.setResult('HTTP ' + response.responseCode + ': ' + resultContent);
            }
          } catch (e) {
            this.setResult('HTTP ' + response.responseCode + ': ' + resultContent);
          }
        } else {
          this.setResult('请求失败，HTTP状态码: ' + response.responseCode);
        }
        return;
      }

      if (!resultContent || resultContent.trim().length === 0) {
        this.setResult('服务器返回空内容，请检查API配置');
        return;
      }

      const chatResp = JSON.parse(resultContent) as ChatResponse;

      if (chatResp.choices && chatResp.choices.length > 0) {
        this.setResult(chatResp.choices[0].message.content);    // ← 用 setResult
      } else {
        this.setResult('未获取到有效回答，请重试');
      }

    } catch (err) {
      this.setResult('请求失败: ' + JSON.stringify(err));
    } finally {
      httpRequest.destroy();
    }
  }

  build() {
    Column() {
      // ===== 顶部导航 =====
      Row() {
        Image($r('app.media.ic_back'))
          .width(24).height(24)
          .onClick(() => this.navigate(0))

        Text('AI 智能问答')
          .fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1).textAlign(TextAlign.Center)
          .margin({ left: 10 })
      }
      .padding(15).width('100%').backgroundColor('#1890FF')

      // ===== 当前问题显示 =====
      Row() {
        Text(this.inputText !== '' ? this.inputText : '请输入问题')
          .fontSize(16).fontColor('#333333')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('90%')
      .padding(12)
      .borderRadius(8)
      .backgroundColor(Color.White)
      .justifyContent(FlexAlign.Center)
      .margin({ top: 15 })
      .shadow({ radius: 4, color: '#1890FF22', offsetX: 0, offsetY: 2 })

      // ===== 回答区域 =====
      Scroll() {
        Column() {
          if (this.hasResult) {
            // ===== ↓↓↓ 核心改动：用 RichText 渲染 HTML ↓↓↓ =====
            Column() {
              Row() {
                Text('🤖 AI 回答')
                  .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1890FF')
              }
              .width('100%').margin({ bottom: 10 })

              RichText(this.resultHtml)
                .width('100%')
            }
            .padding(15)
            .margin(15)
            .backgroundColor(Color.White)
            .borderRadius(12)
            .shadow({ radius: 4, color: '#1890FF22', offsetX: 0, offsetY: 2 })
            // ===== ↑↑↑ 核心改动结束 ↑↑↑ =====

          } else if (this.isLoading) {
            Column() {
              LoadingProgress().width(80).color('#1890FF')
              Text('AI 大模型正在分析，请稍后...')
                .fontSize(14).fontColor('#666666')
                .margin({ top: 15 })
            }
            .margin({ top: 80 })

          } else {
            Column() {
              Text('💡 提问示例')
                .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1890FF')
                .margin({ bottom: 15 })
              Text('• 青海湖的水质标准是什么？')
                .fontSize(14).fontColor('#666666').margin({ bottom: 8 })
              Text('• 青海湖的PH值正常范围？')
                .fontSize(14).fontColor('#666666').margin({ bottom: 8 })
              Text('• 青海湖水质监测有哪些指标？')
                .fontSize(14).fontColor('#666666')
            }
            .padding(20)
            .margin({ top: 40 })
            .backgroundColor(Color.White)
            .borderRadius(12)
            .width('85%')
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')

      // ===== 底部输入区域 =====
      Row({ space: 8 }) {
        TextInput({ placeholder: this.inputHint })
          .layoutWeight(3)
          .height(44)
          .placeholderColor('#999999')
          .borderRadius(8)
          .backgroundColor(Color.White)
          .onFocus(() => {
            this.inputHint = '请您输入...';
          })
          .onChange((value: string) => {
            this.inputText = value;
          })

        Button('发送')
          .layoutWeight(1)
          .height(44)
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor(this.isLoading ? '#999999' : '#1890FF')
          .borderRadius(8)
          .enabled(!this.isLoading)
          .onClick(() => {
            this.sendQuestion();
          })
      }
      .width('95%')
      .padding({ top: 8, bottom: 12 })
    }
    .width('100%').height('100%').backgroundColor('#F0F5FF')
  }
}
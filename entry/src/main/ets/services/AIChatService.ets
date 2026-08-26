import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { AI_SYSTEM_PROMPT } from '../constants/AIPrompts'
import type { ChatRequestMessage, MemorySegment, StreamCallbacks } from '../common/AIChatTypes'

// 兼容 OpenAI Chat Completions 格式的服务地址，需支持 stream: true
const API_URL = 'https://your-api-host/v1/chat/completions'
const API_KEY = 'sk-your-api-key'
const MODEL_NAME = 'your-model-name'

interface DeltaContent {
  role?: string
  content?: string
  reasoning?: string
}

interface StreamChoice {
  index: number
  delta: DeltaContent
  finish_reason: string | null
}

interface StreamChunk {
  id: string
  choices: StreamChoice[]
}

interface ChatRequestBody {
  model: string
  messages: ChatRequestMessage[]
  stream: boolean
}

export class AIChatService {
  private httpRequest: http.HttpRequest | null = null

  buildRequestMessages(history: ChatRequestMessage[], memories: MemorySegment[], question: string): ChatRequestMessage[] {
    const requestMessages: ChatRequestMessage[] = [
      { role: 'system', content: AI_SYSTEM_PROMPT }
    ]

    memories.forEach((memory) => {
      requestMessages.push({
        role: 'system',
        content: `${memory.kind === 'long_term' ? '长期记忆' : '压缩上下文'}：${memory.summary}`
      })
    })

    history.forEach((message) => requestMessages.push(message))
    requestMessages.push({ role: 'user', content: question })
    return requestMessages
  }

  async sendStream(history: ChatRequestMessage[], memories: MemorySegment[], question: string, callbacks: StreamCallbacks): Promise<void> {
    this.destroy()
    this.httpRequest = http.createHttp()

    const body: ChatRequestBody = {
      model: MODEL_NAME,
      messages: this.buildRequestMessages(history, memories, question),
      stream: true
    }

    let sseBuffer: string = ''
    this.httpRequest.on('dataReceive', (data: ArrayBuffer) => {
      const decoder = new util.TextDecoder('utf-8')
      const text = decoder.decodeWithStream(new Uint8Array(data))
      sseBuffer += text
      const lines = sseBuffer.split('\n')
      sseBuffer = lines[lines.length - 1]
      for (let i = 0; i < lines.length - 1; i++) {
        const line = lines[i].trimEnd()
        if (line.length > 0) {
          this.parseSSELine(line, callbacks)
        }
      }
    })

    this.httpRequest.on('dataEnd', () => {
      if (sseBuffer.trim().length > 0) {
        this.parseSSELine(sseBuffer.trim(), callbacks)
      }
      callbacks.onDone()
    })

    try {
      await this.httpRequest.requestInStream(API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + API_KEY,
          'Accept': 'text/event-stream'
        },
        extraData: JSON.stringify(body),
        connectTimeout: 30000,
        readTimeout: 120000
      })
    } catch (err) {
      callbacks.onError('请求失败: ' + JSON.stringify(err))
    }
  }

  destroy(): void {
    if (this.httpRequest) {
      this.httpRequest.destroy()
      this.httpRequest = null
    }
  }

  private parseSSELine(line: string, callbacks: StreamCallbacks): void {
    if (!line.startsWith('data: ')) return
    const jsonStr = line.substring(6).trim()
    if (jsonStr === '[DONE]') {
      return
    }
    try {
      const chunk = JSON.parse(jsonStr) as StreamChunk
      if (!chunk.choices || chunk.choices.length === 0) return
      const delta = chunk.choices[0].delta
      if (delta.reasoning && delta.reasoning.length > 0) {
        callbacks.onReasoningDelta(delta.reasoning)
      }
      if (delta.content && delta.content.length > 0) {
        callbacks.onContentDelta(delta.content)
      }
    } catch (_e) {
    }
  }
}

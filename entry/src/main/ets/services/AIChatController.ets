import { webview } from '@kit.ArkWeb'
import { common } from '@kit.AbilityKit'
import { AIChatService } from './AIChatService'
import { AIChatStore } from './AIChatStore'
import { AIChatPersistence } from './AIChatPersistence'
import { TTSManager } from '../utils/TTSManager'
import { pickRandomExamples } from '../constants/AIPrompts'
import type {
  ChatMessageEntity,
  ChatRequestMessage,
  ConversationSession,
  SessionMeta
} from '../common/AIChatTypes'

interface WebMessagePayload {
  id: string
  role: string
  content: string
  reasoningText: string
  reasoningMs: number
  status: string
  tts: string
}

interface WebResetPayload {
  messages: WebMessagePayload[]
  examples: string[]
  muted: boolean
  streamingId: string
}

type ChangeListener = () => void

/**
 * AIChatController —— 模块级单例，跨页面存活。
 * 持有当前会话 + 会话列表 + 流式服务 + TTS + 持久化，
 * 组件卸载后流式仍在此继续累积，回到页面时由 onWebReady 整屏补推。
 */
export class AIChatController {
  sessions: SessionMeta[] = []
  current: ConversationSession
  isLoading: boolean = false
  muted: boolean = false
  examples: string[] = pickRandomExamples(6)

  private service: AIChatService = new AIChatService()
  private tts: TTSManager = new TTSManager()
  private store: AIChatStore = new AIChatStore()
  private persistence: AIChatPersistence | null = null

  private webCtrl: webview.WebviewController | null = null
  private webReady: boolean = false
  private listener: ChangeListener | null = null
  private ttsSuspended: boolean = false

  private inited: boolean = false
  private activeAssistantId: string = ''
  private reasoningStartAt: number = 0
  private reasoningStarted: boolean = false
  private reasoningEnded: boolean = false
  private lastSpokenLen: number = 0
  private saveTimer: number = -1

  constructor() {
    this.current = this.store.createEmptySession()
  }

  // ============ 初始化 ============
  async init(context: common.Context): Promise<void> {
    if (this.inited) {
      return
    }
    this.inited = true
    this.persistence = new AIChatPersistence(context)
    try {
      this.sessions = await this.persistence.listSessions()
      const activeId = await this.persistence.getActiveSessionId()
      let loaded: ConversationSession | null = null
      if (activeId) {
        loaded = await this.persistence.loadSession(activeId)
      }
      if (!loaded && this.sessions.length > 0) {
        loaded = await this.persistence.loadSession(this.sessions[0].id)
      }
      if (loaded) {
        this.current = this.normalizeSession(loaded)
      } else {
        this.current = this.store.createEmptySession()
        await this.persistAndIndex(true)
      }
    } catch (_e) {
      this.current = this.store.createEmptySession()
    }
    // 任何半截流式状态在重启后都置为完成，避免卡死
    this.current.messages.forEach((m) => {
      if (m.status === 'streaming') {
        m.status = 'done'
      }
      m.ttsState = 'idle'
    })
    this.notify()
    this.pushFullState()
  }

  private normalizeSession(session: ConversationSession): ConversationSession {
    session.messages = session.messages ?? []
    session.memories = session.memories ?? []
    session.draftInput = session.draftInput ?? ''
    session.title = session.title && session.title.length > 0 ? session.title : '新对话'
    return session
  }

  // ============ WebView 绑定 ============
  attachWeb(ctrl: webview.WebviewController): void {
    this.webCtrl = ctrl
    this.webReady = false
    // 回到页面：允许自动朗读
    this.ttsSuspended = false
  }

  detachWeb(): void {
    this.webReady = false
    this.webCtrl = null
    // 离开页面：停止朗读并暂停后台自动朗读（流式生成仍继续）
    this.ttsSuspended = true
    this.tts.stop()
    this.store.resetAllTTSState(this.current)
  }

  onWebReady(): void {
    this.webReady = true
    this.pushFullState()
  }

  private runJs(code: string): void {
    if (!this.webReady || this.webCtrl === null) {
      return
    }
    try {
      this.webCtrl.runJavaScript(code)
    } catch (_e) {
    }
  }

  private pushFullState(): void {
    const payload: WebResetPayload = {
      messages: this.current.messages.map((m): WebMessagePayload => this.toWebMessage(m)),
      examples: this.examples,
      muted: this.muted,
      streamingId: this.isLoading ? this.activeAssistantId : ''
    }
    this.runJs(`Chat.reset(${JSON.stringify(payload)})`)
  }

  private toWebMessage(m: ChatMessageEntity): WebMessagePayload {
    return {
      id: m.id,
      role: m.role,
      content: m.content,
      reasoningText: m.reasoningText,
      reasoningMs: m.reasoningDurationMs,
      status: m.status,
      tts: m.ttsState
    }
  }

  // ============ 订阅 ============
  subscribe(cb: ChangeListener): void {
    this.listener = cb
  }

  unsubscribe(): void {
    this.listener = null
  }

  private notify(): void {
    if (this.listener !== null) {
      this.listener()
    }
  }

  // ============ 发送 / 流式 ============
  send(question: string): void {
    const finalQuestion = question.trim()
    if (finalQuestion.length === 0 || this.isLoading) {
      return
    }

    const history = this.buildHistoryForRequest()
    const userMessage = this.store.newMessage('user', finalQuestion)
    const assistantMessage = this.store.newMessage('assistant', '')
    this.store.appendMessage(this.current, userMessage)
    this.store.appendMessage(this.current, assistantMessage)
    this.current.draftInput = ''

    this.isLoading = true
    this.activeAssistantId = assistantMessage.id
    this.reasoningStartAt = 0
    this.reasoningStarted = false
    this.reasoningEnded = false
    this.lastSpokenLen = 0

    // 切断上一条朗读，开始新内容的播报
    this.stopSpeaking()
    this.store.setMessageTTSState(this.current, assistantMessage.id, this.muted ? 'idle' : 'playing')

    // 推给 WebView
    this.runJs(`Chat.addUser(${JSON.stringify(userMessage.id)}, ${JSON.stringify(finalQuestion)})`)
    this.runJs(`Chat.startAssistant(${JSON.stringify(assistantMessage.id)})`)
    if (!this.muted) {
      this.runJs(`Chat.setTts(${JSON.stringify(assistantMessage.id)}, "playing")`)
    }

    this.notify()
    this.scheduleSave()

    this.service.sendStream(history, this.current.memories, finalQuestion, {
      onReasoningDelta: (delta: string) => {
        if (!this.reasoningStarted) {
          this.reasoningStarted = true
          this.reasoningStartAt = Date.now()
        }
        this.store.appendReasoning(this.current, assistantMessage.id, delta)
        this.runJs(`Chat.appendReasoning(${JSON.stringify(assistantMessage.id)}, ${JSON.stringify(delta)})`)
        this.scheduleSave()
      },
      onContentDelta: (delta: string) => {
        if (this.reasoningStarted && !this.reasoningEnded) {
          this.reasoningEnded = true
          const ms = Date.now() - this.reasoningStartAt
          const target = this.store.findMessage(this.current, assistantMessage.id)
          if (target !== null) {
            target.reasoningDurationMs = ms
          }
          this.runJs(`Chat.endReasoning(${JSON.stringify(assistantMessage.id)}, ${ms})`)
        }
        this.store.updateAssistantDelta(this.current, assistantMessage.id, delta)
        this.runJs(`Chat.appendContent(${JSON.stringify(assistantMessage.id)}, ${JSON.stringify(delta)})`)
        this.enqueueTTS(assistantMessage.id)
        this.scheduleSave()
      },
      onDone: () => {
        this.finishStreaming(assistantMessage.id, false, '')
      },
      onError: (message: string) => {
        this.store.markAssistantError(this.current, assistantMessage.id, message)
        this.runJs(`Chat.setError(${JSON.stringify(assistantMessage.id)}, ${JSON.stringify(message)})`)
        this.finishStreaming(assistantMessage.id, true, message)
      }
    })
  }

  private buildHistoryForRequest(): ChatRequestMessage[] {
    const result: ChatRequestMessage[] = []
    for (let i = 0; i < this.current.messages.length; i++) {
      const message = this.current.messages[i]
      if ((message.role === 'user' || message.role === 'assistant') && message.content.length > 0) {
        result.push({ role: message.role, content: message.content })
      }
    }
    return result
  }

  private enqueueTTS(messageId: string): void {
    if (this.muted || this.ttsSuspended) {
      return
    }
    const message = this.store.findMessage(this.current, messageId)
    if (message === null) {
      return
    }
    const deltaText = message.content.substring(this.lastSpokenLen)
    if (deltaText.length === 0) {
      return
    }
    this.lastSpokenLen = message.content.length
    this.tts.enqueue(deltaText, false)
  }

  private finishStreaming(messageId: string, isError: boolean, errorMsg: string): void {
    if (!isError) {
      const duration = this.reasoningStarted ? Math.max(0, (this.reasoningEnded ? 0 : Date.now() - this.reasoningStartAt)) : 0
      const target = this.store.findMessage(this.current, messageId)
      const finalMs = target !== null && target.reasoningDurationMs > 0 ? target.reasoningDurationMs : duration
      this.store.finishAssistantMessage(this.current, messageId, finalMs)
      this.runJs(`Chat.finishAssistant(${JSON.stringify(messageId)}, ${finalMs})`)
    }
    if (!this.muted && !this.ttsSuspended) {
      this.tts.enqueue('。', true)
    }
    this.isLoading = false
    this.activeAssistantId = ''
    this.notify()
    this.refreshSessionsAndSave()
  }

  // ============ TTS ============
  toggleMute(): void {
    this.setMuted(!this.muted)
  }

  setMuted(muted: boolean): void {
    this.muted = muted
    this.tts.setMuted(muted)
    if (muted) {
      this.store.resetAllTTSState(this.current)
    }
    this.runJs(`Chat.setMuted(${muted})`)
    this.notify()
    this.scheduleSave()
  }

  /** 立即停止当前朗读（不改变静音设置），并同步 WebView 按钮状态 */
  stopSpeaking(): void {
    this.tts.stop()
    for (let i = 0; i < this.current.messages.length; i++) {
      const m = this.current.messages[i]
      if (m.ttsState !== 'idle') {
        m.ttsState = 'idle'
        this.runJs(`Chat.setTts(${JSON.stringify(m.id)}, "idle")`)
      }
    }
    this.notify()
  }

  /** WebView 中某条消息的「朗读/暂停/继续」按钮 */
  bridgeReadAloud(messageId: string): void {
    const message = this.store.findMessage(this.current, messageId)
    if (message === null) {
      return
    }
    if (message.ttsState === 'playing') {
      this.tts.pause()
      this.store.setMessageTTSState(this.current, messageId, 'paused')
      this.runJs(`Chat.setTts(${JSON.stringify(messageId)}, "paused")`)
    } else if (message.ttsState === 'paused') {
      this.tts.resume()
      this.store.setMessageTTSState(this.current, messageId, 'playing')
      this.runJs(`Chat.setTts(${JSON.stringify(messageId)}, "playing")`)
    } else {
      if (this.muted) {
        this.setMuted(false)
      }
      this.tts.stop()
      this.store.setMessageTTSState(this.current, messageId, 'playing')
      this.runJs(`Chat.setTts(${JSON.stringify(messageId)}, "playing")`)
      this.tts.speak(message.content, () => {
        this.store.setMessageTTSState(this.current, messageId, 'idle')
        this.runJs(`Chat.setTts(${JSON.stringify(messageId)}, "idle")`)
        this.notify()
      })
    }
    this.notify()
    this.scheduleSave()
  }

  bridgeExampleTap(text: string): void {
    this.send(text)
  }

  // ============ 会话管理 ============
  async newSession(): Promise<void> {
    this.stopStream()
    this.tts.stop()
    await this.saveNow()
    this.current = this.store.createEmptySession()
    this.examples = pickRandomExamples(6)
    await this.persistAndIndex(true)
    this.pushFullState()
    this.notify()
  }

  async switchSession(sessionId: string): Promise<void> {
    if (sessionId === this.current.id || this.persistence === null) {
      return
    }
    this.stopStream()
    this.tts.stop()
    await this.saveNow()
    const loaded = await this.persistence.loadSession(sessionId)
    if (loaded === null) {
      return
    }
    this.current = this.normalizeSession(loaded)
    this.current.messages.forEach((m) => {
      if (m.status === 'streaming') {
        m.status = 'done'
      }
      m.ttsState = 'idle'
    })
    this.examples = pickRandomExamples(6)
    await this.persistence.setActiveSessionId(sessionId)
    this.sessions = await this.persistence.listSessions()
    this.pushFullState()
    this.notify()
  }

  async deleteSession(sessionId: string): Promise<void> {
    if (this.persistence === null) {
      return
    }
    await this.persistence.deleteSession(sessionId)
    if (sessionId === this.current.id) {
      this.stopStream()
      this.tts.stop()
      const metas = await this.persistence.listSessions()
      if (metas.length > 0) {
        const loaded = await this.persistence.loadSession(metas[0].id)
        this.current = loaded !== null ? this.normalizeSession(loaded) : this.store.createEmptySession()
      } else {
        this.current = this.store.createEmptySession()
      }
      this.examples = pickRandomExamples(6)
      await this.persistAndIndex(true)
      this.pushFullState()
    } else {
      this.sessions = await this.persistence.listSessions()
    }
    this.notify()
  }

  async renameSession(sessionId: string, title: string): Promise<void> {
    const clean = title.trim()
    if (clean.length === 0 || this.persistence === null) {
      return
    }
    if (sessionId === this.current.id) {
      this.current.title = clean
      await this.saveNow()
    } else {
      const loaded = await this.persistence.loadSession(sessionId)
      if (loaded !== null) {
        loaded.title = clean
        loaded.updatedAt = Date.now()
        await this.persistence.saveSession(loaded)
      }
    }
    this.sessions = await this.persistence.listSessions()
    this.notify()
  }

  async clearCurrent(): Promise<void> {
    this.stopStream()
    this.tts.stop()
    this.store.clearMessages(this.current)
    this.examples = pickRandomExamples(6)
    await this.saveNow()
    if (this.persistence !== null) {
      this.sessions = await this.persistence.listSessions()
    }
    this.pushFullState()
    this.notify()
  }

  async deleteMemory(memoryId: string): Promise<void> {
    this.store.deleteMemory(this.current, memoryId)
    await this.saveNow()
    this.notify()
  }

  updateDraft(draft: string): void {
    this.current.draftInput = draft
    this.scheduleSave()
  }

  private stopStream(): void {
    this.service.destroy()
    if (this.isLoading && this.activeAssistantId.length > 0) {
      const target = this.store.findMessage(this.current, this.activeAssistantId)
      if (target !== null && target.status === 'streaming') {
        target.status = 'done'
      }
    }
    this.isLoading = false
    this.activeAssistantId = ''
  }

  /** 用户主动中断生成 */
  abort(): void {
    const id = this.activeAssistantId
    this.stopStream()
    this.tts.stop()
    if (id.length > 0) {
      this.runJs(`Chat.finishAssistant(${JSON.stringify(id)}, 0)`)
    }
    this.notify()
    this.scheduleSave()
  }

  // ============ 持久化 ============
  private async persistAndIndex(setActive: boolean): Promise<void> {
    if (this.persistence === null) {
      return
    }
    this.current.updatedAt = Date.now()
    await this.persistence.saveSession(this.current)
    if (setActive) {
      await this.persistence.setActiveSessionId(this.current.id)
    }
    this.sessions = await this.persistence.listSessions()
  }

  async saveNow(): Promise<void> {
    if (this.persistence === null) {
      return
    }
    this.current.updatedAt = Date.now()
    await this.persistence.saveSession(this.current)
  }

  scheduleSave(): void {
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer)
    }
    this.saveTimer = setTimeout(() => {
      this.saveTimer = -1
      this.saveNow()
    }, 500)
  }

  private async refreshSessionsAndSave(): Promise<void> {
    await this.saveNow()
    if (this.persistence !== null) {
      this.sessions = await this.persistence.listSessions()
    }
    this.notify()
  }
}

export const aiChatController = new AIChatController()

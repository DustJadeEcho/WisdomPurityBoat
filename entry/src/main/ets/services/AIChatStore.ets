import type {
  ChatMessageEntity,
  ConversationSession,
  MemoryKind,
  MemorySegment,
  MessageStatus,
  TTSPlaybackState
} from '../common/AIChatTypes'

const RECENT_MESSAGE_LIMIT: number = 8
const COMPRESS_CHAR_LIMIT: number = 6000
const LONG_TERM_TRIGGERS: string[] = ['喜欢', '偏好', '记住', '习惯', '我是', '我叫', '请记住', '不喜欢', '讨厌', '我的']

function randomId(prefix: string): string {
  return `${prefix}_${Date.now()}_${Math.floor(Math.random() * 1000000)}`
}

/**
 * 会话纯函数式辅助：创建/更新消息、记忆抓取与上下文压缩。
 * 直接在传入的 session 上原地修改（渲染由 WebView 显式驱动，不依赖 ArkUI diff）。
 */
export class AIChatStore {
  createEmptySession(title: string = '新对话'): ConversationSession {
    const now = Date.now()
    return {
      id: randomId('session'),
      title,
      draftInput: '',
      messages: [],
      memories: [],
      createdAt: now,
      updatedAt: now
    }
  }

  newMessage(role: 'user' | 'assistant', content: string): ChatMessageEntity {
    const now = Date.now()
    const status: MessageStatus = role === 'assistant' ? 'streaming' : 'done'
    return {
      id: randomId(role),
      role,
      content,
      reasoningText: '',
      reasoningDurationMs: 0,
      reasoningExpanded: true,
      status,
      createdAt: now,
      updatedAt: now,
      ttsState: 'idle'
    }
  }

  findMessage(session: ConversationSession, messageId: string): ChatMessageEntity | null {
    for (let i = 0; i < session.messages.length; i++) {
      if (session.messages[i].id === messageId) {
        return session.messages[i]
      }
    }
    return null
  }

  appendMessage(session: ConversationSession, message: ChatMessageEntity): void {
    session.messages.push(message)
    if (message.role === 'user') {
      this.captureLongTermMemory(session, message.content, [message.id])
      if (session.title === '新对话' || session.title.length === 0) {
        session.title = this.deriveTitle(message.content)
      }
    }
    session.updatedAt = Date.now()
  }

  updateAssistantDelta(session: ConversationSession, messageId: string, delta: string): void {
    const message = this.findMessage(session, messageId)
    if (message === null) {
      return
    }
    message.content += delta
    message.status = 'streaming'
    message.updatedAt = Date.now()
    session.updatedAt = message.updatedAt
  }

  appendReasoning(session: ConversationSession, messageId: string, delta: string): void {
    const message = this.findMessage(session, messageId)
    if (message === null) {
      return
    }
    message.reasoningText += delta
    message.updatedAt = Date.now()
    session.updatedAt = message.updatedAt
  }

  finishAssistantMessage(session: ConversationSession, messageId: string, durationMs: number): void {
    const message = this.findMessage(session, messageId)
    if (message !== null) {
      message.status = 'done'
      message.reasoningDurationMs = durationMs
      message.reasoningExpanded = false
      message.updatedAt = Date.now()
    }
    this.compressContextIfNeeded(session)
    session.updatedAt = Date.now()
  }

  markAssistantError(session: ConversationSession, messageId: string, errorText: string): void {
    const message = this.findMessage(session, messageId)
    if (message === null) {
      return
    }
    if (message.content.length === 0) {
      message.content = errorText
    }
    message.status = 'error'
    message.updatedAt = Date.now()
    session.updatedAt = message.updatedAt
  }

  setMessageTTSState(session: ConversationSession, messageId: string, state: TTSPlaybackState): void {
    for (let i = 0; i < session.messages.length; i++) {
      const message = session.messages[i]
      message.ttsState = message.id === messageId ? state : 'idle'
    }
    session.updatedAt = Date.now()
  }

  resetAllTTSState(session: ConversationSession): void {
    for (let i = 0; i < session.messages.length; i++) {
      session.messages[i].ttsState = 'idle'
    }
  }

  deleteMemory(session: ConversationSession, memoryId: string): void {
    const next: MemorySegment[] = []
    for (let i = 0; i < session.memories.length; i++) {
      if (session.memories[i].id !== memoryId) {
        next.push(session.memories[i])
      }
    }
    session.memories = next
    session.updatedAt = Date.now()
  }

  clearMessages(session: ConversationSession): void {
    session.messages = []
    session.memories = []
    session.draftInput = ''
    session.title = '新对话'
    session.updatedAt = Date.now()
  }

  deriveTitle(content: string): string {
    const cleaned = content.replace(/\s+/g, ' ').trim()
    if (cleaned.length === 0) {
      return '新对话'
    }
    return cleaned.length > 18 ? cleaned.substring(0, 18) + '…' : cleaned
  }

  private compressContextIfNeeded(session: ConversationSession): void {
    let totalChars = 0
    for (let i = 0; i < session.messages.length; i++) {
      totalChars += session.messages[i].content.length + session.messages[i].reasoningText.length
    }
    if (totalChars < COMPRESS_CHAR_LIMIT || session.messages.length <= RECENT_MESSAGE_LIMIT) {
      return
    }

    const oldCount = session.messages.length - RECENT_MESSAGE_LIMIT
    if (oldCount <= 0) {
      return
    }

    const oldMessages: ChatMessageEntity[] = []
    for (let i = 0; i < oldCount; i++) {
      oldMessages.push(session.messages[i])
    }

    let summary = ''
    const sourceIds: string[] = []
    for (let i = 0; i < oldMessages.length; i++) {
      const message = oldMessages[i]
      const prefix = message.role === 'user' ? '用户：' : '助手：'
      summary += prefix + message.content.substring(0, 120)
      if (i < oldMessages.length - 1) {
        summary += '\n'
      }
      sourceIds.push(message.id)
    }

    const memory = this.createMemory('compressed_context', summary, sourceIds)
    const nextMemories: MemorySegment[] = []
    for (let i = 0; i < session.memories.length; i++) {
      if (session.memories[i].kind !== 'compressed_context') {
        nextMemories.push(session.memories[i])
      }
    }
    nextMemories.push(memory)
    session.memories = nextMemories

    const recentMessages: ChatMessageEntity[] = []
    for (let i = oldCount; i < session.messages.length; i++) {
      recentMessages.push(session.messages[i])
    }
    session.messages = recentMessages
  }

  private captureLongTermMemory(session: ConversationSession, content: string, sourceMessageIds: string[]): void {
    let shouldCapture = false
    for (let i = 0; i < LONG_TERM_TRIGGERS.length; i++) {
      if (content.indexOf(LONG_TERM_TRIGGERS[i]) >= 0) {
        shouldCapture = true
        break
      }
    }
    if (!shouldCapture) {
      return
    }

    const summary = content.length > 120 ? content.substring(0, 120) : content
    for (let i = 0; i < session.memories.length; i++) {
      const memory = session.memories[i]
      if (memory.kind === 'long_term' && memory.summary === summary) {
        return
      }
    }
    session.memories.push(this.createMemory('long_term', summary, sourceMessageIds))
  }

  createMemory(kind: MemoryKind, summary: string, sourceMessageIds: string[]): MemorySegment {
    return {
      id: randomId('memory'),
      kind,
      summary,
      sourceMessageIds,
      createdAt: Date.now()
    }
  }
}

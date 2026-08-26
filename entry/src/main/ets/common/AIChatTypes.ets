export type ChatRole = 'system' | 'user' | 'assistant'
export type MessageStatus = 'streaming' | 'done' | 'error'
export type MemoryKind = 'long_term' | 'compressed_context'
export type TTSPlaybackState = 'idle' | 'playing' | 'paused'

export interface MemorySegment {
  id: string
  kind: MemoryKind
  summary: string
  sourceMessageIds: string[]
  createdAt: number
}

export interface ChatMessageEntity {
  id: string
  role: ChatRole
  content: string
  reasoningText: string
  reasoningDurationMs: number
  reasoningExpanded: boolean
  status: MessageStatus
  createdAt: number
  updatedAt: number
  ttsState: TTSPlaybackState
}

export interface ConversationSession {
  id: string
  title: string
  draftInput: string
  messages: ChatMessageEntity[]
  memories: MemorySegment[]
  createdAt: number
  updatedAt: number
}

/** 抽屉里历史会话列表用的轻量元信息 */
export interface SessionMeta {
  id: string
  title: string
  updatedAt: number
  messageCount: number
}

export interface ChatRequestMessage {
  role: ChatRole
  content: string
}

export interface StreamCallbacks {
  onReasoningDelta: (delta: string) => void
  onContentDelta: (delta: string) => void
  onDone: () => void
  onError: (message: string) => void
}

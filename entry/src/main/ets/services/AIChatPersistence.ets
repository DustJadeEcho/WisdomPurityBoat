import relationalStore from '@ohos.data.relationalStore'
import { common } from '@kit.AbilityKit'
import type { ConversationSession, SessionMeta } from '../common/AIChatTypes'

const DB_NAME: string = 'AIChatDB.db'
const TABLE_NAME: string = 'ai_chat_session'
const META_TABLE: string = 'ai_chat_meta'
const ACTIVE_KEY: string = 'active_session_id'

/**
 * 多会话持久化：每个会话一行（payload 存整段 JSON），
 * 另用 meta 表记录「当前激活会话 id」。
 */
export class AIChatPersistence {
  private context: common.Context
  private store: relationalStore.RdbStore | null = null
  private readonly config: relationalStore.StoreConfig = {
    name: DB_NAME,
    securityLevel: relationalStore.SecurityLevel.S1
  }

  constructor(context: common.Context) {
    this.context = context
  }

  private async getStore(): Promise<relationalStore.RdbStore> {
    if (this.store) {
      return this.store
    }
    const store = await relationalStore.getRdbStore(this.context, this.config)
    await store.executeSql(
      `CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
        session_id TEXT PRIMARY KEY,
        title TEXT,
        message_count INTEGER,
        payload TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )`
    )
    await store.executeSql(
      `CREATE TABLE IF NOT EXISTS ${META_TABLE} (
        meta_key TEXT PRIMARY KEY,
        meta_value TEXT
      )`
    )
    // 兼容旧库（旧表只有 session_id/payload/updated_at）
    await this.tryExec(store, `ALTER TABLE ${TABLE_NAME} ADD COLUMN title TEXT`)
    await this.tryExec(store, `ALTER TABLE ${TABLE_NAME} ADD COLUMN message_count INTEGER`)
    this.store = store
    return store
  }

  private async tryExec(store: relationalStore.RdbStore, sql: string): Promise<void> {
    try {
      await store.executeSql(sql)
    } catch (_e) {
      // 列已存在等情况，忽略
    }
  }

  async listSessions(): Promise<SessionMeta[]> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
    predicates.orderByDesc('updated_at')
    const result = await store.query(predicates, ['session_id', 'title', 'message_count', 'updated_at'])
    const metas: SessionMeta[] = []
    try {
      while (result.goToNextRow()) {
        const id = result.getString(result.getColumnIndex('session_id'))
        const titleRaw = result.getString(result.getColumnIndex('title'))
        const count = result.getLong(result.getColumnIndex('message_count'))
        const updatedAt = result.getLong(result.getColumnIndex('updated_at'))
        metas.push({
          id,
          title: titleRaw && titleRaw.length > 0 ? titleRaw : '新对话',
          updatedAt,
          messageCount: count
        })
      }
    } finally {
      result.close()
    }
    return metas
  }

  async loadSession(sessionId: string): Promise<ConversationSession | null> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
    predicates.equalTo('session_id', sessionId)
    const result = await store.query(predicates, ['payload'])
    try {
      if (!result.goToFirstRow()) {
        return null
      }
      const payload = result.getString(result.getColumnIndex('payload'))
      return JSON.parse(payload) as ConversationSession
    } catch (_e) {
      return null
    } finally {
      result.close()
    }
  }

  async saveSession(session: ConversationSession): Promise<void> {
    const store = await this.getStore()
    const valueBucket: relationalStore.ValuesBucket = {
      session_id: session.id,
      title: session.title,
      message_count: session.messages.length,
      payload: JSON.stringify(session),
      updated_at: session.updatedAt
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
    predicates.equalTo('session_id', session.id)
    const updated = await store.update(valueBucket, predicates)
    if (updated === 0) {
      await store.insert(TABLE_NAME, valueBucket)
    }
  }

  async deleteSession(sessionId: string): Promise<void> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME)
    predicates.equalTo('session_id', sessionId)
    await store.delete(predicates)
  }

  async getActiveSessionId(): Promise<string | null> {
    const store = await this.getStore()
    const predicates = new relationalStore.RdbPredicates(META_TABLE)
    predicates.equalTo('meta_key', ACTIVE_KEY)
    const result = await store.query(predicates, ['meta_value'])
    try {
      if (!result.goToFirstRow()) {
        return null
      }
      return result.getString(result.getColumnIndex('meta_value'))
    } catch (_e) {
      return null
    } finally {
      result.close()
    }
  }

  async setActiveSessionId(sessionId: string): Promise<void> {
    const store = await this.getStore()
    const valueBucket: relationalStore.ValuesBucket = {
      meta_key: ACTIVE_KEY,
      meta_value: sessionId
    }
    const predicates = new relationalStore.RdbPredicates(META_TABLE)
    predicates.equalTo('meta_key', ACTIVE_KEY)
    const updated = await store.update(valueBucket, predicates)
    if (updated === 0) {
      await store.insert(META_TABLE, valueBucket)
    }
  }
}

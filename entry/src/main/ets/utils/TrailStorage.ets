/**
 * 小船轨迹存储工具
 * —— 使用 Preferences 持久化轨迹数据
 * —— 支持实时记录、历史查询、轨迹清理
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

/** 轨迹点数据结构 */
export interface TrailPoint {
  lat: number;
  lng: number;
  timestamp: number;  // 毫秒时间戳
  speed: number;      // km/h
}

/** 历史轨迹记录（按日期分组） */
export interface TrailRecord {
  date: string;       // YYYY-MM-DD
  points: TrailPoint[];
}

const PREF_NAME = 'boat_trail_storage';
const KEY_CURRENT_TRAIL = 'current_trail';
const KEY_HISTORY_TRAILS = 'history_trails';
const MAX_CURRENT_POINTS = 500;    // 当前轨迹最多保留 500 点
const MAX_HISTORY_DAYS = 7;        // 历史轨迹保留 7 天

class TrailStorage {
  private static instance: TrailStorage;
  private prefStore: preferences.Preferences | null = null;
  private currentTrail: TrailPoint[] = [];

  private constructor() {}

  public static getInstance(): TrailStorage {
    if (!TrailStorage.instance) {
      TrailStorage.instance = new TrailStorage();
    }
    return TrailStorage.instance;
  }

  /** 初始化（需在 UIAbility 中调用） */
  public async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.prefStore = await preferences.getPreferences(context, PREF_NAME);
      await this.loadCurrentTrail();
      console.info('[TrailStorage] 初始化成功');
    } catch (e) {
      console.error('[TrailStorage] 初始化失败:', e);
    }
  }

  /** 加载当前轨迹 */
  private async loadCurrentTrail(): Promise<void> {
    if (!this.prefStore) return;
    try {
      const json = await this.prefStore.get(KEY_CURRENT_TRAIL, '[]') as string;
      this.currentTrail = JSON.parse(json);
    } catch (e) {
      console.error('[TrailStorage] 加载当前轨迹失败:', e);
      this.currentTrail = [];
    }
  }

  /** 添加轨迹点 */
  public async addPoint(lat: number, lng: number, speed: number): Promise<void> {
    if (!this.prefStore) return;

    const point: TrailPoint = {
      lat,
      lng,
      timestamp: Date.now(),
      speed
    };

    this.currentTrail.push(point);

    // 限制点数
    if (this.currentTrail.length > MAX_CURRENT_POINTS) {
      this.currentTrail.shift();
    }

    try {
      await this.prefStore.put(KEY_CURRENT_TRAIL, JSON.stringify(this.currentTrail));
      await this.prefStore.flush();
    } catch (e) {
      console.error('[TrailStorage] 保存轨迹点失败:', e);
    }
  }

  /** 获取当前轨迹 */
  public getCurrentTrail(): TrailPoint[] {
    return [...this.currentTrail];
  }

  /** 清除当前轨迹 */
  public async clearCurrentTrail(): Promise<void> {
    if (!this.prefStore) return;
    this.currentTrail = [];
    try {
      await this.prefStore.put(KEY_CURRENT_TRAIL, '[]');
      await this.prefStore.flush();
      console.info('[TrailStorage] 当前轨迹已清除');
    } catch (e) {
      console.error('[TrailStorage] 清除轨迹失败:', e);
    }
  }

  /** 归档当前轨迹到历史（按日期） */
  public async archiveCurrentTrail(): Promise<void> {
    if (!this.prefStore || this.currentTrail.length === 0) return;

    try {
      const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
      const historyJson = await this.prefStore.get(KEY_HISTORY_TRAILS, '[]') as string;
      const history: TrailRecord[] = JSON.parse(historyJson);

      // 查找今天的记录
      let todayRecord = history.find(r => r.date === today);
      if (todayRecord) {
        todayRecord.points.push(...this.currentTrail);
      } else {
        history.push({
          date: today,
          points: [...this.currentTrail]
        });
      }

      // 清理过期记录
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - MAX_HISTORY_DAYS);
      const cutoffStr = cutoffDate.toISOString().split('T')[0];
      const filtered = history.filter(r => r.date >= cutoffStr);

      await this.prefStore.put(KEY_HISTORY_TRAILS, JSON.stringify(filtered));
      await this.prefStore.flush();
      await this.clearCurrentTrail();
      console.info('[TrailStorage] 轨迹已归档到历史');
    } catch (e) {
      console.error('[TrailStorage] 归档轨迹失败:', e);
    }
  }

  /** 获取历史轨迹列表（按日期降序） */
  public async getHistoryTrails(): Promise<TrailRecord[]> {
    if (!this.prefStore) return [];
    try {
      const json = await this.prefStore.get(KEY_HISTORY_TRAILS, '[]') as string;
      const history: TrailRecord[] = JSON.parse(json);
      return history.sort((a, b) => b.date.localeCompare(a.date));
    } catch (e) {
      console.error('[TrailStorage] 获取历史轨迹失败:', e);
      return [];
    }
  }

  /** 获取指定日期的轨迹 */
  public async getTrailByDate(date: string): Promise<TrailPoint[]> {
    const history = await this.getHistoryTrails();
    const record = history.find(r => r.date === date);
    return record ? record.points : [];
  }

  /** 清除所有历史轨迹 */
  public async clearAllHistory(): Promise<void> {
    if (!this.prefStore) return;
    try {
      await this.prefStore.put(KEY_HISTORY_TRAILS, '[]');
      await this.prefStore.flush();
      console.info('[TrailStorage] 历史轨迹已清除');
    } catch (e) {
      console.error('[TrailStorage] 清除历史失败:', e);
    }
  }
}

export default TrailStorage;

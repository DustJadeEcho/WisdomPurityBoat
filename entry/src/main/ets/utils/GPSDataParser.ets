/**
 * GPS 数据帧解析器
 *
 * ★ 协议约定（与 MCU 固件 BoatHullGpsDataFrame 保持一致）：
 *   typedef struct {
 *       uint16_t head;           // 0-1   帧头
 *       uint16_t length;         // 2-3   帧长度
 *       uint16_t clientId;       // 4-5   客户端ID
 *       uint16_t serverId;       // 6-7   服务端ID
 *       uint16_t type;           // 8-9   类型（GPS_DATA）
 *       uint16_t utcYear;        // 10-11 UTC年份
 *       uint16_t bjYear;         // 12-13 北京时间年份
 *       uint16_t speedKmhX100;   // 14-15 速度 × 100 (km/h)
 *       int32_t latitude;        // 16-19 纬度 × 1000000
 *       int32_t longitude;       // 20-23 经度 × 1000000
 *       int32_t altitude;        // 24-27 海拔高度 (m)
 *       uint8_t utcMonth;        // 28    UTC月
 *       uint8_t utcDay;          // 29    UTC日
 *       uint8_t utcHour;         // 30    UTC时
 *       uint8_t utcMinute;       // 31    UTC分
 *       uint8_t utcSecond;       // 32    UTC秒
 *       uint8_t bjMonth;         // 33    北京时间月
 *       uint8_t bjDay;           // 34    北京时间日
 *       uint8_t bjHour;          // 35    北京时间时
 *       uint8_t bjMinute;        // 36    北京时间分
 *       uint8_t bjSecond;        // 37    北京时间秒
 *       uint8_t fixQuality;      // 38    定位质量 0=无信号 1=GPS 2=DGPS
 *       uint8_t numSatellites;   // 39    可见卫星数
 *       uint8_t isValid;         // 40    数据有效性
 *       uint8_t ret[19];         // 41-59 保留字段
 *       uint16_t crc16;          // 60-61 CRC校验
 *       uint16_t end;            // 62-63 帧尾
 *   } BoatHullGpsDataFrame;      // 总长度 64 字节
 */
import { GPSData } from '../common/Types';

// ===== 帧内偏移（小端序） =====
const FRAME_HEAD_OFFSET = 0;
const FRAME_TYPE_OFFSET = 8;
const SPEED_OFFSET = 14;
const LATITUDE_OFFSET = 16;
const LONGITUDE_OFFSET = 20;
const ALTITUDE_OFFSET = 24;
const FIX_QUALITY_OFFSET = 38;
const NUM_SATELLITES_OFFSET = 39;
const IS_VALID_OFFSET = 40;
const FRAME_END_OFFSET = 62;

const MIN_GPS_FRAME_LEN = 64;
const EXPECTED_FRAME_HEAD = 0x5A5A;  // BOAT_FRAME_HEAD
const EXPECTED_FRAME_END = 0x6B6B;   // BOAT_FRAME_END
const GPS_DATA_TYPE = 0x0004;        // GPS_DATA 类型值

/**
 * 从 HEX 字符串（空格分隔）中提取 GPS 信息
 * @param hexString  例 "55 AA 40 00 01 00 02 00 03 00 ..."
 * @returns GPSData | null
 */
export function parseGPSData(hexString: string): GPSData | null {
  const cleaned = hexString.trim().toUpperCase();
  if (!cleaned) return null;

  const tokens = cleaned.split(/\s+/);
  if (tokens.length < MIN_GPS_FRAME_LEN) {
    console.warn('[GPSParser] 帧长度不足:', tokens.length, '< 64');
    return null;
  }

  // 转换为字节数组
  const buf = new Uint8Array(MIN_GPS_FRAME_LEN);
  for (let i = 0; i < MIN_GPS_FRAME_LEN; i++) {
    if (!/^[0-9A-F]{2}$/.test(tokens[i])) {
      console.warn('[GPSParser] 非法字节:', tokens[i]);
      return null;
    }
    buf[i] = parseInt(tokens[i], 16);
  }

  const view = new DataView(buf.buffer);

  try {
    // 校验帧头和帧尾
    const frameHead = view.getUint16(FRAME_HEAD_OFFSET, true);
    const frameEnd = view.getUint16(FRAME_END_OFFSET, true);

    if (frameHead !== EXPECTED_FRAME_HEAD) {
      console.warn('[GPSParser] 帧头错误: 0x' + frameHead.toString(16).toUpperCase() + ' (期望 0x5A5A)');
      return null;
    }
    if (frameEnd !== EXPECTED_FRAME_END) {
      console.warn('[GPSParser] 帧尾错误: 0x' + frameEnd.toString(16).toUpperCase() + ' (期望 0x6B6B)');
      return null;
    }

    // 校验类型
    const frameType = view.getUint16(FRAME_TYPE_OFFSET, true);
    if (frameType !== GPS_DATA_TYPE) {
      console.info('[GPSParser] 非GPS帧，类型: 0x' + frameType.toString(16).toUpperCase());
      return null;
    }

    // 解析 GPS 字段
    const rawLat = view.getInt32(LATITUDE_OFFSET, true);
    const rawLng = view.getInt32(LONGITUDE_OFFSET, true);
    const rawSpeed = view.getUint16(SPEED_OFFSET, true);
    const fixQuality = buf[FIX_QUALITY_OFFSET];
    const numSatellites = buf[NUM_SATELLITES_OFFSET];
    const isValid = buf[IS_VALID_OFFSET];

    const latitude = rawLat / 1_000_000;
    const longitude = rawLng / 1_000_000;
    const speed = rawSpeed / 100;

    // 有效性校验
    const valid = isValid > 0
      && fixQuality > 0
      && latitude >= -90 && latitude <= 90
      && longitude >= -180 && longitude <= 180
      && !(latitude === 0 && longitude === 0);

    console.info('[GPSParser] 解析成功:', {
      lat: latitude.toFixed(6),
      lng: longitude.toFixed(6),
      speed: speed.toFixed(2),
      fix: fixQuality,
      sat: numSatellites,
      valid
    });

    return {
      latitude,
      longitude,
      fixStatus: fixQuality,
      satellites: numSatellites,
      speed,
      isValid: valid
    };
  } catch (e) {
    console.error('[GPSParser] 解析异常:', e);
    return null;
  }
}

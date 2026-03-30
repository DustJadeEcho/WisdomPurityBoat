/**
 * 帧构建 / CRC 校验 / HEX 工具函数
 */

const CRC16_POLYNOMIAL = 0x1021;
const FRAME_HEADER = 0x5A5A;
const FRAME_LENGTH = 16;
const COMMAND_TYPE = 0x00000005;
const FRAME_END = 0x6B6B;

/**
 * CRC16 校验和（CCITT-FALSE）
 */
export function crc16Sum(data: Uint8Array): number {
  if (!data || data.length === 0) {
    throw new Error('Invalid input: data must be a non-empty Uint8Array');
  }
  let crc = 0xFFFF;
  for (const byte of data) {
    crc ^= (byte << 8);
    for (let j = 0; j < 8; j++) {
      const msbSet = (crc & 0x8000) !== 0;
      crc = (crc << 1) & 0xFFFF;
      if (msbSet) {
        crc ^= CRC16_POLYNOMIAL;
      }
    }
  }
  return crc;
}

/**
 * 创建小船方向控制数据帧
 * @param direction 方向位掩码（0x08前进/0x10后退/0x03左转/0x04右转）
 */
export function createBoatCtrlFrame(direction: number): ArrayBuffer {
  const buffer = new ArrayBuffer(FRAME_LENGTH);
  const view = new DataView(buffer);

  for (let i = 0; i < FRAME_LENGTH; i++) {
    view.setUint8(i, 0);
  }

  let offset = 0;
  view.setUint16(offset, FRAME_HEADER, true);  offset += 2;
  view.setUint16(offset, FRAME_LENGTH, true);  offset += 2;
  view.setUint32(offset, COMMAND_TYPE, true);   offset += 4;
  view.setUint32(offset, direction, true);      offset += 4;

  const crcData = new Uint8Array(buffer, 0, FRAME_LENGTH - 4);
  const crc = crc16Sum(crcData);

  view.setUint16(offset, crc, true);  offset += 2;
  view.setUint16(offset, FRAME_END, true);

  return buffer;
}

/**
 * ArrayBuffer → 空格分隔的大写 HEX 字符串
 * 例：[0x5A, 0x5A] → "5A 5A"
 */
export function arrayBufferToHexString(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  return Array.from(bytes)
    .map(b => b.toString(16).padStart(2, '0').toUpperCase())
    .join(' ');
}
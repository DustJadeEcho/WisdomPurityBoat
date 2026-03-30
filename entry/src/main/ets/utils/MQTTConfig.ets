/**
 * MQTT 连接配置 & 单例实例
 * ——导入此文件即自动建立 MQTT 连接
 */
import { MQTTClient, MQTTOptionsType } from './MQTTClient';

const MQTTOption: MQTTOptionsType = {
  url: 'mqtt://124.70.15.127:1883',
  clientId: '/qhmu/lly/harmonyos/01',
  userName: 'lly',
  password: 'qhmully123',
  pubTopicName: '/qhmu/lly/hsetting',
  subTopicName: '/qhmu/lly/mcu',
  qos: 0
};

/** 全局唯一 MQTT 客户端实例 */
export const MQTTInstance: MQTTClient = MQTTClient.getInstance(MQTTOption);
import {
  MqttAsync,
  MqttClient,
  MqttMessage,
  MqttQos,
  MqttResponse,
  MqttSubscribeOptions,
} from '@ohos/mqtt';
import emitter from '@ohos.events.emitter';

const EVENTID = 1001;
const GPS_EVENTID = 1002;

const MEASURED_DATA_TYPE = 0x0001;
const GPS_DATA_TYPE = 0x0004;

interface MQTTOptionsType {
  url?: string;
  clientId?: string;
  userName?: string;
  password?: string;
  pubTopicName?: string;
  subTopicName?: string;
  gubTopicName?: string;
  qos?: MqttQos;
}

class MQTTClient {
  private static instance: MQTTClient;
  private static latestWaterMessage: string = '';
  private mqttClient: MqttClient | null = null;
  private url: string = '';
  private userName: string = '';
  private password: string = '';
  private clientId: string = '';
  private pubTopicName: string = '';
  private subTopicName: string = '';
  private gubTopicName: string = '';
  private qos: MqttQos = 0;

  constructor(mqttOptions: MQTTOptionsType) {
    mqttOptions.url !== undefined && (this.url = mqttOptions.url);
    mqttOptions.userName !== undefined && (this.userName = mqttOptions.userName);
    mqttOptions.password !== undefined && (this.password = mqttOptions.password);
    mqttOptions.clientId !== undefined && (this.clientId = mqttOptions.clientId);
    mqttOptions.pubTopicName !== undefined && (this.pubTopicName = mqttOptions.pubTopicName);
    mqttOptions.subTopicName !== undefined && (this.subTopicName = mqttOptions.subTopicName);
    mqttOptions.gubTopicName !== undefined && (this.gubTopicName = mqttOptions.gubTopicName);
    mqttOptions.qos !== undefined && (this.qos = mqttOptions.qos);
    this.init();
  }

  public static getInstance(mqttOptions: MQTTOptionsType): MQTTClient {
    if (!MQTTClient.instance) {
      MQTTClient.instance = new MQTTClient(mqttOptions);
    }
    return MQTTClient.instance;
  }

  public static getLatestWaterMessage(): string {
    return MQTTClient.latestWaterMessage;
  }

  async init(): Promise<void> {
    console.info(`MQTT Server URL: ${this.url}`);
    console.info(`UserName: ${this.userName}`);
    console.info(`Client ID: ${this.clientId}`);
    console.info(`Publish Topic: ${this.pubTopicName}`);
    console.info(`Water Subscribe Topic: ${this.subTopicName}`);
    console.info(`GPS Subscribe Topic: ${this.gubTopicName}`);
    this.createMqttClient();
    await this.connectMqtt();
    await this.subscribe();
    this.messageArrived();
  }

  public createMqttClient(): void {
    this.mqttClient = MqttAsync.createMqtt({
      url: this.url,
      clientId: this.clientId,
      persistenceType: 1
    });
  }

  public async connectMqtt(): Promise<void> {
    if (!this.mqttClient) {
      return;
    }
    await this.mqttClient.connect({
      userName: this.userName,
      password: this.password,
      connectTimeout: 30,
      automaticReconnect: true,
      MQTTVersion: 0,
    }).then((res: MqttResponse) => {
      console.info('MQTT connect success: ' + JSON.stringify(res.message));
    }).catch((err: Error) => {
      console.error('MQTT connect failed: ' + JSON.stringify(err));
    });
  }

  public async subscribe(): Promise<void> {
    if (!this.mqttClient) {
      return;
    }

    const topics: string[] = [];
    if (this.subTopicName) {
      topics.push(this.subTopicName);
    }
    if (this.gubTopicName && this.gubTopicName !== this.subTopicName) {
      topics.push(this.gubTopicName);
    }
    if (topics.length === 0) {
      console.error('MQTT subscribe topic is empty');
      return;
    }

    const subscribeOptions: MqttSubscribeOptions[] = topics.map((topic: string): MqttSubscribeOptions => {
      return {
        topic,
        qos: this.qos
      };
    });

    await this.mqttClient.subscribeMany(subscribeOptions).then((res: MqttResponse) => {
      console.info(`MQTT subscribe success: ${JSON.stringify(topics)}, ${JSON.stringify(res.message)}`);
    }).catch((err: Error) => {
      console.error('MQTT subscribe failed: ' + JSON.stringify(err));
    });
  }

  public messageArrived(): void {
    if (!this.mqttClient) {
      return;
    }

    this.mqttClient.messageArrived((err: Error, data: MqttMessage) => {
      if (err) {
        console.error('MQTT receive failed: ' + JSON.stringify(err));
        return;
      }

      const raw = new Uint8Array(data.payloadBinary);
      const hexStr = Array.from(raw).map((b: number): string => b.toString(16).padStart(2, '0')).join(' ');
      const frameType = this.getFrameType(raw);
      console.info(`MQTT receive topic=${data.topic}, type=0x${frameType.toString(16)}, hex=${hexStr}`);

      if (data.topic === this.gubTopicName || frameType === GPS_DATA_TYPE) {
        this.emitMessage(GPS_EVENTID, hexStr);
        return;
      }
      if (data.topic === this.subTopicName || frameType === MEASURED_DATA_TYPE) {
        MQTTClient.latestWaterMessage = hexStr;
        this.emitMessage(EVENTID, hexStr);
        return;
      }

      console.warn('MQTT received message from unknown topic: ' + data.topic);
    });
  }

  public async pushMessage(hexString: string, pic: string = this.pubTopicName, qo: MqttQos = this.qos): Promise<void> {
    if (!this.mqttClient) {
      console.error('MQTT client not initialized');
      return;
    }

    await this.mqttClient.publish({
      topic: pic,
      qos: qo,
      payload: hexString
    }).then((data: MqttResponse) => {
      console.info(`MQTT message sent to ${pic}: ${JSON.stringify(data)}`);
      console.debug('Sent hex data: ' + hexString);
    }).catch((err: Error) => {
      console.error('MQTT publish failed: ' + JSON.stringify(err));
    });
  }

  public async destroy(): Promise<void> {
    if (!this.mqttClient) {
      return;
    }
    await this.mqttClient.destroy().then((data: boolean) => {
      if (data) {
        console.info('MQTT instance destroyed');
        emitter.off(EVENTID);
        emitter.off(GPS_EVENTID);
      } else {
        console.error('MQTT instance destroy failed');
      }
    });
  }

  private getFrameType(raw: Uint8Array): number {
    if (raw.length < 10) {
      return -1;
    }
    return raw[8] | (raw[9] << 8);
  }

  private emitMessage(eventId: number, content: string): void {
    emitter.emit({
      eventId,
      priority: emitter.EventPriority.LOW
    }, {
      data: { content }
    });
  }
}

export {
  MQTTClient,
  EVENTID,
  GPS_EVENTID,
  MQTTOptionsType
};

import type { BaseClient } from '../types.js';

export class ChannelsResource {
  constructor(private readonly client: BaseClient) {}

  sendWhatsapp(data: Record<string, unknown>) {
    return this.client.request('POST', '/channels/whatsapp/send', data);
  }

  sendPush(data: Record<string, unknown>) {
    return this.client.request('POST', '/channels/push/send', data);
  }
}

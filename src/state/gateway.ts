import { AppConfig } from '@/core/config';
import { DemoGateway } from '@/core/demoGateway';
import { AppGateway, RemoteGateway } from '@/core/gateway';

/** The one gateway the app talks to: the server, or in-memory demo data. */
export const gateway: AppGateway = AppConfig.useDemoData ? new DemoGateway() : new RemoteGateway();

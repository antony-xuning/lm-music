/**
 * 后台播放长时任务：audioPlayback 类型，与 AVSession 同生命周期启停。
 * 失败只记录日志并降级，绝不阻塞应用内播放。
 */
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppConstants } from '../common/Constants';
import { AppContextHolder } from '../common/AppContextHolder';
import { Logger } from '../common/Logger';

const SCOPE: string = 'BackgroundPlayback';
const REQUEST_CODE: number = 2001;

export class BackgroundPlaybackService {
  private running: boolean = false;
  private starting: boolean = false;

  /** 是否已成功申请长时任务。 */
  get active(): boolean {
    return this.running;
  }

  /** 申请 audioPlayback 长时任务（幂等）。 */
  async start(): Promise<void> {
    if (this.running || this.starting) {
      return;
    }
    const context = AppContextHolder.context;
    if (context === null) {
      Logger.warn(SCOPE, 'context unavailable, skip background task');
      return;
    }
    this.starting = true;
    try {
      const agent: WantAgent | null = await this.buildWantAgent();
      if (agent === null) {
        Logger.warn(SCOPE, 'want agent unavailable, skip background task');
        return;
      }
      await backgroundTaskManager.startBackgroundRunning(context, ['audioPlayback'], agent);
      this.running = true;
      Logger.info(SCOPE, 'background audio playback started');
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `startBackgroundRunning failed: ${err.code}`);
    } finally {
      this.starting = false;
    }
  }

  /** 取消长时任务（幂等）。 */
  async stop(): Promise<void> {
    if (!this.running) {
      return;
    }
    this.running = false;
    const context = AppContextHolder.context;
    if (context === null) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(context);
      Logger.info(SCOPE, 'background audio playback stopped');
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `stopBackgroundRunning failed: ${err.code}`);
    }
  }

  /** 点击通知回到应用。 */
  private async buildWantAgent(): Promise<WantAgent | null> {
    const info: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: AppConstants.BUNDLE_NAME,
          abilityName: 'EntryAbility'
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: REQUEST_CODE,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    try {
      return await wantAgent.getWantAgent(info);
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `getWantAgent failed: ${err.code}`);
      return null;
    }
  }
}

export const backgroundPlaybackService: BackgroundPlaybackService = new BackgroundPlaybackService();

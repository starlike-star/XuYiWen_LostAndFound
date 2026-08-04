import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ContentSnapshot } from '../models/AppModels';
import { joinContentChunks, splitContentText } from './ContentCodec';

const DOMAIN: number = 0x0000;
const TAG: string = 'ContentRepository';
const CONTENT_PREFIX: string = 'content_';
const COUNT_SUFFIX: string = '_chunk_count';
const CHUNK_SUFFIX: string = '_chunk_';

export class ContentRepository {
  private data?: preferences.Preferences;

  async initialize(context: common.Context): Promise<void> {
    try {
      this.data = await preferences.getPreferences(context, { name: 'campus_lost_found_content' });
    } catch (error) {
      this.data = undefined;
      const businessError: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Initialize failed. Code: %{public}d, message: %{public}s',
        businessError.code, businessError.message);
      throw new Error(businessError.message);
    }
  }

  load(accountId: string): ContentSnapshot | undefined {
    if (this.data === undefined) {
      hilog.error(DOMAIN, TAG, 'Load failed: repository is not initialized.');
      return undefined;
    }
    try {
      const baseKey: string = `${CONTENT_PREFIX}${accountId}`;
      const countValue: preferences.ValueType = this.data.getSync(`${baseKey}${COUNT_SUFFIX}`, 0);
      const chunkCount: number = Number(`${countValue}`);
      let text: string = '';
      if (chunkCount > 0) {
        const chunks: string[] = [];
        for (let index: number = 0; index < chunkCount; index++) {
          chunks.push(`${this.data.getSync(`${baseKey}${CHUNK_SUFFIX}${index}`, '')}`);
        }
        text = joinContentChunks(chunks);
      } else {
        text = `${this.data.getSync(baseKey, '')}`;
      }
      return text.length === 0 ? undefined : JSON.parse(text) as ContentSnapshot;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Load content failed: %{public}s', JSON.stringify(error));
      return undefined;
    }
  }

  async save(accountId: string, snapshot: ContentSnapshot): Promise<void> {
    if (this.data === undefined) {
      hilog.error(DOMAIN, TAG, 'Save failed: repository is not initialized.');
      throw new Error('ContentRepository is not initialized');
    }
    try {
      const baseKey: string = `${CONTENT_PREFIX}${accountId}`;
      const oldCountValue: preferences.ValueType = this.data.getSync(`${baseKey}${COUNT_SUFFIX}`, 0);
      const oldChunkCount: number = Number(`${oldCountValue}`);
      const chunks: string[] = splitContentText(JSON.stringify(snapshot));
      for (let index: number = 0; index < chunks.length; index++) {
        await this.data.put(`${baseKey}${CHUNK_SUFFIX}${index}`, chunks[index]);
      }
      for (let index: number = chunks.length; index < oldChunkCount; index++) {
        await this.data.delete(`${baseKey}${CHUNK_SUFFIX}${index}`);
      }
      await this.data.put(`${baseKey}${COUNT_SUFFIX}`, chunks.length);
      await this.data.delete(baseKey);
      await this.data.flush();
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Save content failed. Code: %{public}d, message: %{public}s',
        businessError.code, businessError.message);
      throw new Error(businessError.message);
    }
  }
}

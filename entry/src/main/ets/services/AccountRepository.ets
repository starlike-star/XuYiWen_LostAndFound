import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AuthSession, UserAccount } from '../models/AccountModels';
import { joinContentChunks, splitContentText } from './ContentCodec';

const DOMAIN: number = 0x0000;
const TAG: string = 'AccountRepository';
const ACCOUNTS_KEY: string = 'accounts';
const SESSION_KEY: string = 'session';
const COUNT_SUFFIX: string = '_chunk_count';
const CHUNK_SUFFIX: string = '_chunk_';

export class AccountRepository {
  private data?: preferences.Preferences;

  async initialize(context: common.Context): Promise<void> {
    try {
      this.data = await preferences.getPreferences(context, { name: 'campus_lost_found_accounts' });
    } catch (error) {
      this.data = undefined;
      const businessError: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Initialize failed. Code: %{public}d, message: %{public}s',
        businessError.code, businessError.message);
      throw new Error(businessError.message);
    }
  }

  loadAccounts(): UserAccount[] {
    if (this.data === undefined) {
      return [];
    }
    try {
      const countValue: preferences.ValueType = this.data.getSync(`${ACCOUNTS_KEY}${COUNT_SUFFIX}`, 0);
      const chunkCount: number = Number(`${countValue}`);
      let text: string = '';
      if (chunkCount > 0) {
        const chunks: string[] = [];
        for (let index: number = 0; index < chunkCount; index++) {
          chunks.push(`${this.data.getSync(`${ACCOUNTS_KEY}${CHUNK_SUFFIX}${index}`, '')}`);
        }
        text = joinContentChunks(chunks);
      } else {
        text = `${this.data.getSync(ACCOUNTS_KEY, '')}`;
      }
      if (text.length === 0) {
        return [];
      }
      return JSON.parse(text) as UserAccount[];
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Load accounts failed: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  loadSession(): AuthSession | undefined {
    if (this.data === undefined) {
      return undefined;
    }
    try {
      const value: preferences.ValueType = this.data.getSync(SESSION_KEY, '');
      const text: string = `${value}`;
      if (text.length === 0) {
        return undefined;
      }
      return JSON.parse(text) as AuthSession;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Load session failed: %{public}s', JSON.stringify(error));
      return undefined;
    }
  }

  async saveAccounts(accounts: UserAccount[]): Promise<void> {
    if (this.data === undefined) {
      hilog.error(DOMAIN, TAG, 'Save accounts failed: repository is not initialized.');
      throw new Error('AccountRepository is not initialized');
    }
    try {
      const oldCountValue: preferences.ValueType = this.data.getSync(`${ACCOUNTS_KEY}${COUNT_SUFFIX}`, 0);
      const oldChunkCount: number = Number(`${oldCountValue}`);
      const chunks: string[] = splitContentText(JSON.stringify(accounts));
      for (let index: number = 0; index < chunks.length; index++) {
        await this.data.put(`${ACCOUNTS_KEY}${CHUNK_SUFFIX}${index}`, chunks[index]);
      }
      for (let index: number = chunks.length; index < oldChunkCount; index++) {
        await this.data.delete(`${ACCOUNTS_KEY}${CHUNK_SUFFIX}${index}`);
      }
      await this.data.put(`${ACCOUNTS_KEY}${COUNT_SUFFIX}`, chunks.length);
      await this.data.delete(ACCOUNTS_KEY);
      await this.data.flush();
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Save accounts failed. Code: %{public}d, message: %{public}s',
        businessError.code, businessError.message);
      throw new Error(businessError.message);
    }
  }

  async saveSession(session?: AuthSession): Promise<void> {
    if (this.data === undefined) {
      hilog.error(DOMAIN, TAG, 'Save session failed: repository is not initialized.');
      throw new Error('AccountRepository is not initialized');
    }
    try {
      if (session === undefined) {
        await this.data.delete(SESSION_KEY);
      } else {
        await this.data.put(SESSION_KEY, JSON.stringify(session));
      }
      await this.data.flush();
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      hilog.error(DOMAIN, TAG, 'Save session failed. Code: %{public}d, message: %{public}s',
        businessError.code, businessError.message);
      throw new Error(businessError.message);
    }
  }
}

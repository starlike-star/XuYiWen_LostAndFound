import { common } from '@kit.AbilityKit';
import { request } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { RemoteImage } from './ApiTypes';

export class FileApiRepository {
  private baseUrl: string = 'http://172.22.9.223:3000';

  async uploadImages(context: common.UIAbilityContext, token: string, uris: string[]): Promise<RemoteImage[]> {
    const result: RemoteImage[] = [];
    for (const uri of uris) {
      result.push(await this.uploadOne(context, token, uri));
    }
    return result;
  }

  private async uploadOne(context: common.UIAbilityContext, token: string, uri: string): Promise<RemoteImage> {
    const cacheName: string = `lostfound-upload-${Date.now()}-${Math.floor(Math.random() * 100000)}.jpg`;
    const cachePath: string = `${context.cacheDir}/${cacheName}`;
    try {
      // PhotoViewPicker grants temporary access to the selected media URI. Read
      // it through FileIO, then write a private cache copy before uploading.
      await this.materializeUserFile(uri, cachePath);
      return await this.uploadCacheFile(context, token, cacheName);
    } finally {
      fileIo.unlink(cachePath).catch(() => {});
    }
  }

  private async materializeUserFile(sourceUri: string, destinationPath: string): Promise<void> {
    const sourceFile: fileIo.File = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
    let destinationFile: fileIo.File | undefined = undefined;
    try {
      const sourceStat: fileIo.Stat = await fileIo.stat(sourceFile.fd);
      const totalSize: number = Number(sourceStat.size);
      if (totalSize <= 0 || totalSize > 10 * 1024 * 1024) {
        throw new Error('图片大小必须在 1B 到 10MB 之间');
      }
      const bytes = new ArrayBuffer(totalSize);
      const target = new Uint8Array(bytes);
      let offset: number = 0;
      while (offset < totalSize) {
        const chunk = new ArrayBuffer(totalSize - offset);
        const count: number = await fileIo.read(sourceFile.fd, chunk);
        if (count <= 0) break;
        target.set(new Uint8Array(chunk, 0, count), offset);
        offset += count;
      }
      if (offset !== totalSize) {
        throw new Error('无法完整读取所选图片');
      }
      destinationFile = await fileIo.open(destinationPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      await fileIo.write(destinationFile.fd, bytes);
    } finally {
      await fileIo.close(sourceFile);
      if (destinationFile !== undefined) await fileIo.close(destinationFile);
    }
  }

  private async uploadCacheFile(context: common.UIAbilityContext, token: string, cacheName: string): Promise<RemoteImage> {
    return new Promise<RemoteImage>((resolve, reject) => {
      const config: request.agent.Config = {
        action: request.agent.Action.UPLOAD,
        url: `${this.baseUrl}/api/v1/files/images`,
        mode: request.agent.Mode.FOREGROUND,
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
        data: [{
          name: 'file',
          value: [{ path: cacheName, filename: 'image.jpg', contentType: 'image/jpeg' }]
        }]
      };
      let settled: boolean = false;
      let responseHeaders: Map<string, Array<string>> | undefined = undefined;
      const fail = (message: string): void => {
        if (settled) return;
        settled = true;
        reject(new Error(message));
      };
      const headerValue = (name: string): string => {
        if (responseHeaders === undefined) return '';
        let result: string = '';
        responseHeaders.forEach((values: Array<string>, key: string) => {
          if (key.toLowerCase() === name.toLowerCase() && values.length > 0) result = values[0];
        });
        return result;
      };
      request.agent.create(context, config).then((task: request.agent.Task) => {
        task.on('response', (response: request.agent.HttpResponse) => {
          responseHeaders = response.headers;
          if (response.statusCode < 200 || response.statusCode >= 300) {
            fail(`图片服务返回 HTTP ${response.statusCode}`);
          }
        });
        task.on('completed', (_progress: request.agent.Progress) => {
          const id: string = headerValue('X-Image-Id');
          if (id.length === 0) {
            fail('图片服务未返回图片标识');
            return;
          }
          if (settled) return;
          settled = true;
          resolve({ id: id,
            publicUrl: headerValue('X-Image-Url'),
            contentType: headerValue('X-Image-Content-Type') || 'image/jpeg',
            sizeBytes: Number(headerValue('X-Image-Size') || '0') });
        });
        task.on('failed', (_progress: request.agent.Progress) => {
          fail('图片上传失败');
        });
        task.start().catch((error: Object) => fail(JSON.stringify(error)));
      }).catch((error: Object) => fail(JSON.stringify(error)));
    });
  }
}

export function loadEnvironment(source) {
  const databaseUrl = source.DATABASE_URL;
  if (typeof databaseUrl !== 'string' || databaseUrl.length === 0) {
    throw new Error('DATABASE_URL is required');
  }

  const port = Number(source.PORT ?? 3000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be a valid TCP port');
  }

  const jwtSecret = source.APP_JWT_SECRET;
  if (typeof jwtSecret !== 'string' || jwtSecret.length < 32) {
    throw new Error('APP_JWT_SECRET must contain at least 32 characters');
  }
  const storageMode = source.APP_STORAGE_MODE ?? 'local';
  if (!['local', 'remote'].includes(storageMode)) throw new Error('APP_STORAGE_MODE must be local or remote');
  if (storageMode === 'remote' && (!source.APP_STORAGE_BASE_URL || !source.APP_STORAGE_SHARED_SECRET)) {
    throw new Error('remote storage requires APP_STORAGE_BASE_URL and APP_STORAGE_SHARED_SECRET');
  }
  return {
    databaseUrl,
    port,
    jwtSecret,
    storageMode,
    storageRoot: source.APP_STORAGE_ROOT ?? './storage/uploads',
    publicUploadPrefix: source.APP_PUBLIC_UPLOAD_PREFIX ?? '/uploads',
    storageBaseUrl: source.APP_STORAGE_BASE_URL,
    storageSharedSecret: source.APP_STORAGE_SHARED_SECRET,
    publicBaseUrl: source.APP_PUBLIC_BASE_URL ?? 'http://127.0.0.1:3000'
  };
}

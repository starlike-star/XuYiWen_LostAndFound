import { createApp } from './app.js';
import { createDatabase } from './db/knex.js';
import { loadEnvironment } from './config/env.js';
import { LocalStorageService } from './files/local-storage.service.js';
import { RemoteStorageService } from './files/remote-storage.service.js';

const environment = loadEnvironment(process.env);
const database = createDatabase(environment.databaseUrl);
const storage = environment.storageMode === 'remote'
  ? new RemoteStorageService(environment.storageBaseUrl, environment.storageSharedSecret, environment.publicBaseUrl)
  : new LocalStorageService(environment.storageRoot, environment.publicUploadPrefix);
const app = createApp({ db: database, storage, jwtSecret: environment.jwtSecret });

app.listen(environment.port, () => {
  console.log(`LostFound API listening on port ${environment.port}`);
});

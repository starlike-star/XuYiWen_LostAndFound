import { http } from '@kit.NetworkKit';
import { ApiEnvelope, PasswordLoginData, PasswordLoginRequest } from './ApiTypes';

const API_BASE_URL: string = 'http://172.22.9.223:3000';

export class ApiClient {
  private baseUrl: string;

  constructor(baseUrl: string = API_BASE_URL) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  async request<T>(method: http.RequestMethod, path: string, body?: object,
    token: string = ''): Promise<ApiEnvelope<T>> {
    const request: http.HttpRequest = http.createHttp();
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (token.length > 0) {
      headers['Authorization'] = 'Bearer ' + token;
    }
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      expectDataType: http.HttpDataType.STRING
    };
    if (body !== undefined) {
      options.extraData = JSON.stringify(body);
    }
    try {
      const response: http.HttpResponse = await request.request(this.baseUrl + path, options);
      const envelope: ApiEnvelope<T> = JSON.parse(String(response.result)) as ApiEnvelope<T>;
      if (response.responseCode >= 400) {
        throw new Error(envelope.message);
      }
      return envelope;
    } finally {
      request.destroy();
    }
  }

  async login(account: string, password: string): Promise<PasswordLoginData> {
    const body: PasswordLoginRequest = { account: account.trim(), password: password };
    const response: ApiEnvelope<PasswordLoginData> = await this.request<PasswordLoginData>(
      http.RequestMethod.POST, '/api/v1/auth/login/password', body);
    return response.data;
  }
}

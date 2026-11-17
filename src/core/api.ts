import { AppConfig } from './config';
import { AppException } from './errors';

type Json = Record<string, any>;
type Query = Record<string, string | number | boolean | null | undefined>;

const CONNECT_AND_RECEIVE_TIMEOUT_MS = 20_000; // dio: 8 s connect + 12 s receive

/** The HTTP client: base `${API}/v1`, bearer auth, one refresh-and-retry on 401. */
export class ApiClient {
  private token: string | null = null;
  private refreshHandler: (() => Promise<string | null>) | null = null;
  readonly base: string;

  constructor(baseUrl: string) {
    this.base = baseUrl.replace(/\/+$/, '');
  }

  setRefreshHandler(handler: () => Promise<string | null>) {
    this.refreshHandler = handler;
  }

  authorize(token: string | null) {
    this.token = token;
  }

  get = (path: string, query?: Query) => this.request('GET', path, { query });
  post = (path: string, data?: unknown, opts: { idempotencyKey?: string; allowRefresh?: boolean } = {}) =>
    this.request('POST', path, { data, ...opts });
  put = (path: string, data?: unknown) => this.request('PUT', path, { data });
  patch = (path: string, data?: unknown) => this.request('PATCH', path, { data });
  delete = (path: string, query?: Query) => this.request('DELETE', path, { query });

  /** A short-lived, single-use ticket for WebSocket auth. */
  async createRealtimeTicket(): Promise<string> {
    const res = await this.post('/realtime/ticket');
    if (typeof res.ticket !== 'string' || !res.ticket) {
      throw new Error('The server returned an invalid realtime ticket.');
    }
    return res.ticket;
  }

  /** http -> ws locally, https -> wss in production. */
  realtimeUrl(ticket: string): string {
    const url = new URL(this.base);
    url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
    url.pathname = `${url.pathname.replace(/\/+$/, '')}/v1/realtime`;
    url.search = `?ticket=${encodeURIComponent(ticket)}`;
    return url.toString();
  }

  private async request(
    method: string,
    path: string,
    opts: { query?: Query; data?: unknown; idempotencyKey?: string; allowRefresh?: boolean },
  ): Promise<Json> {
    const allowRefresh = opts.allowRefresh ?? true;
    let url = `${this.base}/v1${path}`;
    if (opts.query) {
      const params = Object.entries(opts.query)
        .filter(([, v]) => v !== undefined && v !== null)
        .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`);
      if (params.length) url += `?${params.join('&')}`;
    }
    const headers: Record<string, string> = { Accept: 'application/json' };
    if (this.token) headers.Authorization = `Bearer ${this.token}`;
    if (opts.idempotencyKey) headers['Idempotency-Key'] = opts.idempotencyKey;
    if (opts.data !== undefined) headers['Content-Type'] = 'application/json';

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), CONNECT_AND_RECEIVE_TIMEOUT_MS);
    let response: Response;
    try {
      response = await fetch(url, {
        method,
        headers,
        body: opts.data === undefined ? undefined : JSON.stringify(opts.data),
        signal: controller.signal,
      });
    } catch {
      throw new AppException('Unable to connect. Please try again.', 'network');
    } finally {
      clearTimeout(timer);
    }

    let body: unknown = null;
    const text = await response.text().catch(() => '');
    if (text) {
      try {
        body = JSON.parse(text);
      } catch {
        body = null;
      }
    }

    if (response.ok) {
      // A 204 (or any reply that is not a JSON object) has nothing to parse.
      return body && typeof body === 'object' && !Array.isArray(body) ? (body as Json) : {};
    }

    if (response.status === 401 && allowRefresh && this.refreshHandler) {
      const token = await this.refreshHandler();
      if (token) {
        this.authorize(token);
        return this.request(method, path, { ...opts, allowRefresh: false });
      }
    }

    let code: string | undefined;
    let message = 'Unable to connect. Please try again.';
    const err = (body as Json | null)?.error;
    if (err && typeof err === 'object') {
      code = typeof err.code === 'string' ? err.code : undefined;
      if (typeof err.message === 'string') message = err.message;
    }
    if (response.status === 401) throw new AppException(message, 'authentication', code);
    if (response.status < 500) throw new AppException(message, 'validation', code);
    throw new AppException(message, 'network', code);
  }
}

export const apiClient = new ApiClient(AppConfig.apiBaseUrl);

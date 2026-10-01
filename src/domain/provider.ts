export interface ProviderMetadata {
  endpoint: string;
  model: string;
}
export function validateProvider(config: ProviderMetadata): string | null {
  try {
    const u = new URL(config.endpoint);
    if (u.username || u.password || u.search || u.hash)
      return 'endpoint 不能包含凭据、查询参数或片段';
    const loopback = ['localhost', '127.0.0.1', '[::1]'].includes(u.hostname);
    if (u.protocol !== 'https:' && !(u.protocol === 'http:' && loopback))
      return '远程服务需要 HTTPS；仅 loopback 允许 HTTP';
    if (!config.model.trim() || config.model.length > 200)
      return '请填写有效 model';
    return null;
  } catch {
    return '请输入有效 endpoint';
  }
}
export interface CredentialStore {
  available: boolean; /* Credential methods will be defined after native security review. */
}
export const unavailableCredentialStore: CredentialStore = { available: false };

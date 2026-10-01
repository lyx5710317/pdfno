import path from 'node:path';
export const appOrigin = 'pdfno://app';
export function allowedRenderer(url, dev = false) {
  try {
    const u = new URL(url);
    return dev
      ? u.origin === 'http://127.0.0.1:5173'
      : u.protocol === 'pdfno:' &&
          u.hostname === 'app' &&
          !u.username &&
          !u.password &&
          !u.port;
  } catch {
    return false;
  }
}
export function resourcePath(url, directory) {
  const u = new URL(url);
  if (!allowedRenderer(url)) throw new Error('INVALID_ORIGIN');
  const relative =
    decodeURIComponent(u.pathname).replace(/^\//, '') || 'index.html';
  const file = path.resolve(directory, relative);
  if (file !== directory && !file.startsWith(directory + path.sep))
    throw new Error('INVALID_PATH');
  return file;
}

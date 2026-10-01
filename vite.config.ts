import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
export default defineConfig(({ command }) => ({
  plugins: [
    react(),
    {
      name: 'dev-csp',
      transformIndexHtml: {
        order: 'pre',
        handler(html) {
          return command === 'serve'
            ? html.replace(
                "script-src 'self'",
                "script-src 'self' 'unsafe-inline'",
              )
            : html;
        },
      },
    },
  ],
  base: './',
  server: { host: '127.0.0.1', port: 5173, strictPort: true },
  test: { include: ['tests/**/*.test.ts'], environment: 'node' },
}));

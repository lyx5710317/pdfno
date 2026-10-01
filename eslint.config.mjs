import js from '@eslint/js';
import tseslint from 'typescript-eslint';
export default tseslint.config(
  {
    ignores: [
      'node_modules/**',
      'dist/**',
      'native/**',
      'test-results/**',
      'playwright-report/**',
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    languageOptions: {
      globals: {
        process: 'readonly',
        console: 'readonly',
        URL: 'readonly',
        fetch: 'readonly',
        setTimeout: 'readonly',
        clearTimeout: 'readonly',
        Buffer: 'readonly',
        Response: 'readonly',
        AbortController: 'readonly',
      },
    },
    rules: { '@typescript-eslint/no-explicit-any': 'error' },
  },
  {
    files: ['**/*.cjs'],
    languageOptions: { globals: { require: 'readonly' } },
    rules: { '@typescript-eslint/no-require-imports': 'off' },
  },
);

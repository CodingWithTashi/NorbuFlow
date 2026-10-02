import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['lib/', 'node_modules/', '*.mjs'] },
  eslint.configs.recommended,
  tseslint.configs.recommended,
  {
    languageOptions: { parserOptions: { projectService: true } },
    rules: {
      // A promise nobody awaits fails silently, and inside a transaction escapes it.
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
    },
  },
);

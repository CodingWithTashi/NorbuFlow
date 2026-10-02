import { defineConfig } from 'vitest/config';

// Run through `npm run test:e2e`, which starts the Auth and Functions
// emulators around it.
export default defineConfig({
  test: {
    include: ['test/e2e/**/*.test.ts'],
    testTimeout: 30_000,
  },
});

import { defineConfig } from "vitest/config";

export default defineConfig({
  // An inline postcss config stops Vite searching upward for one. Without it,
  // it finds the Next.js app's postcss.config.mjs at the repo root and fails on
  // @tailwindcss/postcss, which is not a dependency down here. This SDK ships
  // no CSS, so an empty plugin list costs nothing.
  css: { postcss: { plugins: [] } },
  test: {
    globals: true,
    environment: "node",
    coverage: {
      provider: "v8",
      thresholds: { lines: 80, functions: 80, branches: 80, statements: 80 },
    },
  },
});

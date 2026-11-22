import { defineConfig } from "@playwright/test";
const baseURL = process.env.E2E_BASE_URL || "http://127.0.0.1:3000";

export default defineConfig({
  testDir: "./tests/e2e",
  workers: 1,
  retries: 0,
  forbidOnly: !!process.env.CI,
  use: {
    baseURL,
    browserName: "chromium",
    ...(process.env.E2E_BROWSER_CHANNEL ? {channel:process.env.E2E_BROWSER_CHANNEL} : {}),
    trace: "off",
    screenshot: "off",
    video: "off",
  },
  reporter: "list",
});

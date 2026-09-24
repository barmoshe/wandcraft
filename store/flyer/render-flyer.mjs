// Renders iphone-install.html to wandcraft-iphone-install.png (1080x1920). Uses Playwright
// with an exact viewport: headless Chrome's --window-size leaves the page area short.
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const here = path.dirname(fileURLToPath(import.meta.url));
const browser = await chromium.launch({ args: ['--allow-file-access-from-files'] });
const page = await browser.newPage({ viewport: { width: 540, height: 960 }, deviceScaleFactor: 2 });
await page.goto('file://' + path.join(here, 'iphone-install.html'));
await page.evaluate(() => document.fonts.ready);
await page.waitForTimeout(300);
await page.screenshot({ path: path.join(here, 'wandcraft-iphone-install.png') });
await browser.close();

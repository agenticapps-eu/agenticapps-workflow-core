// render-cheatsheet.mjs — render the self-contained cheatsheet HTML to a full-page PNG.
// Usage: node scripts/render-cheatsheet.mjs <input.html> <output.png>
import { chromium } from 'playwright';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [, , input = 'publish/index.html', output = '_site/cheatsheet.png'] = process.argv;
const url = pathToFileURL(resolve(input)).href;

const browser = await chromium.launch();
const page = await browser.newPage({
  viewport: { width: 960, height: 1400 },
  deviceScaleFactor: 2,
});
await page.goto(url, { waitUntil: 'networkidle' });
await page.screenshot({ path: output, fullPage: true });
await browser.close();
console.log(`rendered ${input} -> ${output}`);

// Render code-native T-63 mockups with Chrome DevTools Protocol; Node 22+.
// One isolated browser, no npm packages, no external assets or running web server.
import { spawn } from 'node:child_process';
import { mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const seconds = Number(process.argv[2] ?? 60);
if (![45, 60, 90].includes(seconds)) throw new Error('Usage: render.sh [45|60|90]');
const out = resolve(here, '../../docs/release/screenshots');
const validation = resolve(here, '../../docs/validation/T-63');
const profile = await mkdtemp(join(tmpdir(), 'nextset-render-'));
const browser = spawn(process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
  '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
  '--no-default-browser-check', '--disable-background-networking',
  '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank',
], { stdio: ['ignore', 'ignore', 'pipe'] });
let socket;
const pending = new Map();
let commandId = 0;
let log = '';
function send(method, params = {}, sessionId) {
  return new Promise((resolve, reject) => {
    const id = ++commandId;
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`Timed out: ${method}`)); }, 20000);
    pending.set(id, { resolve, reject, timer });
    socket.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
  });
}
try {
  const endpoint = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`Chrome did not start: ${log.slice(-1200)}`)), 20000);
    browser.on('error', error => { clearTimeout(timer); reject(error); });
    browser.once('exit', code => { clearTimeout(timer); reject(new Error(`Chrome exited (${code}). ${log.slice(-1200)}`)); });
    browser.stderr.on('data', chunk => {
      log += chunk;
      const match = log.match(/DevTools listening on (ws:\/\/[^\s]+)/);
      if (match) { clearTimeout(timer); resolve(match[1]); }
    });
  });
  socket = new WebSocket(endpoint);
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    const waiter = pending.get(message.id);
    if (!waiter) return;
    clearTimeout(waiter.timer);
    pending.delete(message.id);
    if (message.error) waiter.reject(new Error(message.error.message));
    else waiter.resolve(message.result);
  });
  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
  const page = (method, params) => send(method, params, sessionId);
  await page('Page.enable');
  const results = [];
  async function render(lang, screen, secs, width, height, filename) {
    await page('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false });
    const url = pathToFileURL(join(here, 'ipad.html'));
    url.search = new URLSearchParams({ lang, screen, secs });
    await page('Page.navigate', { url: url.href });
    let state;
    for (let attempt = 0; attempt < 100; attempt++) {
      state = await page('Runtime.evaluate', { expression: `document.documentElement.dataset.ready === 'true' && location.href === ${JSON.stringify(url.href)}`, returnByValue: true });
      if (state.result.value) break;
      await new Promise(resolve => setTimeout(resolve, 50));
    }
    if (!state.result.value) throw new Error(`Page not ready: ${url}`);
    const check = await page('Runtime.evaluate', { returnByValue: true, expression: `(() => {
      const issues = [];
      for (const img of document.images) if (!img.complete || !img.naturalWidth) issues.push('Image failed: ' + img.src);
      for (const shot of document.querySelectorAll('.shot')) {
        const heading = shot.querySelector('h1');
        const style = getComputedStyle(heading);
        if (heading.offsetHeight > parseFloat(style.lineHeight) * 2 + 2) issues.push(shot.id + ': title exceeds two lines');
        const copy = shot.querySelector('.copy');
        // 시안: 태블릿 프레임이 top:1010 에서 시작한다. 카피는 그 위 여백을 남겨야 한다.
        if (copy.offsetTop + copy.offsetHeight > 940) issues.push(shot.id + ': copy too close to device');
        const tablet = shot.querySelector('.tablet');
        const frame = shot.getBoundingClientRect();
        const bounds = tablet.getBoundingClientRect();
        if (bounds.left < frame.left || bounds.right > frame.right || bounds.bottom > frame.bottom) issues.push(shot.id + ': device cropped');
        // 화면 안 요소가 화면 밖으로 넘치면 안 된다(overflow:hidden 으로 잘려 보이지 않으므로 직접 확인).
        const screen = shot.querySelector('.screen');
        const sb = screen.getBoundingClientRect();
        for (const el of screen.querySelectorAll('*')) {
          const r = el.getBoundingClientRect();
          if (r.width && r.height && (r.left < sb.left - 1 || r.right > sb.right + 1 || r.top < sb.top - 1 || r.bottom > sb.bottom + 1)) { issues.push(shot.id + ': element overflows screen: ' + (el.textContent.trim().slice(0, 20) || el.className)); break; }
        }
      }
      if (document.body.classList.contains('single')) {
        const canvas = document.querySelector('#root > *');
        if (!canvas || canvas.offsetWidth !== innerWidth || canvas.offsetHeight !== innerHeight) issues.push('Wrong canvas size');
        const walker = document.createTreeWalker(canvas, NodeFilter.SHOW_TEXT);
        while (walker.nextNode()) {
          if (!walker.currentNode.textContent.trim()) continue;
          const range = document.createRange(); range.selectNodeContents(walker.currentNode);
          for (const rect of range.getClientRects()) if (rect.left < -1 || rect.top < -1 || rect.right > innerWidth + 1 || rect.bottom > innerHeight + 1) issues.push('Text outside canvas: ' + walker.currentNode.textContent);
        }
      }
      return {issues, width:innerWidth, height:innerHeight};
    })()` });
    if (check.exceptionDetails) throw new Error(JSON.stringify(check.exceptionDetails));
    if (check.result.value.issues.length) throw new Error(`${lang}/${screen}/${secs}: ${check.result.value.issues.join(', ')}`);
    if (filename) {
      const shot = await page('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
      await writeFile(filename, Buffer.from(shot.data, 'base64'));
      console.log(filename);
    }
    results.push({ lang, screen, secs, ...check.result.value, exported: !!filename });
  }
  await mkdir(validation, { recursive: true });
  // 시안 iPad 13" 섹션: 2064×2752 세로, P1~P4.
  const names = ['resting', 'picker', 'split-view', 'summary'];
  for (const lang of ['ko', 'en']) {
    await mkdir(join(out, lang), { recursive: true });
    for (const [i, name] of names.entries()) {
      for (const secs of [45, 90]) if (secs !== seconds) await render(lang, String(i + 1), secs, 2064, 2752);
      await render(lang, String(i + 1), seconds, 2064, 2752, join(out, lang, `ipad-0${i + 1}-${name}-portrait.png`));
    }
  }
  await writeFile(join(validation,'ipad-render-validation.json'),JSON.stringify({generatedAt:new Date().toISOString(),results},null,2));
  console.log(`Validated ${results.length} layouts and exported ${names.length * 2} iPad screenshots.`);

} finally {
  if (socket?.readyState === WebSocket.OPEN) {
    await send('Browser.close').catch(() => {});
    socket.close();
  }
  if (browser.exitCode === null) {
    const exited = new Promise(resolve => browser.once('exit', resolve));
    browser.kill('SIGTERM');
    await Promise.race([exited, new Promise(resolve => setTimeout(resolve, 3000))]);
  }
  for (const waiter of pending.values()) { clearTimeout(waiter.timer); waiter.reject(new Error('Browser closed')); }
  await rm(profile, { recursive: true, force: true, maxRetries: 3, retryDelay: 200 });
}

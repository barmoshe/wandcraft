// Plays the web build in headless Chromium as a landscape iPhone (932x430, touch) and checks
// what a tester would notice first. Run through tools/webtest.sh.
//   1. the canvas fills the window          2. no page errors
//   3. after a first tap (an iPhone-style touch id), sound really comes out: every connection to an AudioContext's destination is also
//   4. the Music bus itself plays (D8: window.wandcraftMusicPeak from the Audio autoload)
//      tapped into an AnalyserNode and the peak level measured (a "running" context alone
//      proves nothing: 0.4.1's first web builds were silent while reporting "running").
const PW = process.env.PLAYWRIGHT_MODULE || '/opt/node22/lib/node_modules/playwright/index.mjs';
const { chromium } = await import(PW);
const url = process.argv[2] || 'http://localhost:8765/index.html';
const browser = await chromium.launch({
	proxy: !url.includes('localhost') && process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY } : undefined,
	args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
const ctx = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 932, height: 430 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
await ctx.addInitScript(() => {
	window.__taps = [];
	const orig = AudioNode.prototype.connect;
	AudioNode.prototype.connect = function (dest, ...rest) {
		const r = orig.call(this, dest, ...rest);
		if (dest instanceof AudioDestinationNode) {
			const c = dest.context;
			if (!c.__an) { c.__an = c.createAnalyser(); c.__an.fftSize = 2048; window.__taps.push(c.__an); }
			orig.call(this, c.__an);
		}
		return r;
	};
	window.__peak = () => {
		let m = 0;
		for (const an of window.__taps) {
			const b = new Float32Array(an.fftSize);
			an.getFloatTimeDomainData(b);
			for (const v of b) m = Math.max(m, Math.abs(v));
		}
		return m;
	};
});
const page = await ctx.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
const cdp = await ctx.newCDPSession(page);
const touch = (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts });
const tap = async (x, y, id) => { await touch('touchStart', [{ x, y, id }]); await page.waitForTimeout(80); await touch('touchEnd', []); };
let failed = 0;
const check = (ok, msg) => { console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${msg}`); if (!ok) failed++; };

await page.goto(url);
await page.waitForFunction(() => !document.getElementById('status'), null, { timeout: 60000 });
await page.waitForTimeout(3000);
const box = await page.locator('canvas').boundingBox();
check(box && box.x === 0 && box.y === 0 && box.width === 932 && box.height === 430, `canvas fills the window (${JSON.stringify(box)})`);
// NEW RUN sits at about 63% x 47% of the title; iPhone-style large touch id
await tap(932 * 0.63, 430 * 0.47, 1234567);
let peak = 0;
for (let i = 0; i < 30; i++) {
	await page.waitForTimeout(100);
	peak = Math.max(peak, await page.evaluate(() => window.__peak()));
}
check(peak > 0.01, `sound comes out (peak level ${peak.toFixed(3)})`);
// D8: the music bus itself, once the run's first room has started its area music
let music = -200;
let track = '';
for (let i = 0; i < 20; i++) {
	await page.waitForTimeout(250);
	music = Math.max(music, await page.evaluate(() => (typeof window.wandcraftMusicPeak === 'number' ? window.wandcraftMusicPeak : -200)));
	track = await page.evaluate(() => window.wandcraftMusicTrack || '');
}
check(music > -60 && track !== '', `the music bus plays (${track}, peak ${music.toFixed(1)} dB)`);
const state = await page.evaluate(() => (window.wandcraftAudioState ? window.wandcraftAudioState() : 'none'));
check(/worklet ok/.test(state), `audio report: ${state}`);
check(errors.length === 0, `no page errors ${errors.length ? JSON.stringify(errors.slice(0, 3)) : ''}`);
await browser.close();
console.log(failed ? `WEBTEST: ${failed} FAILED` : 'WEBTEST: PASS');
process.exit(failed ? 1 : 0);

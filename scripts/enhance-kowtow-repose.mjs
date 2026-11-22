/**
 * 磕头小人高清化 v2 · 姿态重排：以高清站立帧为统一底图，逐帧独立编辑出对应姿态。
 *
 * v1 教训：从"伏地小扁团"源帧直接风格化，模型总是把人物画回站立/端坐，
 * 且各帧人物尺寸位置各画各的，动画抖动严重。
 * v2：每帧都以同一张高清底图（kowtow-hd-out/f01.png）出发"做动作"，
 * 风格/人物一致，姿态由显式角度指令控制（chain50 已验证此路姿态可控）。
 *
 * 用法: node scripts/enhance-kowtow-repose.mjs [起,止]   （缺省 1..51，帧 1 直接复制底图）
 * 输出: scripts/kowtow-hd-out2/fXX.png
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync, copyFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const BASE = resolve(__dirname, 'kowtow-hd-out/f01.png'); // 高清站立帧（财神像风格）
const OUT_DIR = resolve(__dirname, 'kowtow-hd-out2');
mkdirSync(OUT_DIR, { recursive: true });

// 每帧源图 alpha bbox 宽高比：站立≈0.54 → 渐进下拜 → 伏地定格=0.92
const RATIOS = [0.55,0.54,0.54,0.54,0.54,0.54,0.54,0.54,0.57,0.59,0.60,0.62,0.62,0.64,0.66,
  0.68,0.70,0.72,0.75,0.78,0.79,0.81,0.82,0.84,0.87,0.87,0.88,0.89,0.90,0.91,
  0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,
  0.92,0.92,0.92,0.92,0.92,0.92];

function poseText(idx) {
  const r = RATIOS[idx - 1] ?? 0.92;
  if (r <= 0.58) {
    return 'Kneeling upright on both knees, back completely vertical, hands resting on thighs, viewed from behind.';
  }
  if (r >= 0.91) {
    return 'Full prostration kowtow on the ground: the character lies FLAT, forehead and both hands pressed on the floor, ' +
      'the whole upper body folded all the way down into a low flat mound close to the ground. ' +
      'The head is DOWN at ground level, only the round back of the head and the curved back of the red robe visible, ' +
      'viewed from directly behind and slightly above. NOTHING upright: no raised head, no visible torso height, no chair, no sitting.';
  }
  const deg = Math.round((r - 0.57) / (0.91 - 0.57) * 150);
  return `Kneeling kowtow, mid-bow: the upper body leans forward about ${deg} degrees from vertical, ` +
    'head lowered forward accordingly, lower body still kneeling on both knees unchanged, viewed from behind.';
}

const KEEP =
  'Keep back view, the figure ALWAYS faces AWAY from viewer. ' +
  'Keep the red Hanfu robe with gold trim, black topknot hair, same character identity, ' +
  'same soft 3D chibi collectible figure style with soft studio lighting. ' +
  'Clean solid light cream background, full body visible and large in frame.';

async function editOne(idx) {
  const outPath = resolve(OUT_DIR, `f${String(idx).padStart(2, '0')}.png`);
  if (existsSync(outPath)) { console.log(`  [${idx}] skip (exists)`); return true; }
  const b64 = 'data:image/png;base64,' + readFileSync(BASE).toString('base64');
  const body = {
    model: 'Qwen/Qwen-Image-Edit-2509',
    prompt: `${poseText(idx)} ${KEEP}`,
    image: b64,
    image_size: '1024x1024',
  };
  const t0 = Date.now();
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch('https://api.siliconflow.cn/v1/images/generations', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      if (res.ok && data.images && data.images[0]) {
        const url = data.images[0].url ?? data.images[0].b64_json;
        const buf = url.startsWith('data:')
          ? Buffer.from(url.split(',')[1], 'base64')
          : Buffer.from(await (await fetch(url)).arrayBuffer());
        writeFileSync(outPath, buf);
        console.log(`  [${idx}] ok (${(buf.length / 1024).toFixed(0)}KB, ${Date.now() - t0}ms)`);
        return true;
      }
      console.warn(`  [${idx}] attempt${attempt}: HTTP ${res.status} ${JSON.stringify(data).slice(0, 150)}`);
    } catch (e) {
      console.warn(`  [${idx}] attempt${attempt}: ${e.message}`);
    }
    await new Promise(r => setTimeout(r, 3000));
  }
  console.error(`  [${idx}] FAIL`);
  return false;
}

let fail = 0;
for (let i = 1; i <= 51; i++) {
  if (i === 1) {
    copyFileSync(BASE, resolve(OUT_DIR, 'f01.png'));
    console.log('  [1] base copied');
    continue;
  }
  const ok = await editOne(i);
  if (!ok) fail++;
  await new Promise(r => setTimeout(r, 1500));
}
console.log(`\ndone, fail=${fail}`);
process.exit(fail > 0 ? 1 : 0);

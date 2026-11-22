/**
 * 磕头小人高清化 · 第 2 步：逐帧独立走 Qwen-Image-Edit-2509 风格化重绘。
 * 不做链式编辑（54 连链会累积劣化）——每帧直接编辑自己的源帧，姿态由原图锁定。
 * 风格对齐财神像 v2（gen-deities-v2.mjs）的 soft-3D 手办质感。
 *
 * 用法: node scripts/enhance-kowtow-hd.mjs 1,14,27,40,51   （缺省跑全部 1..51）
 * 输入: scripts/kowtow-hd-src/fXX.png   输出: scripts/kowtow-hd-out/fXX.png
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const SRC_DIR = resolve(__dirname, 'kowtow-hd-src');
const OUT_DIR = resolve(__dirname, 'kowtow-hd-out');
mkdirSync(OUT_DIR, { recursive: true });

const KEEP =
  'CRITICAL: Do NOT stand the figure up. The output pose MUST match the input image exactly. ' +
  'Keep back view, the figure ALWAYS faces AWAY from viewer. ' +
  'Keep the red Hanfu robe with gold trim, black topknot hair, same character identity. ' +
  'Keep the clean solid light cream background.';

const STYLE =
  'Repaint this character in premium soft 3D chibi collectible figure style: ' +
  'smooth glossy surfaces, rich soft shading and highlights, soft studio lighting, ' +
  'high detail digital painting, vibrant saturated colors, Q-version chibi big head small body.';

// 每帧源图 alpha bbox 宽高比（kowtow-hd-prep 实测）：站立≈0.54，渐进下拜 0.57→0.91，伏地定格=0.92
const RATIOS = [0.55,0.54,0.54,0.54,0.54,0.54,0.54,0.54,0.57,0.59,0.60,0.62,0.62,0.64,0.66,
  0.68,0.70,0.72,0.75,0.78,0.79,0.81,0.82,0.84,0.87,0.87,0.88,0.89,0.90,0.91,
  0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,0.92,
  0.92,0.92,0.92,0.92,0.92,0.92];

/** 按宽高比生成显式姿态描述：修复伏地帧被模型"站起来"的问题 */
function poseText(idx) {
  const r = RATIOS[idx - 1] ?? 0.92;
  if (r <= 0.58) return 'Kneeling upright on both knees, back completely vertical, hands resting on thighs, viewed from behind.';
  if (r >= 0.91) return 'Fully prostrate on the ground: forehead and arms flat on the floor, body folded completely flat, a low rounded mound of red robe lying on the ground, head lying LOW, holding still, viewed from directly behind and slightly above.';
  const deg = Math.round((r - 0.57) / (0.91 - 0.57) * 150);
  return `Kneeling, upper body bowed forward about ${deg} degrees, head lowered accordingly, viewed from behind.`;
}

const arg = process.argv[2];
const idxs = arg
  ? arg.split(',').map(s => parseInt(s.trim(), 10))
  : Array.from({ length: 51 }, (_, i) => i + 1);

async function editOne(idx) {
  const inPath = resolve(SRC_DIR, `f${String(idx).padStart(2, '0')}.png`);
  const outPath = resolve(OUT_DIR, `f${String(idx).padStart(2, '0')}.png`);
  if (!existsSync(inPath)) { console.error(`  MISS ${inPath}`); return false; }
  if (existsSync(outPath)) { console.log(`  [${idx}] skip (exists)`); return true; }
  const b64 = 'data:image/png;base64,' + readFileSync(inPath).toString('base64');
  const body = {
    model: 'Qwen/Qwen-Image-Edit-2509',
    prompt: `${poseText(idx)} ${STYLE}. ${KEEP}`,
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
for (const i of idxs) {
  const ok = await editOne(i);
  if (!ok) fail++;
  await new Promise(r => setTimeout(r, 1500));
}
console.log(`\ndone: ${idxs.length - fail}/${idxs.length} ok`);
process.exit(fail > 0 ? 1 : 0);

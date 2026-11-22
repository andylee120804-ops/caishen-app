/**
 * 磕头关键帧候选生成（方案 2：3~4 帧交叉淡入淡出替代 51 帧序列）。
 * 底图 = HD 站立小人（财神像风格），逐姿态生成 4 个候选，
 * 后续由 pick 脚本按 [宽高比 + 左右对称度(背面视角) + 红袍占比] 自动择优。
 *
 * 输出: scripts/kowtow-kf/cand/kf{2,3,4}_{1..4}.png
 * KF1(站立) 直接复用 scripts/kowtow-hd-out/f01.png，不重新生成。
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const BASE = resolve(__dirname, 'kowtow-hd-out/f01.png');
const OUT = resolve(__dirname, 'kowtow-kf/cand');
mkdirSync(OUT, { recursive: true });

const CAMERA_LOCK =
  'CAMERA LOCKED: the camera stays directly BEHIND the character — strict back view, ' +
  'only the back of the head and the back are visible, the face is NOT visible. ' +
  'Character perfectly centered, left-right symmetrical composition. ' +
  'Keep the premium soft 3D chibi collectible figure style: smooth glossy surfaces, soft studio lighting, ' +
  'rich shading, vibrant colors, red Hanfu robe with gold trim, black topknot. ' +
  'Clean solid light cream background, full body large in frame.';

const KEYFRAMES = [
  {
    id: 2,
    pose: 'Kneeling kowtow mid-bow: the upper body leans forward about 65 degrees from vertical, ' +
      'head lowered forward accordingly, lower body still kneeling on both knees unchanged.',
  },
  {
    id: 3,
    pose: 'Kneeling kowtow deep bow: the upper body is bent forward past horizontal, about 115 degrees, ' +
      'the head hangs low close to the ground in front of the knees, lower body kneeling on both knees unchanged.',
  },
  {
    id: 4,
    pose: 'Full prostration kowtow: the character lies FLAT, forehead and both hands pressed on the floor, ' +
      'the whole upper body folded all the way down into a low rounded mound close to the ground, ' +
      'head lying LOW, nothing upright, no raised head, no sitting.',
  },
];

const N_CAND = 4;

async function genOne(kf, n) {
  const outPath = resolve(OUT, `kf${kf.id}_${n}.png`);
  if (existsSync(outPath)) { console.log(`  kf${kf.id}_${n} skip`); return true; }
  const b64 = 'data:image/png;base64,' + readFileSync(BASE).toString('base64');
  const body = {
    model: 'Qwen/Qwen-Image-Edit-2509',
    prompt: `${kf.pose} ${CAMERA_LOCK}`,
    image: b64,
    image_size: '1024x1024',
    seed: 1000 * kf.id + n,
  };
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
        console.log(`  kf${kf.id}_${n} ok (${(buf.length / 1024).toFixed(0)}KB)`);
        return true;
      }
      console.warn(`  kf${kf.id}_${n} attempt${attempt}: HTTP ${res.status}`);
    } catch (e) {
      console.warn(`  kf${kf.id}_${n} attempt${attempt}: ${e.message}`);
    }
    await new Promise(r => setTimeout(r, 3000));
  }
  console.error(`  kf${kf.id}_${n} FAIL`);
  return false;
}

let fail = 0;
const base64img = readFileSync(BASE);
writeFileSync(resolve(OUT, 'kf1_1.png'), base64img); // KF1 直接复用底图
console.log('  kf1_1 base copied');
for (const kf of KEYFRAMES) {
  for (let n = 1; n <= N_CAND; n++) {
    const ok = await genOne(kf, n);
    if (!ok) fail++;
    await new Promise(r => setTimeout(r, 1500));
  }
}
console.log(`\ndone, fail=${fail}`);
process.exit(fail > 0 ? 1 : 0);

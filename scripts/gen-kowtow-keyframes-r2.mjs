/**
 * 关键帧候选第二轮：kf3(深拜)/kf4(伏地) 用"镜头所见外观"描述重生成。
 * 第一轮教训：角度数字指令（115度/贴地）模型不遵从——背面的不够深、够深的转侧脸；
 * 改为描述从背面看到的剪影外观（"看到宽圆的背、头沉到两肩之间/贴地矮团"），
 * 每姿态 6 候选，交给 pick 脚本对称度指标把关。
 *
 * 输出: scripts/kowtow-kf/cand/kf3_r1..6.png, kf4_r1..6.png
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
  'The camera is fixed directly BEHIND the character and does not move: strict back view, ' +
  'the face is NEVER visible, only the back of the head and the back. ' +
  'Perfectly centered, left-right symmetrical. ' +
  'Premium soft 3D chibi collectible figure style: glossy surfaces, soft studio lighting, rich shading, ' +
  'vibrant colors, red Hanfu robe with gold trim, black topknot. ' +
  'Clean solid light cream background, full body large in frame.';

const KEYFRAMES = [
  {
    id: 3,
    pose: 'Seen from behind: a kneeling chibi figure whose upper body has folded far forward and down — ' +
      'the head has sunk low between the shoulders, so we mostly see the broad curved back of the red robe ' +
      'rising up toward the camera and the round back of the black-hair head dropped low in the middle of it. ' +
      'The figure looks compressed and rounded, nearly as wide as it is tall. No standing, no upright torso.',
  },
  {
    id: 4,
    pose: 'Seen from directly behind and slightly above: only a LOW FLAT MOUND on the floor — ' +
      'the character is fully prostrate, forehead and arms flat on the ground, ' +
      'so we see the wide curved back of the red robe spread over the ground and the round back of the head ' +
      'resting low at the center of the mound. The silhouette is clearly WIDER than it is tall and very low. ' +
      'No standing, no sitting, no raised head, no visible face.',
  },
];

const N_CAND = 6;

async function genOne(kf, n) {
  const outPath = resolve(OUT, `kf${kf.id}_r${n}.png`);
  if (existsSync(outPath)) { console.log(`  kf${kf.id}_r${n} skip`); return true; }
  const b64 = 'data:image/png;base64,' + readFileSync(BASE).toString('base64');
  const body = {
    model: 'Qwen/Qwen-Image-Edit-2509',
    prompt: `${kf.pose} ${CAMERA_LOCK}`,
    image: b64,
    image_size: '1024x1024',
    seed: 7000 * kf + n,
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
        console.log(`  kf${kf.id}_r${n} ok (${(buf.length / 1024).toFixed(0)}KB)`);
        return true;
      }
      console.warn(`  kf${kf.id}_r${n} attempt${attempt}: HTTP ${res.status}`);
    } catch (e) {
      console.warn(`  kf${kf.id}_r${n} attempt${attempt}: ${e.message}`);
    }
    await new Promise(r => setTimeout(r, 3000));
  }
  console.error(`  kf${kf.id}_r${n} FAIL`);
  return false;
}

let fail = 0;
for (const kf of KEYFRAMES) {
  for (let n = 1; n <= N_CAND; n++) {
    const ok = await genOne(kf, n);
    if (!ok) fail++;
    await new Promise(r => setTimeout(r, 1500));
  }
}
console.log(`\ndone, fail=${fail}`);
process.exit(fail > 0 ? 1 : 0);

// 关羽编辑第三轮：小步链式把刀从「向下」翻到「刀头朝上」
// 经验来自 sf-kowtow-chain.mjs：单步大改动会被模型忽略，小步递进才可靠。
// 起点 = r2_eyes.jpg（已闭眼），3 小步抬刀，每步锁定闭眼+人物不变，失败重试 3 次。
// 用法: node scripts/gen-guanyu-edit3.mjs
// 输出: tmp/guanyu-edit-candidates/r3_s1_raise.jpg / r3_s2_high.jpg / r3_final_up.jpg
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const API = 'https://api.siliconflow.cn/v1/images/generations';
const SRC = resolve(__dirname, '../tmp/guanyu-edit-candidates/r2_eyes.jpg');
const OUT_DIR = resolve(__dirname, '../tmp/guanyu-edit-candidates');

const KEEP =
  'CRITICAL: Keep the exact same character: red face, long black beard, emerald green robe with gold armor, ' +
  'same chibi cartoon style, same fully closed serene eyes, same cream background, same composition and design. ' +
  'Never change the character.';

const STEPS = [
  {
    out: 'r3_s1_raise.jpg',
    pose: 'Lift the weapon upward: the long pole now rises from the hand up to about 45 degrees, the blade head moves up from the ground to waist height. Only the weapon moves, small change.',
  },
  {
    out: 'r3_s2_high.jpg',
    pose: 'Raise the pole further: now almost vertical, the crescent blade head rises above head level, clearly pointing up. Remove the blade head from the bottom, no weapon parts remain near the ground.',
  },
  {
    out: 'r3_final_up.jpg',
    pose: 'Final pose: hold the long pole fully vertical and upright, the curved crescent blade head at the very top, high above the head, pointing straight up. Absolutely no blade or metal parts at the bottom or on the ground. Only the upright pole and the top blade head remain.',
  },
];

async function editOne(inputPath, step) {
  const b64 = 'data:image/jpeg;base64,' + readFileSync(inputPath).toString('base64');
  const body = {
    model: 'Qwen/Qwen-Image-Edit-2509',
    prompt: `${step.pose}. ${KEEP}`,
    image: b64,
    image_size: '1024x1024',
  };
  console.log(`▶ ${step.out}: ${step.pose.slice(0, 70)}...`);
  const t0 = Date.now();
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch(API, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      if (data.images && data.images[0]) {
        const buf = Buffer.from(await (await fetch(data.images[0].url)).arrayBuffer());
        mkdirSync(OUT_DIR, { recursive: true });
        const outPath = resolve(OUT_DIR, step.out);
        writeFileSync(outPath, buf);
        console.log(`  ✓ ${outPath} (${(buf.length / 1024).toFixed(1)} KB, ${((Date.now() - t0) / 1000).toFixed(1)}s)`);
        return outPath;
      }
      throw new Error(`HTTP ${res.status}: ${JSON.stringify(data).slice(0, 200)}`);
    } catch (e) {
      console.error(`  ✗ attempt ${attempt}: ${e.message}`);
      if (attempt === 3) return null;
    }
  }
  return null;
}

async function main() {
  if (!existsSync(SRC)) {
    console.error(`起点图不存在: ${SRC}（先运行 gen-guanyu-edit2.mjs）`);
    process.exit(1);
  }
  let cur = SRC;
  for (const step of STEPS) {
    const out = await editOne(cur, step);
    if (!out) {
      console.error(`  ✗ ${step.out} 三步全失败，中止链`);
      break;
    }
    cur = out;
  }
  console.log('done');
}

main();

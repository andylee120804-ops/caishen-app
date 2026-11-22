// 关羽神像编辑 第二轮：单步短指令 + 分阶段链式（闭眼 → 改刀向）
// 第一轮（gen-guanyu-edit.mjs）长中文指令被模型弱化，几乎未改动。
// 本轮每步只做一件事、用英文短指令；链式：先闭眼，再在闭眼结果上改刀向。
// 用法: node scripts/gen-guanyu-edit2.mjs
// 输出: tmp/guanyu-edit-candidates/
//   r2_eyes.jpg        闭眼单步（底图=原图）
//   r2_blade.jpg       刀头朝上单步（底图=原图）
//   r2_eyes_blade.jpg  闭眼结果上再改刀向（链式最终版）
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const API = 'https://api.siliconflow.cn/v1/images/generations';
const SRC = resolve(__dirname, '../entry/src/main/resources/rawfile/deities/_v2/guanyu.jpg');
const OUT_DIR = resolve(__dirname, '../tmp/guanyu-edit-candidates');

async function edit(srcPath, prompt, outName) {
  const b64 = 'data:image/jpeg;base64,' + readFileSync(srcPath).toString('base64');
  const body = {
    model: 'Qwen/Qwen-Image-Edit-2509',
    prompt,
    image: b64,
    image_size: '1024x1024',
  };
  console.log(`▶ ${outName}: ${prompt}`);
  const start = Date.now();
  const res = await fetch(API, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok || !data.images || !data.images.length) {
    throw new Error(`HTTP ${res.status}: ${JSON.stringify(data).slice(0, 300)}`);
  }
  const buf = Buffer.from(await (await fetch(data.images[0].url)).arrayBuffer());
  mkdirSync(OUT_DIR, { recursive: true });
  const outPath = resolve(OUT_DIR, outName);
  writeFileSync(outPath, buf);
  console.log(`  ✓ ${outPath} (${(buf.length / 1024).toFixed(1)} KB, ${((Date.now() - start) / 1000).toFixed(1)}s)`);
  return outPath;
}

const EYES = 'Close the eyes of this character: both eyes fully closed, drawn as two gentle downward-curving dark lines instead of open eyes. Change nothing else.';
const BLADE = 'Make the weapon point upward: hold the long pole vertically upright with the curved crescent blade at the top. Change nothing else.';

async function main() {
  if (!existsSync(SRC)) {
    console.error(`底图不存在: ${SRC}`);
    process.exit(1);
  }
  let eyesOut = null;
  try {
    eyesOut = await edit(SRC, EYES, 'r2_eyes.jpg');
  } catch (e) { console.error('  ✗ eyes step failed:', e.message); }
  try {
    await edit(SRC, BLADE, 'r2_blade.jpg');
  } catch (e) { console.error('  ✗ blade step failed:', e.message); }
  if (eyesOut) {
    try {
      await edit(eyesOut, BLADE, 'r2_eyes_blade.jpg');
    } catch (e) { console.error('  ✗ chained step failed:', e.message); }
  }
  console.log('done');
}

main();

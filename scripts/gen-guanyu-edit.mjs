// 关羽神像指令式编辑：刀头向下→朝上、睁眼→闭眼（保人物一致性）
// 底图：rawfile/deities/_v2/guanyu.jpg（1024×1024，浅奶油底，即 deities/3.png 的原始大图）
// 通道：硅基流动 Qwen-Image-Edit-2509（与 sf-imgedit.mjs 同一 API / 同一模型）
//
// 用法：
//   node scripts/gen-guanyu-edit.mjs          # 生成全部 4 版候选
//   node scripts/gen-guanyu-edit.mjs 1 3      # 只生成指定版本
//
// 输出：tmp/guanyu-edit-candidates/guanyu_edit_v{n}.jpg
// 候选仅供挑选（预览 guanyu-edit-preview.html），选定后再 rembg 抠图 + 缩放 512 入库。
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const API = 'https://api.siliconflow.cn/v1/images/generations';
const SRC = resolve(__dirname, '../entry/src/main/resources/rawfile/deities/_v2/guanyu.jpg');
const OUT_DIR = resolve(__dirname, '../tmp/guanyu-edit-candidates');

// 共同约束：Q版国风卡通、红脸长须、绿袍金甲、构图配色背景一律不变
const KEEP =
  '其余全部保持原样：Q版卡通国风、红脸长须、绿袍金甲、姿势构图、配色、浅奶油背景都不变。';

const VARIANTS = [
  {
    id: 1,
    desc: '竖持刀头朝上 + 闭眼（基准版）',
    prompt: `把图中关羽手中的青龙偃月刀改为刀头朝上、刀刃朝外的竖持姿势（刀杆直立，刀头在上方）；把关羽的眼睛改为安详闭眼。${KEEP}`,
  },
  {
    id: 2,
    desc: '扛刀在肩刀头朝上 + 闭眼',
    prompt: `把图中关羽手中的青龙偃月刀改为扛在肩上、刀头朝上（刀杆斜靠肩头，刀头在上方高处）；把关羽的眼睛改为安详闭眼。${KEEP}`,
  },
  {
    id: 3,
    desc: '一手捋须一手持刀刀头朝上 + 闭眼',
    prompt: `把图中关羽改为左手捋长须、右手竖持青龙偃月刀且刀头朝上；把关羽的眼睛改为安详闭眼。${KEEP}`,
  },
  {
    id: 4,
    desc: '闭眼安详神情 + 竖持刀头朝上（表情强化版）',
    prompt: `把图中关羽的眼睛改为安详闭眼，神情庄重慈祥；把手中的青龙偃月刀改为刀头朝上的竖持姿势。${KEEP}`,
  },
];

async function generateOne(v) {
  const b64 = 'data:image/jpeg;base64,' + readFileSync(SRC).toString('base64');
  const body = {
    model: 'Qwen/Qwen-Image-Edit-2509',
    prompt: v.prompt,
    image: b64,
    image_size: '1024x1024',
  };
  console.log(`▶ v${v.id} - ${v.desc}`);
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
  const url = data.images[0].url;
  const buf = Buffer.from(await (await fetch(url)).arrayBuffer());
  mkdirSync(OUT_DIR, { recursive: true });
  const outPath = resolve(OUT_DIR, `guanyu_edit_v${v.id}.jpg`);
  writeFileSync(outPath, buf);
  console.log(`  ✓ ${outPath} (${(buf.length / 1024).toFixed(1)} KB, ${((Date.now() - start) / 1000).toFixed(1)}s)`);
}

async function main() {
  if (!existsSync(SRC)) {
    console.error(`底图不存在: ${SRC}`);
    process.exit(1);
  }
  const want = process.argv.slice(2).map(Number).filter(Boolean);
  const list = want.length ? VARIANTS.filter(v => want.includes(v.id)) : VARIANTS;
  for (const v of list) {
    try {
      await generateOne(v);
      await new Promise(r => setTimeout(r, 2000));
    } catch (e) {
      console.error(`  ✗ v${v.id} failed:`, e.message);
    }
  }
  console.log('done');
}

main();

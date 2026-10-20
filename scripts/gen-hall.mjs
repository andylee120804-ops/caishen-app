// 财神殿大殿背景生成脚本 - 通过 Pollinations.ai (FLUX) 生成殿内整幅背景
// 与 gen-props.mjs 同一出图流程（同 API / 同画风前缀），区别：
//   1. 场景背景是整幅图，不抠透明背景（无需 rembg）
//   2. 输出到 tmp/hall-candidates/ 供挑选，选定后再拷入 rawfile/hall/
//
// 用法：
//   node scripts/gen-hall.mjs              # 生成全部候选
//   node scripts/gen-hall.mjs 401 403      # 只生成指定 seed
//
// 选定后：
//   cp tmp/hall-candidates/hall_s<seed>.jpg entry/src/main/resources/rawfile/hall/hall_bg.jpg

import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = resolve(__dirname, '../tmp/hall-candidates');

const POLLINATIONS_URL = 'https://image.pollinations.ai/prompt/';
const MODEL = 'flux';

// 与财神像/道具一致的画风前缀（Q版国风卡通、高饱和），场景版去掉奶油底要求
// 教训1：只写 "Q-version cartoon" FLUX 会画成半写实，需加 game background art；
// 教训2：过长/按位置结构化的提示词会被稀释跑偏（青绿、日式房间），保持短提示词
const STYLE_PREFIX =
  'beautiful digital painting, Chinese cartoon game background art, ' +
  'vibrant saturated colors, rich detail, soft warm lighting, ' +
  'no people, no person, no character, no creature, no text, no letters, no watermark';

// 短提示词：朱红+金殿内、正面对称、背面实墙、地面留空（真实素材在 ArkTS 分层叠加）
const SCENE =
  'interior of a grand Chinese temple hall, straight-on front view, perfectly symmetrical, ' +
  'vertical composition, deep crimson red and gold palette, ' +
  'golden caisson ceiling medallion at top, dark red beams with golden cloud patterns, ' +
  'solid red lacquer walls with golden trim, two thick red pillars with golden dragon engravings at left and right edges, ' +
  'warm golden glow in the air, floating golden sparkles, ' +
  'polished dark red wooden floor, a long red carpet with golden border down the center, ' +
  'completely empty, no windows, no doors, no lanterns, no furniture, no table, no offerings';

// 候选 seed：同一构图提示词，不同 seed 挑选最贴近项目风格的
const SEEDS = [401, 402, 403, 404];
const WIDTH = 640, HEIGHT = 1392; // 390:844 ≈ 0.462，屏幕 1.64x 分辨率

async function generateOne(seed) {
  const file = `hall_s${seed}.jpg`;
  const fullPrompt = `${STYLE_PREFIX}. ${SCENE}.`;
  const params = new URLSearchParams({
    width: String(WIDTH),
    height: String(HEIGHT),
    model: MODEL,
    seed: String(seed),
    nologo: 'true',
  });
  const url = `${POLLINATIONS_URL}${encodeURIComponent(fullPrompt)}?${params}`;
  const outPath = resolve(OUT_DIR, file);
  console.log(`▶ 生成 ${file}（seed=${seed}, ${WIDTH}x${HEIGHT}）`);

  const start = Date.now();
  // 免费档限流会返回 402，指数退避重试
  let buf = null;
  for (let attempt = 1; attempt <= 3; attempt++) {
    const res = await fetch(url, { method: 'GET' });
    if (res.ok) {
      buf = Buffer.from(await res.arrayBuffer());
      if (buf.length >= 10 * 1024) break; // 过小视为错误响应
      buf = null;
    }
    if (attempt < 3) {
      const wait = attempt * 20000;
      console.log(`  … 第${attempt}次未成功(${res ? res.status : 'body too small'})，${wait / 1000}s 后重试`);
      await new Promise((r) => setTimeout(r, wait));
    }
  }
  if (!buf) {
    throw new Error('重试 3 次仍失败（限流或服务不可用）');
  }
  await mkdir(OUT_DIR, { recursive: true });
  await writeFile(outPath, buf);
  console.log(`  ✓ 已保存 ${outPath} (${(buf.length / 1024).toFixed(1)} KB, ${Date.now() - start}ms)\n`);
}

async function main() {
  const args = process.argv.slice(2).map(Number).filter(Boolean);
  const seeds = args.length ? args : SEEDS;
  console.log(`将生成 ${seeds.length} 张大殿背景候选\n`);
  let ok = 0;
  for (let i = 0; i < seeds.length; i++) {
    try {
      await generateOne(seeds[i]);
      ok++;
    } catch (err) {
      console.error(`  ✗ 失败 seed=${seeds[i]}: ${err.message}\n`);
    }
    if (i < seeds.length - 1) {
      await new Promise((r) => setTimeout(r, 12000)); // 请求间隔，降低限流概率
    }
  }
  console.log(`完成 ${ok}/${seeds.length}。挑选后运行: cp tmp/hall-candidates/hall_s<seed>.jpg entry/src/main/resources/rawfile/hall/hall_bg.jpg`);
}

main();

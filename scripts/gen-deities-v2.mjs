// 四位新财神神像生成（王亥/比干/关羽/柴荣）——硅基流动 Qwen-Image（Pollinations 波动时用此通道）
// 输出：rawfile/deities/_v2/{name}.jpg（1024×1024，浅奶油底，待 rembg 抠图）
import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = resolve(__dirname, '../entry/src/main/resources/rawfile/deities/_v2');

const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const API = 'https://api.siliconflow.cn/v1/images/generations';

const STYLE_PREFIX =
  'Q-version chibi cartoon Chinese deity, cute chibi style, big head small body, ' +
  'traditional Chinese folk god style, centered full body, symmetrical, ' +
  'vibrant saturated colors, clean solid light cream background, ' +
  'high detail, digital painting, soft studio lighting';

const DEITIES = [
  {
    file: 'wanghai.jpg', name: '王亥', role: '中路', seed: 106,
    prompt: 'Wang Hai, legendary first merchant of ancient China, Shang dynasty tribal leader, gentle strong man in simple ancient leather and fur robe, standing proudly beside a sturdy ox pulling a wooden cart loaded with trade goods, warm earthy brown and gold color scheme',
  },
  {
    file: 'bigan.jpg', name: '比干', role: '东路', seed: 107,
    prompt: 'Bi Gan, ancient Chinese royal advisor and loyal minister, dignified elderly civil official with white hair and long beard, elegant dark blue official robe, holding a narrow court tablet, wise and fair expression, blue white and silver color scheme',
  },
  {
    file: 'guanyu.jpg', name: '关羽', role: '西路', seed: 108,
    prompt: 'Guan Yu, red face with long black beard, heroic martial god, magnificent emerald green robe over golden armor, holding the Green Dragon Crescent Blade, majestic imposing stance, green red and gold color scheme',
  },
  {
    file: 'chairong.jpg', name: '柴荣', role: '南路', seed: 109,
    prompt: 'Chai Rong, Later Zhou Dynasty emperor, heroic young king wearing golden dragon robe with imperial crown, holding a scroll, ambitious and majestic expression, royal gold and red color scheme',
  },
];

async function generateOne(deity) {
  const body = {
    model: 'Qwen/Qwen-Image',
    prompt: `${STYLE_PREFIX}. ${deity.prompt}.`,
    image_size: '1024x1024',
    seed: deity.seed,
  };
  console.log(`▶ ${deity.file} - ${deity.name}（${deity.role}）seed=${deity.seed}`);
  const start = Date.now();
  const res = await fetch(API, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok || !data.images || !data.images.length) {
    throw new Error(`HTTP ${res.status}: ${JSON.stringify(data).slice(0, 240)}`);
  }
  const b64 = data.images[0].url ?? data.images[0].b64_json;
  const buf = b64.startsWith('data:')
    ? Buffer.from(b64.split(',')[1], 'base64')
    : Buffer.from(await (await fetch(b64)).arrayBuffer());
  const outPath = resolve(OUT_DIR, deity.file);
  await writeFile(outPath, buf);
  console.log(`  ✓ ${outPath} (${(buf.length / 1024).toFixed(1)} KB, ${Date.now() - start}ms)`);
}

async function main() {
  await mkdir(OUT_DIR, { recursive: true });
  for (const d of DEITIES) {
    try {
      await generateOne(d);
      await new Promise(r => setTimeout(r, 3000));
    } catch (e) {
      console.error(`  ✗ ${d.name} failed:`, e.message);
    }
  }
  console.log('done');
}

main();
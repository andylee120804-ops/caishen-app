/**
 * 测试低 strength 是否能保住伏地姿态(只换风格不动姿态)。
 * 单图(源帧) + 纯"提升质感、保持姿态"提示词，扫 strength=0.15 / 0.30。
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const KEY = 'sk-izzswqdtlbmkkuxizbqrovkppxvbdomoujaezttrghipkpsx';
const IN = resolve(__dirname, 'kowtow-hd-src/f31.png');
const b64 = 'data:image/png;base64,' + readFileSync(IN).toString('base64');
const prompt = 'Enhance the visual quality and detail of this exact character. ' +
  'Keep the IDENTICAL pose, silhouette, back view, size and position. ' +
  'Only upgrade art style to premium soft 3D chibi collectible figure with soft studio lighting and rich shading. Do not alter the pose.';

for (const s of [0.15, 0.30]) {
  const body = { model: 'Qwen/Qwen-Image-Edit-2509', prompt, image: b64, image_size: '1024x1024', strength: s };
  const res = await fetch('https://api.siliconflow.cn/v1/images/generations', {
    method: 'POST', headers: { 'Authorization': `Bearer ${KEY}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body),
  });
  const data = await res.json();
  if (res.ok && data.images && data.images[0]) {
    const url = data.images[0].url ?? data.images[0].b64_json;
    const buf = url.startsWith('data:') ? Buffer.from(url.split(',')[1], 'base64') : Buffer.from(await (await fetch(url)).arrayBuffer());
    writeFileSync(resolve(__dirname, `test-31c-s${s}.png`), buf);
    console.log(`strength=${s} saved (${(buf.length/1024).toFixed(0)}KB)`);
  } else console.log(`strength=${s} FAIL`, JSON.stringify(data).slice(0,200));
}

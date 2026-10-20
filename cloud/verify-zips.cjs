// cloud/verify-zips.cjs
// 校验 deploy.cjs 产出的 6 个 zip 是否满足 AGC 部署要求：
// handler.js/myHandler、shared/、agc-credential.json、cloud-server SDK、
// 正斜杠路径、hostOS=Unix、无 smoke 脚本、无 zip 嵌套。仅本地校验，不联网。
const fs = require('fs');
const path = require('path');

const FUNCS = ['update-prayer-count', 'get-leaderboard', 'wish-wall',
  'game-record-backup', 'donation-record', 'jieqian-unlock'];
const BS = String.fromCharCode(92); // 反斜杠

let allOk = true;
for (const name of FUNCS) {
  const zipPath = path.join(__dirname, name, name + '.zip');
  if (!fs.existsSync(zipPath)) {
    console.log('FAIL  ' + name + '  zip 不存在');
    allOk = false;
    continue;
  }
  const buf = fs.readFileSync(zipPath);
  const EOCD_SIG = 0x06054b50;
  let eocd = -1;
  for (let i = buf.length - 22; i >= 0; i--) {
    if (buf.readUInt32LE(i) === EOCD_SIG) { eocd = i; break; }
  }
  if (eocd < 0) { console.log('FAIL  ' + name + '  非法 zip'); allOk = false; continue; }
  const total = buf.readUInt16LE(eocd + 10);
  let off = buf.readUInt32LE(eocd + 16);
  const names = [];
  let backslash = 0;
  let hostOsBad = 0;
  for (let n = 0; n < total; n++) {
    if (buf.readUInt32LE(off) !== 0x02014b50) break;
    const fnLen = buf.readUInt16LE(off + 28);
    const exLen = buf.readUInt16LE(off + 30);
    const cLen = buf.readUInt16LE(off + 32);
    const fname = buf.slice(off + 46, off + 46 + fnLen).toString('utf8');
    if (fname.includes(BS)) backslash++;
    if (buf[off + 5] !== 3) hostOsBad++;
    names.push(fname);
    off += 46 + fnLen + exLen + cLen;
  }
  const has = (p) => names.includes(p);
  const src = fs.readFileSync(path.join(__dirname, name, 'handler.js'), 'utf8');
  const checks = {
    'handler.js': has('handler.js'),
    'package.json': has('package.json'),
    'shared/response.js': has('shared/response.js'),
    'shared/db.js': has('shared/db.js'),
    'agc-credential.json': has('agc-credential.json'),
    'cloud-server SDK': names.some((n) => n.startsWith('node_modules/@hw-agconnect/cloud-server/')),
    'myHandler导出': /exports\s*\.\s*myHandler|module\.exports\s*\.\s*myHandler/.test(src),
    '无smoke脚本': !names.some((n) => /^smoke/.test(n)),
    '无zip嵌套': !names.some((n) => n.endsWith('.zip')),
    '正斜杠路径': backslash === 0,
    'hostOS=Unix': hostOsBad === 0,
  };
  const fails = Object.entries(checks).filter(([, v]) => v !== true).map(([k]) => k);
  const ok = fails.length === 0;
  if (!ok) allOk = false;
  console.log((ok ? 'PASS ' : 'FAIL ') + name + '  entries=' + total +
    '  size=' + Math.round(fs.statSync(zipPath).size / 1024) + 'KB' +
    (ok ? '' : '  问题: ' + fails.join(',')));
}
console.log(allOk ? '\n全部 ' + FUNCS.length + ' 个 zip 校验通过' : '\n存在失败项！');
process.exit(allOk ? 0 : 1);

// DevEco 签名密码解密/加密（按 hvigor decipher-util.js 精确复刻）
// 用法：
//   node deveco-cipher.cjs decrypt <0000001B...> [materialDir]
//   node deveco-cipher.cjs encrypt <明文密码> [materialDir]
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const COMP = new Int8Array([49, 243, 9, 115, 214, 175, 91, 184, 211, 190, 177, 88, 101, 131, 192, 119]);

function readDirBytes(dir) {
  const entries = fs.readdirSync(dir);
  if (entries.length !== 1) throw new Error('expect 1 file in ' + dir);
  return new Int8Array(fs.readFileSync(path.join(dir, entries[0])));
}

function getRootKey(fdArr, salt) {
  // XOR fd[0]^fd[1]^fd[2]^comp
  let e = xor(fdArr[0], fdArr[1]);
  for (let i = 2; i < fdArr.length; i++) e = xor(e, fdArr[i]);
  e = xor(e, COMP);
  // 与 hvigor 一致：xorComponents 返回 Buffer.from(Int8Array)，再 .toString() = 原始字节 UTF-8 串
  const pwd = Buffer.from(e).toString();
  return new Int8Array(crypto.pbkdf2Sync(pwd, Buffer.from(salt), 10000, 16, 'sha256'));
}

function xor(t, r) {
  const out = new Int8Array(t.byteLength);
  for (let i = 0; i < t.byteLength; i++) out[i] = t[i] ^ r[i];
  return out;
}

function aesDecrypt(key, r) {
  // r: Int8Array。前4字节大端=密文长度，其后为nonce，再后密文，末尾16字节tag
  const len = (255 & r[0]) << 24 | (255 & r[1]) << 16 | (255 & r[2]) << 8 | (255 & r[3]);
  const nonceLen = r.length - 4 - len;
  const nonce = Buffer.from(r.slice(4, 4 + nonceLen));
  const tag = Buffer.from(r.slice(r.length - 16));
  const ct = Buffer.from(r.subarray(4 + nonceLen, r.length - 16));
  const d = crypto.createDecipheriv('aes-128-gcm', Buffer.from(key), nonce);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(ct), d.final()]);
}

function loadKey(materialDir) {
  const mdir = path.resolve(materialDir, 'material');
  const fdDir = path.resolve(mdir, 'fd');
  const fd = fs.readdirSync(fdDir).filter(x => x !== '.DS_Store');
  if (fd.length !== 3) throw new Error('fd must have 3 entries');
  const fdArr = fd.map(d => readDirBytes(path.join(fdDir, d)));
  const salt = readDirBytes(path.resolve(mdir, 'ac'));
  const ce = readDirBytes(path.resolve(mdir, 'ce'));
  const rootKey = getRootKey(fdArr, salt);
  const key = aesDecrypt(rootKey, ce);  // 真正的 AES-128 密钥
  return key;
}

function encrypt(key, plaintext) {
  const nonce = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-128-gcm', key, nonce);
  const ct = Buffer.concat([c.update(plaintext), c.final()]);
  const tag = c.getAuthTag();
  const head = Buffer.alloc(4);
  head.writeUInt32BE(ct.length + tag.length, 0);  // 头 = ct + tag 长度（11字节密码 -> 27 -> 0000001B）
  // 注意：没有额外前缀！0000001B 就是头本身
  return Buffer.concat([head, nonce, ct, tag]).toString('hex');
}

function decrypt(key, hexVal) {
  const r = new Int8Array(Buffer.from(hexVal, 'hex'));
  return aesDecrypt(key, r).toString('utf-8');
}

const mode = process.argv[2];
const arg = process.argv[3];
const matDir = process.argv[4] || 'C:/Users/Andy/caishen-app/material';

const key = loadKey(matDir);
console.log('AES key (hex):', key.toString('hex'));
if (mode === 'decrypt') {
  console.log('plaintext:', decrypt(key, arg));
} else if (mode === 'encrypt') {
  console.log('encrypted:', encrypt(key, arg));
}

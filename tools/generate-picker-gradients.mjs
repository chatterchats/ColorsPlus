// Deterministic RGBA assets; no image packages or external downloads required.
// Usage: node tools/generate-picker-gradients.mjs [--check] [Assets directory]
import {deflateSync, inflateSync} from 'node:zlib';
import {mkdirSync, readFileSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';
import assert from 'node:assert/strict';

const check = process.argv.includes('--check');
const args = process.argv.slice(2).filter(x => x !== '--check');
assert(args.length <= 1, 'Expected at most one Assets directory');
const output = args[0] ?? fileURLToPath(new URL('../src/ColorsPlus/Assets/', import.meta.url));
function crc32(data) {
  let crc = 0xffffffff;
  for (const byte of data) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const body = Buffer.concat([Buffer.from(type), data]);
  const size = Buffer.alloc(4); size.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body));
  return Buffer.concat([size, body, crc]);
}
function png(width, height, pixel) {
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width); header.writeUInt32BE(height, 4);
  header[8] = 8; header[9] = 6; // 8-bit RGBA, non-interlaced
  const raw = Buffer.alloc(height * (1 + width * 4));
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const rgba = pixel(x, y);
    assert(rgba.length === 4 && rgba.every(v => Number.isInteger(v) && v >= 0 && v <= 255));
    raw.set(rgba, y * (1 + width * 4) + 1 + x * 4);
  }
  const bytes = Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk('IHDR', header),
    chunk('IDAT', deflateSync(raw, {level: 9})), chunk('IEND', Buffer.alloc(0))]);
  return Object.assign(bytes, {header, raw});
}
// The header and the inflated pixels of a PNG with one IDAT chunk. --check compares these, not
// the file bytes: deflate output differs between zlib builds (zlib-ng on Fedora, zlib on Ubuntu).
function decode(file) {
  const chunks = {};
  for (let at = 8; at < file.length;) {
    const size = file.readUInt32BE(at), type = file.toString('latin1', at + 4, at + 8);
    assert(!(type in chunks), `PNG has more than one ${type} chunk`);
    chunks[type] = file.subarray(at + 8, at + 8 + size);
    at += 12 + size;
  }
  return {header: chunks.IHDR, raw: inflateSync(chunks.IDAT)};
}
function hue(x) {
  const h = x / 1023 * 6, sector = Math.floor(h) % 6, f = h - Math.floor(h);
  return [...[[1,f,0],[1-f,1,0],[0,1,f],[0,1-f,1],[f,0,1],[1,0,1-f]][sector]
    .map(v => Math.round(v * 255)), 255];
}
const saturation = x => [255,255,255,255-x];
const value = y => [0,0,0,y];
assert.deepEqual(saturation(0), [255,255,255,255]);
assert.deepEqual(saturation(255), [255,255,255,0]);
assert.deepEqual(value(0), [0,0,0,0]);
assert.deepEqual(value(255), [0,0,0,255]);
assert.deepEqual(hue(0), hue(1023));
assert(new Set(Array.from({length:1024}, (_,x) => hue(x).join(','))).size > 1000);
const assets = {'saturation.png':png(256,4,x=>saturation(x)),
  'value.png':png(4,256,(_,y)=>value(y)), 'hue.png':png(1024,8,hue)};
if (!check) mkdirSync(output, {recursive:true});
for (const [name, bytes] of Object.entries(assets)) {
  const path = join(output, name);
  if (check) {
    const found = decode(readFileSync(path));
    assert(found.header.equals(bytes.header) && found.raw.equals(bytes.raw), `Generated asset differs: ${path}`);
  }
  else writeFileSync(path, bytes);
}
console.log(`${check ? 'Verified' : 'Generated'} three picker gradients (${Object.values(assets).reduce((n,b)=>n+b.length,0)} bytes)`);

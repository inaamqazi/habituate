// Draws the app icon and launch logo as PNGs with no dependencies: node tools/make-icons.js
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const assets = path.join(__dirname, "..", "Habituate", "Resources", "Assets.xcassets");

const crcTable = new Uint32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
const crc32 = (buf) => {
  let c = 0xffffffff;
  for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};
const chunk = (type, data) => {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
};
const png = (size, rgba, hasAlpha) => {
  const channels = hasAlpha ? 4 : 3;
  const raw = Buffer.alloc((size * channels + 1) * size);
  for (let y = 0; y < size; y++) {
    raw[y * (size * channels + 1)] = 0;
    for (let x = 0; x < size; x++) {
      for (let c = 0; c < channels; c++) {
        raw[y * (size * channels + 1) + 1 + x * channels + c] = rgba[(y * size + x) * 4 + c];
      }
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8;
  ihdr[9] = hasAlpha ? 6 : 2;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
};

const clamp = (v) => Math.max(0, Math.min(1, v));
const segmentDistance = (px, py, ax, ay, bx, by) => {
  const dx = bx - ax, dy = by - ay;
  const t = clamp(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy));
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
};

// White ring with a tick inside, in a 1024 design space.
const markCoverage = (x, y) => {
  const ring = Math.abs(Math.hypot(x - 512, y - 512) - 330) - 34;
  const tick = Math.min(
    segmentDistance(x, y, 352, 528, 466, 642),
    segmentDistance(x, y, 466, 642, 690, 398)
  ) - 44;
  return clamp(0.5 - Math.min(ring, tick));
};

const draw = (size, withBackground) => {
  const scale = 1024 / size;
  const out = new Uint8Array(size * size * 4);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const dx = (x + 0.5) * scale, dy = (y + 0.5) * scale;
      const m = markCoverage(dx, dy);
      const i = (y * size + x) * 4;
      if (withBackground) {
        const t = (dx + dy) / 2048; // teal top-left to blue bottom-right
        const bg = [0x1f + (0x2f - 0x1f) * t, 0xc2 + (0x5b - 0xc2) * t, 0xa0 + (0xf0 - 0xa0) * t];
        for (let c = 0; c < 3; c++) out[i + c] = Math.round(bg[c] * (1 - m) + 255 * m);
        out[i + 3] = 255;
      } else {
        out[i] = out[i + 1] = out[i + 2] = 255;
        out[i + 3] = Math.round(m * 255);
      }
    }
  }
  return out;
};

fs.writeFileSync(path.join(assets, "AppIcon.appiconset", "AppIcon.png"), png(1024, draw(1024, true), false));
fs.writeFileSync(path.join(assets, "LaunchLogo.imageset", "LaunchLogo.png"), png(360, draw(360, false), true));
console.log("Icons written.");

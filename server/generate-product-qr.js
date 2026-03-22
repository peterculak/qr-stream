/**
 * generate-product-qr.js
 *
 * Generates test QR codes containing product data in the compact
 * ProductQR binary format (TLV + zlib compression).
 *
 * The QR code content is base64-encoded binary data that the
 * QRProductScanner iOS app can decode.
 *
 * Usage:
 *   npm install qrcode sharp   (one-time)
 *   node generate-product-qr.js
 *
 * Outputs:
 *   product-qr-*.png files in the current directory
 */

const zlib = require('zlib');
const fs = require('fs');
const path = require('path');

// Try to load optional dependencies
let QRCode, sharp;
try { QRCode = require('qrcode'); } catch (e) { /* optional */ }
try { sharp = require('sharp'); } catch (e) { /* optional */ }

// MARK: - TLV Tags (must match iOS ProductData.swift)
const TAG = {
  NAME:         0x01,
  THUMBNAIL:    0x02,
  CALORIES:     0x03,
  FAT:          0x04,
  CARBS:        0x05,
  PROTEIN:      0x06,
  SUGAR:        0x07,
  FIBER:        0x08,
  SODIUM:       0x09,
  SERVING_SIZE: 0x0A,
  BRAND:        0x0B,
  CATEGORY:     0x0C,
};

const MAGIC = Buffer.from([0x50, 0x51]); // "PQ"
const VERSION = 0x01;

// MARK: - TLV Encoding

function appendString(buf, tag, value) {
  if (!value) return buf;
  const encoded = Buffer.from(value, 'utf-8');
  const header = Buffer.alloc(3);
  header[0] = tag;
  header[1] = (encoded.length >> 8) & 0xFF;
  header[2] = encoded.length & 0xFF;
  return Buffer.concat([buf, header, encoded]);
}

function appendUInt16(buf, tag, value) {
  const chunk = Buffer.alloc(5);
  chunk[0] = tag;
  chunk[1] = 0x00;
  chunk[2] = 0x02;
  chunk[3] = (value >> 8) & 0xFF;
  chunk[4] = value & 0xFF;
  return Buffer.concat([buf, chunk]);
}

function appendData(buf, tag, data) {
  const header = Buffer.alloc(3);
  header[0] = tag;
  header[1] = (data.length >> 8) & 0xFF;
  header[2] = data.length & 0xFF;
  return Buffer.concat([buf, header, data]);
}

function encodeProduct(product, thumbnailBuffer) {
  let tlv = Buffer.alloc(0);

  tlv = appendString(tlv, TAG.NAME, product.name);
  tlv = appendString(tlv, TAG.BRAND, product.brand);
  tlv = appendString(tlv, TAG.CATEGORY, product.category);
  tlv = appendString(tlv, TAG.SERVING_SIZE, product.servingSize);
  tlv = appendUInt16(tlv, TAG.CALORIES, product.calories);
  tlv = appendUInt16(tlv, TAG.FAT, product.fat);       // grams × 10
  tlv = appendUInt16(tlv, TAG.CARBS, product.carbs);
  tlv = appendUInt16(tlv, TAG.PROTEIN, product.protein);
  tlv = appendUInt16(tlv, TAG.SUGAR, product.sugar);
  tlv = appendUInt16(tlv, TAG.FIBER, product.fiber);
  tlv = appendUInt16(tlv, TAG.SODIUM, product.sodium);

  if (thumbnailBuffer && thumbnailBuffer.length > 0) {
    tlv = appendData(tlv, TAG.THUMBNAIL, thumbnailBuffer);
  }

  // Compress TLV payload (Apple's COMPRESSION_ZLIB actually expects Raw Deflate RFC 1951)
  const compressed = zlib.deflateRawSync(tlv);

  // Build final binary: magic + version + compressed payload
  return Buffer.concat([MAGIC, Buffer.from([VERSION]), compressed]);
}

// MARK: - Generate a tiny JPEG thumbnail programmatically

async function generateTinyThumbnail(color, isGranola) {
  if (!sharp) {
    console.log('  ⚠ sharp not installed — skipping thumbnail');
    return null;
  }

  if (isGranola) {
    const brainImg = '/Users/peter2/.gemini/antigravity/brain/000848f8-b3dc-46ca-9066-828dd99501de/organic_granola_product_1774184750044.png';
    let rawImg;
    if (fs.existsSync(brainImg)) {
      rawImg = fs.readFileSync(brainImg);
    } else {
      console.log('  ⚠ Granola thumbnail source not found — using color fallback');
      return await generateTinyThumbnail(color, false);
    }
    const imageBuffer = await sharp(rawImg)
      .resize(32, 32)
      .png({ palette: true, colors: 16 })
      .toBuffer();
    console.log(`  📸 Real Thumbnail (PNG): ${imageBuffer.length} bytes`);
    return imageBuffer;
  }

  // Create a tiny 24x24 colored square as JPEG
  const { r, g, b } = color;
  const pixel = Buffer.alloc(24 * 24 * 3);
  for (let i = 0; i < 24 * 24; i++) {
    pixel[i * 3] = r;
    pixel[i * 3 + 1] = g;
    pixel[i * 3 + 2] = b;
  }

  const imageBuffer = await sharp(pixel, { raw: { width: 24, height: 24, channels: 3 } })
    .png()
    .toBuffer();

  console.log(`  📸 Thumbnail (PNG): ${imageBuffer.length} bytes`);
  return imageBuffer;
}

// MARK: - Sample Products

const products = [
  {
    name: 'Organic Granola',
    brand: 'Nature Valley',
    category: 'Cereal',
    servingSize: '45g',
    calories: 210,
    fat: 80,       // 8.0g
    carbs: 290,    // 29.0g
    protein: 50,   // 5.0g
    sugar: 120,    // 12.0g
    fiber: 35,     // 3.5g
    sodium: 140,   // mg
    color: { r: 200, g: 160, b: 50 },
  },
  {
    name: 'Greek Yogurt',
    brand: 'Chobani',
    category: 'Dairy',
    servingSize: '170g',
    calories: 100,
    fat: 0,        // 0.0g
    carbs: 60,     // 6.0g
    protein: 170,  // 17.0g
    sugar: 40,     // 4.0g
    fiber: 0,      // 0.0g
    sodium: 55,    // mg
    color: { r: 240, g: 240, b: 250 },
  },
  {
    name: 'Dark Chocolate',
    brand: 'Lindt',
    category: 'Confection',
    servingSize: '30g',
    calories: 170,
    fat: 130,      // 13.0g
    carbs: 130,    // 13.0g
    protein: 20,   // 2.0g
    sugar: 100,    // 10.0g
    fiber: 30,     // 3.0g
    sodium: 5,     // mg
    color: { r: 60, g: 30, b: 15 },
  },
];

// MARK: - Main

async function main() {
  console.log('🏭 ProductQR Generator\n');

  for (const product of products) {
    const thumbnail = await generateTinyThumbnail(product.color, product.name === 'Organic Granola');
    const binary = encodeProduct(product, thumbnail);
    const base64 = binary.toString('base64');

    console.log(`\n📦 ${product.name} (${product.brand})`);
    console.log(`  TLV size (uncompressed → compressed): check logs`);
    console.log(`  Final binary: ${binary.length} bytes`);
    console.log(`  Base64 length: ${base64.length} chars`);

    // Save base64 string to file for easy copy-paste
    const safeName = product.name.toLowerCase().replace(/\s+/g, '-');
    const publicDir = path.join(__dirname, 'public');
    if (!fs.existsSync(publicDir)) fs.mkdirSync(publicDir, { recursive: true });
    
    const txtFile = path.join(publicDir, `product-qr-${safeName}.txt`);
    fs.writeFileSync(txtFile, base64);
    console.log(`  💾 Saved: public/product-qr-${safeName}.txt`);

    // Generate QR code image if qrcode module is available
    if (QRCode) {
      const filename = path.join(publicDir, `product-qr-${safeName}.png`);
      await QRCode.toFile(filename, base64, {
        errorCorrectionLevel: 'L',
        margin: 2,
        width: 400,
        color: { dark: '#000000', light: '#FFFFFF' },
      });
      console.log(`  🖼  QR image: public/product-qr-${safeName}.png`);
    } else {
      console.log('  ⚠ qrcode module not installed — skipping QR image generation');
      console.log('  Run: npm install qrcode');
    }
  }

  console.log('\n✅ Done! Point the QR Product Scanner app at the generated QR codes.');
  if (!QRCode) {
    console.log('\n💡 You can also paste the base64 content from .txt files into any');
    console.log('   online QR code generator (e.g. qr-code-generator.com) to create');
    console.log('   scannable QR codes.');
  }
}

main().catch(console.error);

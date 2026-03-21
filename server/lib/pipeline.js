const zlib = require('zlib');
const crypto = require('crypto');

const PBKDF2_ITERATIONS = 100000;
const KEY_LENGTH = 32; // AES-256
const SALT_LENGTH = 16;
const IV_LENGTH = 12; // GCM standard
const AUTH_TAG_LENGTH = 16;

// Magic byte prefix to detect encrypted vs plain data
const ENCRYPTED_MAGIC = Buffer.from([0xE1, 0xC0]);
const PLAIN_MAGIC = Buffer.from([0xDA, 0x7A]);

/**
 * Compress → (optionally Encrypt) → Chunk pipeline
 *
 * @param {string} text - The plaintext to encode
 * @param {string} password - Encryption password (empty/null = no encryption)
 * @param {string} filename - Filename for the receiver to save as
 * @param {number} chunkSize - Max bytes per QR frame payload (before base64)
 * @returns {Promise<string[]>} Array of JSON strings, one per QR frame
 */
async function encode(text, password, filename = 'received.txt', chunkSize = 600) {
  // 1. Compress (raw deflate)
  const compressed = zlib.deflateRawSync(Buffer.from(text, 'utf-8'));

  let packed;

  if (password) {
    // 2a. Encrypt (AES-256-GCM)
    const salt = crypto.randomBytes(SALT_LENGTH);
    const key = crypto.pbkdf2Sync(password, salt, PBKDF2_ITERATIONS, KEY_LENGTH, 'sha256');
    const iv = crypto.randomBytes(IV_LENGTH);
    const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);

    const encrypted = Buffer.concat([cipher.update(compressed), cipher.final()]);
    const authTag = cipher.getAuthTag();

    // Pack: magic(2) + salt(16) + iv(12) + authTag(16) + ciphertext
    packed = Buffer.concat([ENCRYPTED_MAGIC, salt, iv, authTag, encrypted]);
  } else {
    // 2b. No encryption — just prefix with plain magic
    packed = Buffer.concat([PLAIN_MAGIC, compressed]);
  }

  // 3. Chunk
  const chunks = [];
  for (let offset = 0; offset < packed.length; offset += chunkSize) {
    chunks.push(packed.slice(offset, offset + chunkSize));
  }

  // 4. Frame format: JSON with index, total, base64 data, and filename
  const totalFrames = chunks.length;
  const frames = chunks.map((chunk, i) =>
    JSON.stringify({ i, n: totalFrames, f: filename, d: chunk.toString('base64') })
  );

  return frames;
}

/**
 * Reassemble → Decrypt → Decompress pipeline (for testing / verification)
 *
 * @param {string[]} frames - Array of JSON frame strings
 * @param {string} password - Decryption password (empty/null if not encrypted)
 * @returns {string} Original plaintext
 */
function decode(frames, password) {
  // 1. Parse & sort frames
  const parsed = frames
    .map((f) => JSON.parse(f))
    .sort((a, b) => a.i - b.i);

  // 2. Reassemble
  const packed = Buffer.concat(parsed.map((f) => Buffer.from(f.d, 'base64')));

  // 3. Check magic bytes
  const magic = packed.slice(0, 2);
  const isEncrypted = magic.equals(ENCRYPTED_MAGIC);

  let compressed;

  if (isEncrypted) {
    // 4a. Unpack encrypted: magic(2) + salt(16) + iv(12) + authTag(16) + ciphertext
    const offset = 2;
    const salt = packed.slice(offset, offset + SALT_LENGTH);
    const iv = packed.slice(offset + SALT_LENGTH, offset + SALT_LENGTH + IV_LENGTH);
    const authTag = packed.slice(
      offset + SALT_LENGTH + IV_LENGTH,
      offset + SALT_LENGTH + IV_LENGTH + AUTH_TAG_LENGTH
    );
    const ciphertext = packed.slice(offset + SALT_LENGTH + IV_LENGTH + AUTH_TAG_LENGTH);

    const key = crypto.pbkdf2Sync(password, salt, PBKDF2_ITERATIONS, KEY_LENGTH, 'sha256');
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(authTag);
    compressed = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
  } else {
    // 4b. Plain: magic(2) + compressed
    compressed = packed.slice(2);
  }

  // 5. Decompress
  const text = zlib.inflateRawSync(compressed).toString('utf-8');
  return text;
}

module.exports = { encode, decode, PBKDF2_ITERATIONS, KEY_LENGTH, SALT_LENGTH, IV_LENGTH, AUTH_TAG_LENGTH, ENCRYPTED_MAGIC, PLAIN_MAGIC };

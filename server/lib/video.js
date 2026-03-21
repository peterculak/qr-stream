const QRCode = require('qrcode');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { v4: uuidv4 } = require('uuid');

/**
 * Generate an MP4 video of QR code frames.
 *
 * @param {string[]} frames - Array of JSON strings (one per QR frame)
 * @param {object} opts
 * @param {number} opts.fps - Frames per second (default 3)
 * @param {number} opts.loops - How many times to loop the sequence (default 3)
 * @param {number} opts.qrSize - QR image pixel size (default 800)
 * @returns {Promise<string>} Path to the generated MP4 file
 */
async function generateVideo(frames, { fps = 3, loops = 3, qrSize = 800 } = {}) {
    const tmpDir = path.join(os.tmpdir(), `qrstream-${uuidv4()}`);
    fs.mkdirSync(tmpDir, { recursive: true });

    // Build the full sequence (looped)
    const allFrames = [];
    for (let l = 0; l < loops; l++) {
        allFrames.push(...frames);
    }

    // Generate QR PNG for each frame
    for (let idx = 0; idx < allFrames.length; idx++) {
        const pngPath = path.join(tmpDir, `frame_${String(idx).padStart(6, '0')}.png`);
        await QRCode.toFile(pngPath, allFrames[idx], {
            type: 'png',
            width: qrSize,
            margin: 2,
            errorCorrectionLevel: 'M',
            color: { dark: '#000000', light: '#ffffff' },
        });
    }

    // Stitch into MP4 using ffmpeg
    const outputPath = path.join(tmpDir, 'output.mp4');
    const ffmpegCmd = [
        'ffmpeg',
        '-y',
        '-framerate', String(fps),
        '-i', path.join(tmpDir, 'frame_%06d.png'),
        '-c:v', 'libx264',
        '-pix_fmt', 'yuv420p',
        '-preset', 'fast',
        '-crf', '18',
        outputPath,
    ].join(' ');

    execSync(ffmpegCmd, { stdio: 'pipe' });

    // Clean up PNGs (keep the mp4)
    const pngs = fs.readdirSync(tmpDir).filter((f) => f.endsWith('.png'));
    for (const png of pngs) {
        fs.unlinkSync(path.join(tmpDir, png));
    }

    return outputPath;
}

module.exports = { generateVideo };

const QRCode = require('qrcode');
const sharp = require('sharp');
const { execFileSync } = require('child_process');
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
 * @param {number} opts.tiles - Number of tiles per frame (1, 2, or 4)
 * @returns {Promise<string>} Path to the generated MP4 file
 */
async function generateVideo(frames, { fps = 3, loops = 3, qrSize = 800, tiles = 1 } = {}) {
    const tmpDir = path.join(os.tmpdir(), `qrstream-${uuidv4()}`);
    fs.mkdirSync(tmpDir, { recursive: true });

    // Build the full sequence (looped and shuffled!)
    const allFrames = [];
    for (let l = 0; l < loops; l++) {
        // Shuffle frames on every loop except the very first one
        // This stops "resonance" where the camera consistently misses the same frame position
        let currentLoopFrames = [...frames];
        if (l > 0) {
            for (let i = currentLoopFrames.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [currentLoopFrames[i], currentLoopFrames[j]] = [currentLoopFrames[j], currentLoopFrames[i]];
            }
        }
        allFrames.push(...currentLoopFrames);
    }

    // Group frames by tiles per frame
    const tileGroups = [];
    for (let i = 0; i < allFrames.length; i += tiles) {
        tileGroups.push(allFrames.slice(i, i + tiles));
    }

    // Composite logic
    let cols = 1, rows = 1, singleQrSize = qrSize;

    if (tiles === 2) { cols = 2; rows = 1; singleQrSize = qrSize / 2; } // 2x1 grid
    else if (tiles === 4) { cols = 2; rows = 2; singleQrSize = qrSize / 2; } // 2x2 grid
    else if (tiles === 8) { cols = 4; rows = 2; singleQrSize = qrSize / 2; } // 4x2 grid

    const canvasWidth = cols * singleQrSize;
    const canvasHeight = rows * singleQrSize;

    // Generate QR PNG for each frame group
    for (let idx = 0; idx < tileGroups.length; idx++) {
        const group = tileGroups[idx];
        const buffers = [];

        // Generate base QR buffers
        for (const frameStr of group) {
            const buf = await QRCode.toBuffer(frameStr, {
                type: 'png',
                width: singleQrSize,
                margin: 2,
                errorCorrectionLevel: 'M', // 'M' balances huge optical dots with the algorithmic Fountain Engine resilience
                color: { dark: '#000000', light: '#ffffff' },
            });
            buffers.push(buf);
        }

        const compositeOperations = [];
        for (let i = 0; i < buffers.length; i++) {
            compositeOperations.push({
                input: buffers[i],
                left: (i % cols) * singleQrSize,
                top: Math.floor(i / cols) * singleQrSize
            });
        }

        const pngPath = path.join(tmpDir, `frame_${String(idx).padStart(6, '0')}.png`);
        await sharp({
            create: {
                width: canvasWidth,
                height: canvasHeight,
                channels: 3,
                background: { r: 255, g: 255, b: 255 }
            }
        })
            .composite(compositeOperations)
            .toFile(pngPath);
    }

    // Stitch into MP4 using ffmpeg
    // Note: ensure width/height are even numbers for yuv420p!
    const outputPath = path.join(tmpDir, 'output.mp4');
    const ffmpegArgs = [
        '-y',
        '-framerate', String(fps),
        '-i', path.join(tmpDir, 'frame_%06d.png'),
        '-c:v', 'libx264',
        '-pix_fmt', 'yuv420p',
        '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2',
        '-preset', 'fast',
        '-crf', '12',             // near-lossless to prevent blurring QR codes
        '-g', '1',                // Intraframes only! Eliminates inter-frame ghosting which ruins camera scans
        '-tune', 'animation',     // optimize for sharp edges
        outputPath,
    ];

    execFileSync('ffmpeg', ffmpegArgs, { stdio: 'pipe' });

    // Clean up PNGs (keep the mp4)
    const pngs = fs.readdirSync(tmpDir).filter((f) => f.endsWith('.png'));
    for (const png of pngs) {
        fs.unlinkSync(path.join(tmpDir, png));
    }

    return outputPath;
}

module.exports = { generateVideo };

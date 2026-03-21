const express = require('express');
const path = require('path');
const fs = require('fs');
const { encode } = require('./lib/pipeline');
const { generateVideo } = require('./lib/video');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json({ limit: '5mb' }));
app.use(express.static(path.join(__dirname, 'public')));

app.post('/api/encode', async (req, res) => {
    try {
        const { text, password, fps, filename, tiles, missingFrames } = req.body;

        if (!text) {
            return res.status(400).json({ error: 'text is required' });
        }

        const selectedFps = Math.min(Math.max(parseInt(fps) || 3, 1), 10);
        // Ensure tiles is exactly 1, 2, 4, or 8
        const selectedTiles = [1, 2, 4, 8].includes(parseInt(tiles)) ? parseInt(tiles) : 1;
        const selectedFilename = filename || 'received.txt';

        // Scale the drop packet size based on the structural grid density
        // A 1x tile can easily hold 600 bytes. An 8x tile squashes the barcode to 1/4 the screen width,
        // so to keep the dots visually gargantuan, we clamp the byte size respectively.
        let dynamicChunkSize = 600;
        if (selectedTiles === 2) dynamicChunkSize = 350;
        if (selectedTiles === 4) dynamicChunkSize = 200;
        if (selectedTiles === 8) dynamicChunkSize = 100;

        // Pipeline: compress → (encrypt) → chunk → QR frames
        const frames = await encode(text, password || null, selectedFilename, dynamicChunkSize, missingFrames);
        console.log(`Generated ${frames.length} drops (dynamic size: ${dynamicChunkSize} bytes)`);

        // Generate video
        const videoPath = await generateVideo(frames, { fps: selectedFps, tiles: selectedTiles });
        console.log(`Video created: ${videoPath}`);

        // Stream the file back and clean up
        res.setHeader('Content-Type', 'video/mp4');
        res.setHeader('Content-Disposition', 'attachment; filename="qr-stream.mp4"');

        const stream = fs.createReadStream(videoPath);
        stream.pipe(res);
        stream.on('end', () => {
            const tmpDir = path.dirname(videoPath);
            fs.rmSync(tmpDir, { recursive: true, force: true });
        });
    } catch (err) {
        console.error('Encode error:', err);
        res.status(500).json({ error: err.message });
    }
});

app.listen(PORT, () => {
    console.log(`QR Stream server running on http://localhost:${PORT}`);
});

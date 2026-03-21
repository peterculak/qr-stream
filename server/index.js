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
        const { text, password, fps, filename } = req.body;

        if (!text) {
            return res.status(400).json({ error: 'text is required' });
        }

        const selectedFps = Math.min(Math.max(parseInt(fps) || 3, 1), 10);
        const selectedFilename = filename || 'received.txt';

        console.log(`Encoding ${text.length} chars, fps=${selectedFps}, encrypted=${!!password}, filename=${selectedFilename}`);

        // Pipeline: compress → (encrypt) → chunk → QR frames
        const frames = await encode(text, password || null, selectedFilename);
        console.log(`Generated ${frames.length} frames`);

        // Generate video
        const videoPath = await generateVideo(frames, { fps: selectedFps });
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

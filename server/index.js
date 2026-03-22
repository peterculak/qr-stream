const express = require('express');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const { encode } = require('./lib/pipeline');
const { generateVideo } = require('./lib/video');

const app = express();
const PORT = process.env.PORT || 3000;

// Temporary session storage for live streaming (in-memory)
const activeSessions = new Map();

app.use(express.json({ limit: '50mb' })); // Increased limit for larger files
app.use(express.static(path.join(__dirname, 'public')));

// Initialize a streaming session (POST to handle large payloads)
app.post('/api/stream-init', (req, res) => {
    const sid = uuidv4();
    activeSessions.set(sid, {
        params: req.body,
        timestamp: Date.now()
    });
    
    // Auto-cleanup after 5 minutes
    setTimeout(() => activeSessions.delete(sid), 5 * 60 * 1000);
    
    res.json({ sid });
});

// SSE Streaming Endpoint (Live Image Mode - using Session ID)
app.get('/api/stream', async (req, res) => {
    const { sid } = req.query;
    const session = activeSessions.get(sid);

    if (!session) {
        return res.status(404).json({ error: 'Session expired or not found' });
    }

    const { text, password, filename, chunkSize, loops } = session.params;

    // Set SSE headers
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    try {
        const dynamicChunkSize = parseInt(chunkSize) || 600;
        const selectedLoops = parseInt(loops) || 1;
        
        // Use existing encode logic
        const frames = await encode(text, password || null, filename || 'received.txt', dynamicChunkSize);
        
        // Clean up session early if we have everything
        activeSessions.delete(sid);

        // Send meta-information first
        res.write(`event: init\ndata: ${JSON.stringify({ totalFrames: frames.length, loops: selectedLoops })}\n\n`);

        // Stream the frame data
        for (let i = 0; i < frames.length; i++) {
            res.write(`event: frame\ndata: ${frames[i]}\n\n`);
        }

        res.write('event: end\ndata: done\n\n');
        res.end();
    } catch (err) {
        console.error('Streaming error:', err);
        res.write(`event: error\ndata: ${err.message}\n\n`);
        res.end();
    }
});

app.post('/api/encode', async (req, res) => {
    try {
        const { text, password, fps, filename, tiles, missingFrames, chunkSize, loops } = req.body;

        if (!text) {
            return res.status(400).json({ error: 'text is required' });
        }

        const selectedFps = Math.min(Math.max(parseInt(fps) || 3, 1), 10);
        const selectedTiles = [1, 2, 4, 8].includes(parseInt(tiles)) ? parseInt(tiles) : 1;
        const selectedLoops = parseInt(loops) || 3;
        const selectedFilename = filename || 'received.txt';
        const dynamicChunkSize = parseInt(chunkSize) || 1500;

        // Pipeline: compress → (encrypt) → chunk → QR frames
        const frames = await encode(text, password || null, selectedFilename, dynamicChunkSize, missingFrames);
        console.log(`Generated ${frames.length} drops (dynamic size: ${dynamicChunkSize} bytes)`);

        // Generate video
        const videoPath = await generateVideo(frames, { 
            fps: selectedFps, 
            tiles: selectedTiles, 
            loops: selectedLoops 
        });
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

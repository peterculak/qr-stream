const fs = require('fs');
const qrcode = require('qrcode');
const path = require('path');

async function generateMultiQR() {
    const html = fs.readFileSync(path.join(__dirname, '../ultra_min_tetris.html'), 'utf8');
    const base64 = Buffer.from(html).toString('base64');
    
    // Chunk size (1000 is safer for camera resolution than 1200)
    const CHUNK_SIZE = 1000;
    const total = Math.ceil(base64.length / CHUNK_SIZE);
    
    console.log(`Payload: ${html.length} bytes -> ${base64.length} base64 bytes. Total chunks: ${total}`);
    
    for (let i = 0; i < total; i++) {
        const chunk = base64.slice(i * CHUNK_SIZE, (i + 1) * CHUNK_SIZE);
        const payload = `AR:${i}:${total}:${chunk}`;
        const filename = `tetris_qr_${i}.png`;
        const outputPath = path.join(__dirname, '../public', filename);
        
        await qrcode.toFile(outputPath, payload, {
            errorCorrectionLevel: 'L',
            margin: 2,
            scale: 8,
            color: { dark: '#000000', light: '#ffffff' }
        });
        console.log(`Saved: ${filename} (Payload size: ${payload.length})`);
    }
    
    // Also save a combined reference for display
    console.log(`--- MULTI-扫码 COMPLETE ---`);
    console.log(`Scan chunks in order to load the High-Fidelity AR App.`);
}

generateMultiQR().catch(console.error);

const QRCode = require('qrcode');
const fs = require('fs');
const path = require('path');

// Re-generate the exactly the same payload for consistency
const htmlPath = path.join(__dirname, '../ultra_min_tetris.html');
const htmlContent = fs.readFileSync(htmlPath, 'utf8');
const base64Content = Buffer.from(htmlContent).toString('base64');
const payload = `APP:${base64Content}`;

const outputPath = path.join(__dirname, '../public/tetris_qr.png');

QRCode.toFile(outputPath, payload, {
    errorCorrectionLevel: 'L',
    width: 600,
    margin: 4,
    color: {
        dark: '#000000',
        light: '#FFFFFF'
    }
}, function (err) {
    if (err) throw err;
    console.log('--- QR IMAGE GENERATED ---');
    console.log(`Saved to: ${outputPath}`);
    console.log('--- END ---');
});

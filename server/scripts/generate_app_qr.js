const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '../ultra_min_tetris.html');
if (!fs.existsSync(filePath)) {
    console.error('Error: ultra_min_tetris.html not found.');
    process.exit(1);
}

const htmlContent = fs.readFileSync(filePath, 'utf8');
const base64Content = Buffer.from(htmlContent).toString('base64');
const finalPayload = `APP:${base64Content}`;

console.log('\n--- SINGLE-QR AR APP PAYLOAD ---');
console.log(finalPayload);
console.log('--- END PAYLOAD ---\n');
console.log(`Total Length: ${finalPayload.length} characters`);

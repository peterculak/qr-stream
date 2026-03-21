# QR Stream
Stream raw binary files from your monitor to your iPhone using ultra-dense 8x QR Code matrices. Completely air-gapped data transfer.

## Features
- **High-Density Payload Engine**: Groups up to 8x QR chunks into a single dynamic 4x2 matrix grid on screen instantly using Node `sharp`.
- **Landscape iOS Scanner**: Natively tracks widescreen 1600x800 QR Grids using automatic hardware `AVCaptureVideoOrientation` mapping.
- **Manual Rescue Backchannel**: Visually surfaces dropped frame coordinates directly on the iOS interface, allowing targeted re-broadcasts via the web app to manually bypass the Coupon Collector's problem instantly.
- **Max Compression**: Level 9 Zlib deflation on all payloads.

## Usage
1. `cd server` & `npm install`
2. `npm start`
3. Open `http://localhost:3000`
4. Rebuild the `QRStream` iOS app in Xcode.

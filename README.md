# [ QR STREAM ] 

A retro-futuristic, fully air-gapped file transfer system that uses animated QR codes to broadcast documents, images, and text directly from a web browser to an iOS device. 

## Features

- **100% Air-Gapped**: Transfer files to your phone without Bluetooth, Airdrop, Wi-Fi, or cables. The data is entirely encoded within the visual QR stream.
- **Support for All Files**: Transfer `.docx`, `.pdf`, `.zip`, `.png`, and plain text. Binary files are correctly encoded in Base64 streams and saved exactly as is.
- **AES-256 Encryption**: Secure your transfers with an optional password. Your payload is encrypted in the browser before ever being converted into a video stream.
- **80s Mono-Terminal Aesthetic**: Immersive green-on-black UI with scanning readouts and retro ASCII progress bars.
- **Native File Management**: Decoded files are saved straight into your iOS `Documents` directory, making them accessible via the native iOS **Files app**.

## How it works

1. **Upload & Encode**: Drop a file into the web UI (`localhost:3000`).
2. **Compress & Encrypt**: The Node.js server compresses the file using `zlib` (raw deflate) and encrypts it (AES-256-GCM) if a password is provided.
3. **Chunking**: The payload is split into small chunks, and each chunk is wrapped in a JSON envelope with an index and metadata: `{"i": 0, "n": 50, "f": "document.pdf", "d": "base64..."}`.
4. **Broadcast**: `ffmpeg` generates an MP4 video out of the QR codes representing each chunk. 
5. **Scan & Assemble**: The iOS app rapidly scans the streaming video, intelligently reassembling chunks out-of-order, verifying completion, and extracting the raw file.

## Setup Instructions

### Web / Server
```bash
cd server
npm install
node index.js
```
*The server will run on `http://localhost:3000`.*

### iOS App
Open `ios/QRStream/QRStream.xcodeproj` in Xcode.
Build and run the application on a physical iOS device (a physical camera is required for scanning).

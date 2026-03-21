# QR Stream Architecture Guide

## Overview

QR Stream is a data transfer system that encodes arbitrary text data into a sequence of QR codes displayed as a video. A dedicated iOS application scans these QR codes in real-time and reconstructs the original data.

## System Components

### 1. Server (Node.js + Express)

The server provides an HTTP API and web interface for encoding data. The encoding pipeline follows these steps:

1. **Compression**: The input text is compressed using raw deflate (zlib) to reduce size
2. **Encryption** (Optional): If a password is provided, the compressed data is encrypted using AES-256-GCM with a PBKDF2-derived key
3. **Chunking**: The payload is split into chunks of approximately 600 bytes each
4. **QR Generation**: Each chunk is encoded as a JSON frame and rendered as a QR code image
5. **Video Assembly**: All QR frames are stitched into a looping MP4 video using ffmpeg

### 2. iOS Client (Swift + SwiftUI)

The iOS application provides a camera-based QR code scanner that:

- Continuously scans for QR codes using AVFoundation
- Parses each scanned code as a JSON frame with index, total count, filename, and payload
- Deduplicates and assembles chunks in order
- Detects whether data is encrypted via magic bytes (0xE1C0 for encrypted, 0xDA7A for plain)
- Decrypts using AES-256-GCM if needed
- Decompresses using zlib
- Saves the result as a file in the app's Documents directory

### 3. Wire Format

Each QR code frame contains a JSON object:

```json
{
  "i": 0,
  "n": 5,
  "f": "document.md",
  "d": "base64encodeddata..."
}
```

Where:
- `i` = frame index (0-based)
- `n` = total number of frames
- `f` = suggested filename
- `d` = base64-encoded chunk data

### 4. Security

The encryption uses industry-standard algorithms:
- **Key Derivation**: PBKDF2 with SHA-256, 100,000 iterations
- **Encryption**: AES-256-GCM (authenticated encryption)
- **Parameters**: 16-byte salt, 12-byte IV, 16-byte auth tag

### 5. Performance Characteristics

| Parameter | Value |
|-----------|-------|
| Chunk size | ~600 bytes |
| QR version | ~20-25 |
| Default FPS | 3 |
| Throughput | ~1.8 KB/sec |
| Error correction | Medium (M) |
| Video loops | 3x |

## Getting Started

### Prerequisites
- Node.js 18+
- ffmpeg installed
- Xcode 15+ for iOS development
- Physical iPhone for testing (camera required)

### Quick Start

1. Start the server: `cd server && npm start`
2. Open http://localhost:3000
3. Paste your text content
4. Optionally set a password and filename
5. Click Generate to create the QR video
6. Open the iOS app on your iPhone
7. Enter the password (if used)
8. Point your phone at the screen
9. Watch the progress bar fill up
10. Find your file in the Files tab

## Troubleshooting

- If scanning is slow, try reducing FPS or increasing screen brightness
- If decryption fails, verify the password matches exactly
- Large documents may take several scanning passes through the video loop
- Ensure good lighting and steady camera positioning for best results

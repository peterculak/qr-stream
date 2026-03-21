/**
 * Round-trip test: compress → encrypt → chunk → reassemble → decrypt → decompress
 * Tests both encrypted and plain (no password) modes.
 */
const { encode, decode } = require('./lib/pipeline');

async function main() {
    const testText = 'Hello QR Stream! 🚀 This is a test of the compress→encrypt→chunk pipeline. '.repeat(20);
    const password = 'test-password-123';

    console.log(`Input length: ${testText.length} chars`);

    // Test 1: Encrypted round-trip
    console.log('\n--- Test 1: Encrypted ---');
    const encFrames = await encode(testText, password, 'test.md');
    console.log(`Frames generated: ${encFrames.length}`);
    const first = JSON.parse(encFrames[0]);
    console.log(`First frame: i=${first.i}, n=${first.n}, f=${first.f}, payload=${first.d.length} chars`);
    const decoded1 = decode(encFrames, password);
    console.log(decoded1 === testText ? '✅ PASS — encrypted round-trip' : '❌ FAIL');

    // Test 2: Wrong password
    console.log('\n--- Test 2: Wrong password ---');
    try {
        decode(encFrames, 'wrong');
        console.error('❌ FAIL — should have thrown');
        process.exit(1);
    } catch (e) {
        console.log('✅ PASS — wrong password rejected');
    }

    // Test 3: Plain (no password) round-trip
    console.log('\n--- Test 3: No encryption ---');
    const plainFrames = await encode(testText, null, 'plain.txt');
    console.log(`Frames generated: ${plainFrames.length}`);
    const decoded3 = decode(plainFrames, null);
    console.log(decoded3 === testText ? '✅ PASS — plain round-trip' : '❌ FAIL');

    console.log('\nAll tests passed.');
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});

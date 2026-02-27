# Audio Processing

@Metadata {
    @PageKind(article)
}

Convert audio formats, measure loudness, detect silence, and mix channels.

## Overview

HLSKit provides a suite of audio processing tools for preparing content before encoding and delivery. All types are `Sendable` and operate on raw PCM `Data` buffers.

### Format Conversion

``AudioFormatConverter`` converts between PCM audio formats — bit depth, sample layout (interleaved vs planar), and endianness:

```swift
let converter = AudioFormatConverter()
let output = try converter.convert(
    data: pcmData,
    from: .init(sampleFormat: .int16, layout: .interleaved, endianness: .little),
    to: .init(sampleFormat: .float32, layout: .interleaved, endianness: .native)
)
```

### Sample Rate Conversion

``SampleRateConverter`` resamples audio between standard rates using configurable interpolation:

```swift
let converter = SampleRateConverter()
let output = try converter.convert(
    data: pcmData,
    from: 44100,
    to: 48000,
    channels: 2,
    quality: .sinc
)
```

Quality options: `.linear`, `.sinc`, `.lanczos`.

### Channel Mixing

``ChannelMixer`` handles mono ↔ stereo conversion and surround downmix:

```swift
let mixer = ChannelMixer()

// Mono to stereo
let stereo = try mixer.monoToStereo(data: monoData, mode: .duplicate)

// 5.1 to stereo downmix
let downmixed = try mixer.downmix(
    data: surroundData,
    from: .surround5_1,
    to: .stereo
)
```

### Level Metering

``LevelMeter`` measures audio signal levels per channel — RMS, peak, and true peak per ITU-R BS.1770:

```swift
let meter = LevelMeter()
let levels = meter.measure(
    data: pcmData,
    channels: 2,
    sampleFormat: .float32
)
// levels[0].rmsDB, levels[0].peakDB, levels[0].truePeakDB
```

``ChannelLevel`` contains the per-channel results.

### Loudness Measurement

``LoudnessMeter`` measures loudness per EBU R 128 / ITU-R BS.1770-4 with momentary, short-term, and integrated readings:

```swift
let meter = LoudnessMeter()
let result = meter.measure(
    data: pcmData,
    sampleRate: 48000,
    channels: 2
)
// result.integratedLoudness — LUFS
// result.momentaryMax — peak momentary loudness
// result.loudnessRange — LRA
```

``LoudnessResult`` and ``GatingBlock`` provide the detailed measurement data.

### Loudness Normalization

``AudioNormalizer`` adjusts audio levels to match target loudness presets:

```swift
let normalizer = AudioNormalizer()
let result = try normalizer.normalize(
    data: pcmData,
    channels: 2,
    sampleRate: 48000,
    preset: .podcast  // -16 LUFS
)
```

``NormalizationPreset`` targets: `.podcast` (-16 LUFS), `.music` (-14 LUFS), `.broadcast` (-24 LUFS), `.streaming` (-14 LUFS).

### Silence Detection

``SilenceDetector`` finds silent regions in audio data:

```swift
let detector = SilenceDetector()
let regions = detector.detect(
    data: pcmData,
    sampleRate: 48000,
    channels: 2,
    thresholdDB: -40.0,
    minimumDuration: 0.5
)
for region in regions {
    print("Silence: \(region.startTime)s — \(region.endTime)s")
}
```

``SilenceRegion`` describes each detected silent interval.

## Next Steps

- <doc:LiveEncoding> — Encode processed audio for live delivery
- <doc:LiveStreaming> — Complete pipeline with audio processing
- <doc:SpatialAudio> — Spatial and surround audio capabilities

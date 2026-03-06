# Transport Contracts v2

Understand how HLSKit models quality monitoring, adaptive bitrate recommendations, and unified event streams for RTMP, SRT, and Icecast push delivery.

@Metadata {
    @PageKind(article)
}

## Overview

Transport Contracts v2 extends HLSKit's push delivery system with quality monitoring, adaptive bitrate recommendations, and unified event streams. In v1, transport protocols (``RTMPTransport``, ``SRTTransport``, ``IcecastTransport``) focused purely on data delivery. v2 adds three new protocol layers -- ``QualityAwareTransport``, ``AdaptiveBitrateTransport``, and ``RecordingTransport`` -- that enable the ``LivePipeline`` to react automatically to changing network conditions.

The design follows a dependency injection pattern: HLSKit defines the contracts, and optional companion libraries from the Atelier Socle ecosystem provide concrete implementations. HLSKit never imports RTMPKit, SRTKit, or IcecastKit directly. The companion library bridges supply concrete conformances, and you wire them to the pipeline at startup through ``LivePipelineConfiguration/transportPolicy``. This keeps the core library free of third-party dependencies while enabling deep integration.

## Architecture

The Transport Contracts v2 architecture separates protocol definition from implementation across three layers:

1. **HLSKit** defines the protocol contracts: ``QualityAwareTransport``, ``AdaptiveBitrateTransport``, and ``RecordingTransport``. These protocols live alongside the value types they use (``TransportQuality``, ``TransportEvent``, ``TransportBitrateRecommendation``, ``TransportStatisticsSnapshot``, ``TransportRecordingState``).

2. **Companion libraries** (swift-rtmp-kit, swift-srt-kit, swift-icecast-kit) wrap their internal streaming SDKs and adopt HLSKit's protocols. Each companion provides a bridge module that converts its native metrics into HLSKit's unified types.

3. **``TransportAwarePusher``** wraps any ``SegmentPusher`` together with optional ``QualityAwareTransport`` and ``AdaptiveBitrateTransport`` conformances, exposing transport health to the pipeline without coupling the pusher to a specific transport implementation.

The three v2 protocols compose independently. A transport can adopt any combination:

```swift
// QualityAwareTransport provides quality monitoring
public protocol QualityAwareTransport: Sendable {
    var connectionQuality: TransportQuality? { get async }
    var transportEvents: AsyncStream<TransportEvent> { get }
    var statisticsSnapshot: TransportStatisticsSnapshot? { get async }
}

// AdaptiveBitrateTransport adds ABR recommendations
public protocol AdaptiveBitrateTransport: Sendable {
    var bitrateRecommendations: AsyncStream<TransportBitrateRecommendation> { get }
}

// RecordingTransport adds recording capability
public protocol RecordingTransport: Sendable {
    var recordingState: TransportRecordingState? { get async }
    func startRecording(directory: String) async throws
    func stopRecording() async throws
}
```

``TransportAwarePusher`` accepts all three as optional constructor arguments, so you can incrementally add capabilities as your transport library matures.

## Quality Monitoring

``TransportQuality`` is the normalized view of a connection's health at a point in time. All transport protocols surface quality through this common type so that ``LivePipeline`` can make decisions without knowing which protocol is in use. It carries four properties: `score` (`Double`, 0.0--1.0 composite quality), `grade` (``TransportQualityGrade``), `recommendation` (`String?` with actionable text from the transport layer), and `timestamp` (`Date`).

```swift
let quality = TransportQuality(
    score: 0.95,
    grade: .excellent,
    recommendation: nil,
    timestamp: Date()
)

// Grade can also be derived from score
let grade = TransportQualityGrade(score: 0.85)  // .good

// Grades are Comparable
if quality.grade < .good {
    print("Quality degraded: \(quality.recommendation ?? "No details")")
}
```

``TransportQualityGrade`` maps numeric scores to five ordered grades. The enum is `Comparable`, so the pipeline can compare grades against a minimum threshold without inspecting raw scores:

| Grade | Score range | Meaning |
| --- | --- | --- |
| `.excellent` | score > 0.9 | Optimal conditions |
| `.good` | score > 0.7 | Minor issues possible |
| `.fair` | score > 0.5 | Noticeable degradation |
| `.poor` | score > 0.3 | Significant issues |
| `.critical` | score <= 0.3 | Imminent failure |

``TransportBitrateRecommendation`` carries a structured suggestion from the transport layer about encoder bitrate. The ``TransportBitrateRecommendation/Direction`` enum (`increase`, `decrease`, `maintain`) expresses intent without requiring the pipeline to compute deltas. The `confidence` property (0.0--1.0) indicates how certain the transport is about the recommendation.

```swift
let recommendation = TransportBitrateRecommendation(
    recommendedBitrate: 2_000_000,
    currentEstimatedBitrate: 3_500_000,
    direction: .decrease,
    reason: "Congestion detected on RTMP link",
    confidence: 0.87,
    timestamp: Date()
)
```

The ``LivePipeline`` uses consecutive same-direction recommendations against a threshold controlled by ``TransportAwarePipelinePolicy/abrResponsiveness``.

## Transport Events

``TransportEvent`` is the unified event enum that all quality-aware transports emit through ``QualityAwareTransport/transportEvents``. The pipeline consumes this `AsyncStream` and routes each case to the appropriate handler. There are exactly seven cases:

| Case | Payload | When emitted |
| --- | --- | --- |
| `.connected(transportType:)` | Transport name (`String`) | Transport connected successfully |
| `.disconnected(transportType:error:)` | Transport name, optional error | Transport disconnected |
| `.reconnecting(transportType:attempt:)` | Transport name, 1-based attempt (`Int`) | Reconnection in progress |
| `.qualityChanged(_:)` | ``TransportQuality`` | Quality score changed |
| `.bitrateRecommendation(_:)` | ``TransportBitrateRecommendation`` | ABR signal available |
| `.statisticsUpdated(_:)` | ``TransportStatisticsSnapshot`` | Periodic stats refresh |
| `.recordingStateChanged(_:)` | ``TransportRecordingState`` | Recording status changed |

Subscribe to events with a standard `for await` loop:

```swift
for await event in transport.transportEvents {
    switch event {
    case .connected(let type):
        print("Connected via \(type)")
    case .qualityChanged(let quality):
        print("Quality: \(quality.grade) — score \(quality.score)")
    case .bitrateRecommendation(let rec):
        print("ABR: \(rec.direction) to \(rec.recommendedBitrate) bps")
    case .disconnected(let type, let error):
        print("Disconnected from \(type): \(error?.localizedDescription ?? "clean")")
    default:
        break
    }
}
```

## Statistics and Recording

``TransportStatisticsSnapshot`` is a point-in-time metrics capture with six properties: `bytesSent` (`Int64`), `duration` (`TimeInterval`), `currentBitrate` (`Double`), `peakBitrate` (`Double`), `reconnectionCount` (`Int`), and `timestamp` (`Date`). Transports emit snapshots through the `.statisticsUpdated` event, and ``LivePipeline`` and ``MultiDestinationPusher`` aggregate them for display.

``TransportRecordingState`` tracks whether a transport is actively writing to a local file. Transports that implement ``RecordingTransport`` emit this state through the `.recordingStateChanged` event. It carries `isRecording` (`Bool`), `bytesWritten` (`Int64`), `duration` (`TimeInterval`), and `currentFilePath` (`String?`, `nil` when not recording).

## RTMP Transport v2

``RTMPTransport`` defines the minimum surface for RTMP communication: `connect(to:)`, `disconnect()`, `send(data:timestamp:type:)`, and `isConnected`. Two v2 additions are default-implemented for backward compatibility:

- `sendMetadata(_:)` -- live metadata injection during an active stream (no-op default)
- `serverCapabilities` -- ``RTMPServerCapabilities`` negotiated during the RTMP handshake (`nil` default)

``RTMPServerCapabilities`` describes what the server advertised during the connect handshake. The `supportedCodecs` set uses FourCC identifiers (`"hvc1"`, `"av01"`, `"avc1"`), and `supportsEnhancedRTMP` gates codec negotiation.

``FLVTagType`` is a `UInt8` raw-value enum matching the FLV specification: `.audio` (8), `.video` (9), `.scriptData` (18). Pass the appropriate case to `send(data:timestamp:type:)` when forwarding encoded samples.

### Platform Presets

``RTMPPusherConfiguration`` ships with ten static factory methods covering the major live platforms. The `fullURL` property combines `serverURL` and `streamKey` with correct slash handling.

| Preset | URL | Protocol |
| --- | --- | --- |
| `.twitch(streamKey:)` | `rtmps://live.twitch.tv/app` | RTMPS |
| `.youtube(streamKey:)` | `rtmps://a.rtmp.youtube.com/live2` | RTMPS |
| `.facebook(streamKey:)` | `rtmps://live-api-s.facebook.com:443/rtmp` | RTMPS |
| `.instagram(streamKey:)` | `rtmps://live-upload.instagram.com:443/rtmp/` | RTMPS |
| `.tiktok(streamKey:)` | `rtmps://push.tiktok.com/rtmp/` | RTMPS |
| `.twitter(streamKey:)` | `rtmps://prod-rtmp-publish.periscope.tv:443/` | RTMPS |
| `.rumble(streamKey:)` | `rtmp://publish.rumble.com/live/` | RTMP |
| `.kick(streamKey:)` | `rtmp://fa723fc1b171.global-contribute.live-video.net/app/` | RTMP |
| `.linkedin(streamKey:)` | `rtmps://livein.linkedin.com:443/live/` | RTMPS |
| `.trovo(streamKey:)` | `rtmp://livepush.trovo.live/live/` | RTMP |

Most platforms use RTMPS (TLS-encrypted RTMP) for security. Rumble, Kick, and Trovo use plain RTMP.

```swift
let twitch = RTMPPusherConfiguration.twitch(streamKey: "live_abc123")
// twitch.serverURL == "rtmps://live.twitch.tv/app"
// twitch.fullURL == "rtmps://live.twitch.tv/app/live_abc123"
// twitch.retryPolicy == .aggressive

let youtube = RTMPPusherConfiguration.youtube(streamKey: "xxxx-xxxx")
// youtube.serverURL == "rtmps://a.rtmp.youtube.com/live2"
```

## SRT Transport v2

``SRTTransport`` extends the base transport with v2 additions: `connectionQuality` (``SRTConnectionQuality``), `isEncrypted`, and `networkStats` (``SRTNetworkStats``). All three have default implementations returning `nil` or `false` for backward compatibility.

### Connection Modes

``SRTConnectionMode`` supports three modes: `.caller` (initiates to a listener, the default), `.listener` (accepts incoming connections), and `.rendezvous` (both sides initiate simultaneously for NAT traversal).

### Forward Error Correction

``SRTFECConfiguration`` configures SMPTE 2022-1 XOR-based FEC for packet loss recovery without retransmission. The standard preset is `.smpte2022` (staircase layout, 5x5 matrix).

```swift
let fec = SRTFECConfiguration.smpte2022
// fec.layout == .staircase, fec.rows == 5, fec.columns == 5

let custom = SRTFECConfiguration(layout: .even, rows: 10, columns: 8)
```

### Congestion Control and ARQ

``SRTCongestionControl`` selects the congestion algorithm: `.live` uses pacing-based control optimized for real-time latency; `.file` uses AIMD windowing for maximum bulk-transfer throughput.

``SRTARQMode`` controls retransmission when FEC is active: `.always` keeps both FEC and retransmission enabled (default); `.onreq` uses FEC first and only retransmits on explicit request; `.never` relies on FEC alone for extremely tight latency budgets.

### Bonding

``SRTBondingMode`` aggregates multiple network paths: `.broadcast` (send on all links, receiver deduplicates), `.mainBackup` (active/standby failover), and `.balancing` (distribute packets for aggregate bandwidth). Set `bondingMode` to `nil` to disable bonding (the default).

### SRT Connection Quality

``SRTConnectionQuality`` is SRT's native quality view, combining RTT and packet loss rate into a composite score. Call `toTransportQuality(timestamp:)` to lift it into the unified ``TransportQuality`` type for pipeline integration.

```swift
let srtQuality = SRTConnectionQuality(
    score: 0.88,
    grade: .good,
    rttMs: 25.0,
    packetLossRate: 0.001,
    recommendation: "Connection stable"
)
let transportQuality = srtQuality.toTransportQuality(timestamp: Date())
// transportQuality.grade == .good, transportQuality.score == 0.88
```

### SRT Configuration Presets

``SRTPusherConfiguration`` provides convenience presets for common SRT deployments:

- `.lowLatency(host:port:)` -- 50 ms latency, aggressive retry
- `.encrypted(host:port:passphrase:)` -- AES passphrase encryption
- `.rendezvous(host:port:passphrase:)` -- NAT traversal with encryption, mode `.rendezvous`

## Icecast Transport v2

``IcecastTransport`` extends the base transport with v2 additions: `serverVersion` (`String?`) detected during the Icecast handshake, and `streamStatistics` (``IcecastStreamStatistics``) for real-time metrics. Both have default implementations returning `nil` for backward compatibility.

### Authentication

``IcecastAuthMode`` covers all six authentication styles:

| Mode | Description |
| --- | --- |
| `.basic` | HTTP Basic Auth (RFC 7617) -- default |
| `.digest` | HTTP Digest Auth (RFC 7616) |
| `.bearer` | `Authorization: Bearer` token |
| `.queryToken` | Token in URL query parameter |
| `.shoutcast` | SHOUTcast v1 password-only |
| `.shoutcastV2` | SHOUTcast v2 user:password |

``IcecastCredentials`` carries `username`, `password`, and `authenticationMode`. The default username is `"source"`, the conventional Icecast SOURCE client name.

```swift
let credentials = IcecastCredentials(
    username: "source",
    password: "secret",
    authenticationMode: .basic
)
```

### Server Presets

``IcecastServerPreset`` is a `CaseIterable` enum with seven known platforms, stored in ``IcecastPusherConfiguration/serverPreset`` to give transport implementations a hint about protocol-level behavior:

| Preset | Platform |
| --- | --- |
| `.azuracast` | AzuraCast self-hosted radio |
| `.libretime` | LibreTime broadcast automation |
| `.radioCo` | Radio.co managed service |
| `.centovaCast` | Centova Cast control panel |
| `.shoutcastDNAS` | SHOUTcast DNAS server |
| `.icecastOfficial` | Official Icecast server |
| `.broadcastify` | Broadcastify (formerly RadioReference) |

``IcecastPusherConfiguration`` ships with server-specific factory methods that encode the correct defaults:

```swift
let config = IcecastPusherConfiguration.azuracast(
    host: "radio.example.com",
    password: "az-secret"
)
// config.serverURL == "http://radio.example.com:8000"
// config.mountpoint == "/radio.mp3"
// config.serverPreset == .azuracast
```

### Stream Statistics

``IcecastStreamStatistics`` carries Icecast-specific metrics including `metadataUpdateCount` (ICY metadata update count) alongside the common fields (`bytesSent`, `duration`, `currentBitrate`, `reconnectionCount`). Call `toTransportStatisticsSnapshot(peakBitrate:timestamp:)` to convert for pipeline aggregation. When `peakBitrate` is `nil`, it defaults to `currentBitrate`.

### Metadata

``IcecastMetadata`` holds ICY metadata fields sent inline with the audio stream. The `customFields` dictionary accommodates non-standard fields beyond `StreamTitle` and `StreamURL`.

```swift
let metadata = IcecastMetadata(
    streamTitle: "Episode 42 - Swift Concurrency Deep Dive",
    streamURL: "https://podcast.example.com",
    customFields: ["artist": "Tech Talks", "album": "Season 3"]
)
```

## Companion Libraries

HLSKit works standalone with its built-in ``HTTPPusher``. For RTMP, SRT, and Icecast transport protocols, optional companion libraries from the Atelier Socle ecosystem provide concrete implementations:

- [swift-rtmp-kit](https://github.com/atelier-socle/swift-rtmp-kit) -- RTMP/RTMPS transport implementing ``RTMPTransport``
- [swift-srt-kit](https://github.com/atelier-socle/swift-srt-kit) -- SRT transport implementing ``SRTTransport``
- [swift-icecast-kit](https://github.com/atelier-socle/swift-icecast-kit) -- Icecast/SHOUTcast transport implementing ``IcecastTransport``

All three are optional dependencies. HLSKit's push subsystem compiles and operates without them; you only add the companion libraries you actually need. Each companion library provides bridge modules that make its transport types conform to the HLSKit protocols.

## Next Steps

- <doc:TransportAwarePipeline> -- Integrate transport quality with the live pipeline
- <doc:SegmentPushing> -- Core push protocol and delivery
- <doc:LivePresets> -- Pipeline presets with transport policy

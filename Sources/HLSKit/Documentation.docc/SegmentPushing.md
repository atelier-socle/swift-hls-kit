# Segment Push & Distribution

@Metadata {
    @PageKind(article)
}

Deliver HLS segments and playlists to CDNs and streaming servers via HTTP, RTMP, SRT, or Icecast.

## Overview

HLSKit provides a ``SegmentPusher`` protocol with multiple transport implementations. ``MultiDestinationPusher`` fans out to several destinations simultaneously with failover support.

### Pusher Protocol

``SegmentPusher`` is the contract for all push implementations:

```swift
public protocol SegmentPusher: Sendable {
    func push(data: Data, path: String) async throws
    func pushPlaylist(_ content: String, path: String) async throws
    var state: PushConnectionState { get async }
    var stats: PushStats { get async }
}
```

### HTTP Pusher

``HTTPPusher`` delivers segments via HTTP PUT/POST with configurable retry and circuit breaker:

```swift
let config = HTTPPusherConfiguration(
    baseURL: URL(string: "https://ingest.cdn.example.com/live/")!,
    method: .put,
    headers: ["Authorization": "Bearer token"]
)
```

``HTTPClientProtocol`` enables dependency injection for testing.

### RTMP Pusher

``RTMPPusher`` streams to RTMP servers (Twitch, YouTube Live, etc.) via FLV containers. The ``RTMPTransport`` protocol enables bringing your own RTMP library:

```swift
let config = RTMPPusherConfiguration(
    url: URL(string: "rtmp://live.twitch.tv/app")!,
    streamKey: "live_xxxx"
)
```

### SRT Pusher

``SRTPusher`` provides ultra-low-latency delivery via SRT (Secure Reliable Transport). ``SRTTransport`` protocol + ``SRTOptions`` for encryption, latency, and bandwidth:

```swift
let config = SRTPusherConfiguration(
    host: "srt.example.com",
    port: 9000,
    options: SRTOptions(latency: 200)
)
```

### Icecast Pusher

``IcecastPusher`` streams audio to Icecast/SHOUTcast servers for webradio:

```swift
let config = IcecastPusherConfiguration(
    serverURL: URL(string: "http://icecast.example.com:8000/live")!,
    mountPoint: "/live",
    contentType: .aac
)
```

``IcecastTransport`` protocol enables custom transport implementations.

### Multi-Destination

``MultiDestinationPusher`` delivers to multiple destinations with failover:

```swift
let pusher = MultiDestinationPusher(
    pushers: [httpPusher, rtmpPusher],
    failoverPolicy: .continueOnPartialFailure
)
// Pushes to all destinations simultaneously
// Continues if some fail (based on policy)
```

### Bandwidth Monitoring

``BandwidthMonitor`` tracks real-time upload bandwidth and alerts when insufficient:

```swift
let monitor = BandwidthMonitor(
    configuration: .init(
        minimumBandwidth: 5_000_000,  // 5 Mbps
        windowDuration: 10.0
    )
)
```

### Retry Policy

``PushRetryPolicy`` configures exponential backoff with circuit breaker:

| Parameter | Description |
|-----------|-------------|
| `maxRetries` | Maximum retry attempts |
| `initialDelay` | First retry delay |
| `backoffMultiplier` | Delay multiplier per retry |
| `circuitBreakerThreshold` | Failures before circuit opens |

### Connection State

``PushConnectionState`` tracks the pusher lifecycle: `disconnected` → `connecting` → `connected` → `pushing` → `reconnecting`.

### Transport Quality Monitoring

In 0.4.0, HLSKit adds transport v2 contracts that enable quality-aware delivery. ``TransportAwarePusher`` wraps any ``SegmentPusher`` together with a ``QualityAwareTransport`` to provide real-time quality signals back to the ``LivePipeline``.

The ``QualityAwareTransport`` protocol provides:
- ``TransportQuality`` — a score (0.0–1.0) with a ``TransportQualityGrade`` (excellent, good, fair, poor, critical)
- ``TransportEvent`` — a unified event stream for connection state, quality changes, and bitrate recommendations
- ``TransportStatisticsSnapshot`` — bytes sent, current/peak bitrate, reconnection count

Additional protocol layers:
- ``AdaptiveBitrateTransport`` — publishes ``TransportBitrateRecommendation`` signals for ABR
- ``RecordingTransport`` — adds recording start/stop with ``TransportRecordingState``

### Transport-Aware Pipeline Integration

When a ``TransportAwarePipelinePolicy`` is set on ``LivePipelineConfiguration``, the pipeline monitors all ``TransportAwarePusher`` destinations and emits ``LivePipelineEvent`` cases for quality degradation, bitrate adjustments, destination failures, and health updates.

```swift
var config = LivePipelineConfiguration()
config.transportPolicy = TransportAwarePipelinePolicy(
    autoAdjustBitrate: true,
    minimumQualityGrade: .fair,
    abrResponsiveness: .responsive
)
```

The ``TransportHealthDashboard`` aggregates health across all destinations with `healthyCount`, `degradedCount`, `failedCount`, and `overallGrade`.

### Companion Libraries

HLSKit works standalone with its built-in ``HTTPPusher``. For advanced transport protocols, optional companion libraries from the Atelier Socle ecosystem provide concrete implementations of the transport contracts:

- [swift-rtmp-kit](https://github.com/atelier-socle/swift-rtmp-kit) — RTMP/RTMPS transport implementing ``RTMPTransport``
- [swift-srt-kit](https://github.com/atelier-socle/swift-srt-kit) — SRT transport implementing ``SRTTransport``
- [swift-icecast-kit](https://github.com/atelier-socle/swift-icecast-kit) — Icecast/SHOUTcast transport implementing ``IcecastTransport``

These companion libraries are optional and additive. They conform to the protocols defined by HLSKit and integrate seamlessly through the ``TransportAwarePusher`` wrapper.

## Next Steps

- <doc:TransportContractsV2> — Transport v2 protocols, quality grades, and companion libraries
- <doc:TransportAwarePipeline> — Pipeline integration with transport quality monitoring
- <doc:LiveSegmentation> — Produce segments for delivery
- <doc:LivePlaylists> — Generate playlists to push alongside segments
- <doc:LiveStreaming> — Full pipeline overview

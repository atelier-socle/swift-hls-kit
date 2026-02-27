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

## Next Steps

- <doc:LiveSegmentation> — Produce segments for delivery
- <doc:LivePlaylists> — Generate playlists to push alongside segments
- <doc:LiveStreaming> — Full pipeline overview

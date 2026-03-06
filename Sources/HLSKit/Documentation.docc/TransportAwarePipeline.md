# Transport-Aware Pipeline

Learn how ``LivePipeline`` responds to transport quality signals, enforces ABR policy, and aggregates multi-destination health into a single dashboard.

@Metadata {
    @PageKind(article)
}

## Overview

When a ``LivePipeline`` has a transport policy, it monitors ``TransportAwarePusher`` destinations for quality changes and reacts automatically — adjusting bitrate, emitting alerts, or reporting health dashboards. Without a transport policy, the pipeline pushes segments without network awareness, exactly as in v1.

## Transport Policy

``TransportAwarePipelinePolicy`` controls how the pipeline reacts to transport quality signals. It has three properties that together determine sensitivity and behavior:

- `autoAdjustBitrate: Bool` — Whether the pipeline can lower or raise the encoding bitrate in response to network conditions. When `true`, the pipeline emits ``LivePipelineEvent/transportBitrateAdjusted(oldBitrate:newBitrate:reason:)`` events after the consecutive-recommendation threshold is met. When `false`, the pipeline observes quality but does not suggest bitrate changes.
- `minimumQualityGrade: TransportQualityGrade` — The floor below which a destination's quality triggers a ``LivePipelineEvent/transportQualityDegraded(destination:quality:)`` event. Set this to ``TransportQualityGrade/poor`` to be notified early, or ``TransportQualityGrade/critical`` to react only when the link is nearly unusable.
- `abrResponsiveness: ABRResponsiveness` — How quickly the pipeline acts on bitrate recommendations from ``TransportAwarePusher`` destinations.

### ABRResponsiveness

``TransportAwarePipelinePolicy/ABRResponsiveness`` is an enum that determines how many consecutive same-direction recommendations the pipeline requires before emitting a bitrate adjustment event:

- `.conservative` — Requires 3 consecutive recommendations in the same direction before acting. This reduces bitrate jitter at the cost of slower adaptation.
- `.responsive` — Requires 2 consecutive recommendations in the same direction. This is the default, balancing stability with timely reaction.
- `.immediate` — Acts on every recommendation instantly. This is appropriate when the transport's own ABR algorithm is already well-smoothed.

### Presets

Two static presets cover the most common configurations:

```swift
// Default: ABR on, minimum=poor, responsive
let policy = TransportAwarePipelinePolicy.default

// Disabled: no ABR, no quality monitoring
let disabled = TransportAwarePipelinePolicy.disabled
```

You can also build a custom policy tailored to your deployment:

```swift
let policy = TransportAwarePipelinePolicy(
    autoAdjustBitrate: true,
    minimumQualityGrade: .fair,
    abrResponsiveness: .immediate
)
```

## Health Dashboard

``TransportHealthDashboard`` provides a single aggregated view of all transport destinations in a session. It is computed on demand by ``LivePipeline/transportHealthDashboard()`` and also delivered through ``LivePipelineEvent/transportHealthUpdate(_:)`` after each quality change or disconnection.

The dashboard exposes the following properties:

- `destinations: [TransportDestinationHealth]` — Per-destination health snapshots.
- `overallGrade: TransportQualityGrade` — The worst grade across all destinations. An empty array returns `.critical`.
- `healthyCount: Int` — Destinations with quality grade `.good` or `.excellent`.
- `degradedCount: Int` — Destinations with quality grade `.fair` or `.poor`.
- `failedCount: Int` — Destinations that are disconnected, failed, or have `.critical` quality.

### TransportDestinationHealth

Each destination is described by ``TransportDestinationHealth``, which bundles five fields:

- `label` — Human-readable name (e.g., `"Twitch"`, `"SRT-Backup"`)
- `transportType` — Protocol identifier string (e.g., `"RTMP"`, `"SRT"`, `"Icecast"`)
- `quality` — Current ``TransportQuality``, or `nil` if not yet measured
- `connectionState` — `PushConnectionState` (connected, disconnected, failed, etc.)
- `statistics` — Latest ``TransportStatisticsSnapshot``, or `nil`

A destination in `.disconnected` or `.failed` connection state is always treated as `.critical` for grade purposes, regardless of its last reported quality.

### Multi-Destination Example

```swift
let dashboard = TransportHealthDashboard(
    destinations: [rtmpHealth, srtHealth, icecastHealth]
)
// dashboard.healthyCount == 1
// dashboard.degradedCount == 1
// dashboard.failedCount == 1
// dashboard.overallGrade == .critical  (worst-case)
```

The pipeline also exposes the dashboard directly:

```swift
let dashboard = await pipeline.transportHealthDashboard()
```

## Pipeline Events

Four ``LivePipelineEvent`` cases carry transport-specific information through the pipeline's event stream.

### transportQualityDegraded

Emitted when a destination's quality grade drops below the policy's `minimumQualityGrade`. The event carries both the destination label and the full quality snapshot so your app can display actionable information.

```swift
case .transportQualityDegraded(destination: "Primary-RTMP", quality: quality)
// quality.grade == .critical
// quality.recommendation == "Switch to backup"
```

### transportBitrateAdjusted

Emitted when ABR adjusts the encoding bitrate after the consecutive-recommendation threshold is met and `autoAdjustBitrate` is `true`. The event carries the previous and new bitrates along with a reason string.

```swift
case .transportBitrateAdjusted(oldBitrate: 3_500_000, newBitrate: 2_000_000, reason: "congestion")
```

### transportDestinationFailed

Emitted when a transport disconnects with an error. The event carries the destination label and a localized error description.

```swift
case .transportDestinationFailed(destination: "Icecast-Main", error: "Connection lost")
```

### transportHealthUpdate

Emitted with the full ``TransportHealthDashboard`` after any quality change or disconnection, so your UI can render an up-to-date multi-destination health view without polling.

```swift
case .transportHealthUpdate(dashboard)
// dashboard.destinations.count == 3
```

## ABR Flow

The pipeline's internal ABR tracker counts consecutive same-direction recommendations per destination. The flow works as follows:

1. The pipeline receives `.bitrateRecommendation` events from each ``TransportAwarePusher``.
2. A per-destination counter increments for each recommendation that continues in the same direction (increase, decrease, or maintain).
3. When the counter reaches the responsiveness threshold (1 for `.immediate`, 2 for `.responsive`, 3 for `.conservative`), the pipeline emits `.transportBitrateAdjusted` and resets the counter.
4. If the direction changes, the counter resets immediately. This prevents oscillation when transport conditions stabilize.

Here is a concrete example with `.responsive` (threshold of 2):

- Recommendation 1: decrease — counter=1 (no action)
- Recommendation 2: decrease — counter=2 (threshold reached, emit `.transportBitrateAdjusted`)
- Recommendation 3: increase — counter resets to 1 (direction changed, no action)

The tracker remembers the last effective bitrate so the `oldBitrate` field in the event reflects the actual current encoder bitrate, not the transport's estimate.

## Configuration Example

Here is a complete ``LivePipelineConfiguration`` with a transport policy, showing how to wire a ``TransportAwarePusher`` and monitor pipeline events:

```swift
var config = LivePipelineConfiguration()
config.transportPolicy = TransportAwarePipelinePolicy(
    autoAdjustBitrate: true,
    minimumQualityGrade: .fair,
    abrResponsiveness: .responsive
)

let pipeline = LivePipeline()
try await pipeline.start(configuration: config)

// Add a transport-aware destination
let transport = myQualityAwareTransport  // implements QualityAwareTransport
let pusher = TransportAwarePusher(
    pusher: mySegmentPusher,
    qualityTransport: transport
)
await pipeline.addDestination(pusher, id: "rtmp-1")

// Monitor events
for await event in pipeline.events {
    switch event {
    case .transportQualityDegraded(let dest, let quality):
        print("\(dest) degraded: \(quality.grade)")
    case .transportBitrateAdjusted(let old, let new, let reason):
        print("Bitrate: \(old) → \(new) (\(reason))")
    case .transportDestinationFailed(let dest, let error):
        print("\(dest) failed: \(error)")
    case .transportHealthUpdate(let dashboard):
        print("Health: \(dashboard.overallGrade)")
    default:
        break
    }
}
```

## Next Steps

- <doc:TransportContractsV2> — Transport protocol contracts and companion libraries
- <doc:LivePresets> — Pipeline presets including spatial video
- <doc:LiveStreaming> — Pipeline architecture overview

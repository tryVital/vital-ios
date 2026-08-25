# Workout Stream Sync

Workout stream extraction is intentionally separate from workout summary sync. A single
HealthKit stream query can be slow or get stuck, and embedding it in workout sync makes a
workout upload depend on all of its associated stream samples.

The SDK uploads workouts first. After a successful workout upload, it records the uploaded
HKWorkout UUID and the minimum matching metadata in a durable FIFO worklist. A later
`workoutStream` sync drains that worklist, extracts paginated stream samples one workout
at a time, stages pages on disk, and uploads compact stream attachments through the
existing `workouts` summary endpoint.

This preserves backend ordering without maintaining client-side or backend-side
HKWorkout-to-Vital-ID maps. Since stream attachments are posted after the workout upload
and still use the workout lane, the backend can use the existing workout dedupe/matching
logic to find the already-created workout before attaching the stream.

The durable worklist contains workout identity and matching metadata only. Staging
sessions are disposable execution state derived from the FIFO prefix and the current
authorized stream component plan. If permissions change or staged artifacts become
invalid, the SDK can delete staging and rebuild from the same worklist.

At startup, the unnotified-resource rescue also checks the durable worklist. A non-empty
worklist forces an active `workoutStream` resource to sync even when its last recorded
sync completed successfully, covering a trigger lost to process termination or timing.
Each HealthKit background delivery gets an individual monotonic 20-second deadline when it
is ingested. The deadline bounds the entire delivery batch. For workout deliveries, that
same structured cancellation scope includes its post-sync stream drain, and the delivery
listener uses unrelated deliveries to rescue previously queued stream work. Startup rescue
uses the same 20-second bounded scope around all rescued resources and the final stream
attempt. Non-system-owned foreground sync entry points run inside
`withUIKitBackgroundTask`, which acquires an assertion before the operation starts and
cancels it on expiration. HealthKit delivery and BGProcessing rely on their system-owned
lifetimes instead. BGProcessing schedules its next request before starting the current
invocation, so expiration cancels current work without suppressing a future retry.
Unfinished stream work remains durable for the next delivery, relaunch, or processing task.

UIKit background-task expiration cancels the sync task that owns the assertion before
ending it. BG processing expiration likewise cancels only that processing invocation,
flushes durable progress, and reports failure exactly once. Its successor is already
scheduled before current work starts, following Apple's recurring-task pattern. Processing
requests continue to require external power and network access.

Log archives include a `workout-stream-artifacts` snapshot containing `worklist.json`
and the current staging directory. The snapshot is refreshed immediately before archive
compression so manifests and their referenced pages can be inspected together.

The stream payload is `WorkoutStreamPatch.StreamAttachment`, discriminated by
`patch_type = "workout_stream"`. Existing workout creations are treated as
`patch_type = "workout"` by the backend, including legacy payloads that omit the field.

`HKWorkoutRoute` should use the same attachment pattern in the future, but it needs its
own readiness trigger. Route data can arrive asynchronously after the workout, so route
attachments should not be enqueued only because the workout upload succeeded.

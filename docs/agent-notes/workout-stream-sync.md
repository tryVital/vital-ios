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

The stream payload is `WorkoutStreamPatch.StreamAttachment`, discriminated by
`patch_type = "workout_stream"`. Existing workout creations are treated as
`patch_type = "workout"` by the backend, including legacy payloads that omit the field.

`HKWorkoutRoute` should use the same attachment pattern in the future, but it needs its
own readiness trigger. Route data can arrive asynchronously after the workout, so route
attachments should not be enqueued only because the workout upload succeeded.

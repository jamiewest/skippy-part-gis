# Route planning

Open **Build a route** (the route icon on the map). Choose addresses, places,
coordinates, or use each stop's pin button to pick on the map. Add, remove,
reorder, or reverse up to eight stops. Build the route, select alternatives,
click directions to locate a maneuver, and drag numbered map markers to
recalculate. Copy directions includes the coverage limitations.

## Drag a route onto another street

Drag the selected line (blue, red, or orange) onto a nearby drivable street.
A white handle snaps to the street; a purple dotted line previews the new road
route after a short pause. The preview has **not** been checked for cameras.
Release to rebuild directions, time, distance, and camera coverage over the
new corridors. The map stays in place; use **Fit route** to reframe it.

Each successful drag adds an unnumbered shaping point without adding a stop.
Further drags keep earlier street choices. Move a handle to change its street,
or use **Chosen streets** in the route panel to remove a point, **Undo** an
edit, or **Reset route edits**. These actions also reroute and recheck cameras.
Up to eight shaping points can be used alongside the existing eight stops.

Chosen streets remain mandatory even when they cross mapped camera coverage.
The maximum detour applies beyond the fastest route through those streets;
unmet avoidance and incomplete camera queries remain visible. Camera failures
keep the new route with unverified coverage. A snapping or routing failure
keeps the previous route. Escape or pointer cancellation cancels a drag.

Snapping uses the nearest eligible road within 24 screen pixels and at most
75 meters. Zoom in to distinguish nearby roads. A route must follow the chosen
road geometry, rather than merely intersect it. Roads unavailable to driving,
disconnected streets, or a chosen point requiring an illegal turn may fail.
Geometrically overlapping road levels remain limited by the provider's road
correlation; this is not lane-level editing.

Route previews debounce for 350 ms, with at most one preview operation in flight
and no more than one start per second. Only release invokes camera queries and
the full avoidance search. Later edits, cancellation, and county changes discard
late responses. Settings changes keep shaping points; changing, reordering,
reversing, or replacing stops clears them and undo history. Edits are session-only.
Area selection and stop picking take precedence over line dragging.

The assistant uses the same planner and state. For example:

> Route me from Riverside City Hall to the Riverside Municipal Airport, avoid
> mapped ALPR coverage, and allow up to 15 extra minutes.

Place searches return candidates; ambiguous addresses need clarification.
Routing supports driving on roads, with estimated travel times. This is a
route planner, not live GPS navigation, voice guidance, or live traffic.

## Preferences

- **Fastest:** shortest travel time among returned candidates; still reports
  estimated camera exposure when the camera query succeeds.
- **Lower camera exposure:** minimizes the number of intersected camera
  footprints among checked candidates within the detour limit, then travel time.
- **Avoid mapped coverage:** requires zero footprint intersections and a
  completed camera query within the detour limit. If no candidate qualifies,
  the panel and assistant explicitly say the request was not satisfied.

The default reader filter includes all ALPR vendors, including Flock. Flock-only
uses explicit manufacturer/brand evidence and excludes unknown vendors.
Missing direction is treated conservatively; it is never taken as evidence
that a reader cannot see a road.

## Geometry and search limits

The analyzer intersects complete polyline segments with estimated viewing
footprints, including segments whose endpoints lie outside the footprint.
Known bearings use a 120 m, 70° sector; unknown bearings use a 150 m buffer.
These intentionally differ from the existing illustrative 90 m, 50° display
cones. Route overlays show the actual analysis footprints. These are modeled
assumptions, not calibrated optics or measured line-of-sight.

The direction the reader faces is not the direction of traffic it can read.
Front plates may be visible when a vehicle approaches, and rear plates when
it travels away. Both travel directions count as exposure within the estimated
viewing footprint, so reversing a route does not remove its exposure. Front
plates do not extend a camera's view behind it. The source does
not establish capture orientation, lane coverage, height, occlusion, or plate
read success. Ways and relations use their reported centers. A route outside
modeled coverage is not a guarantee against capture; OSM's inventory is incomplete.

The planner obtains ordinary Valhalla alternatives and queries cameras over
their entire corridors. Valhalla searches the full road graph; the app builds
a directed graph of discovered segments and records complete routes and their
search exclusions. It never splices paths at shared vertices, since that could
invent an illegal turn or skip a requested stop.

Up to ten additional requests explore camera detours and branches of successful
routes. These requests favor local streets, reduce highway preference, balance
distance with time, and disable hierarchy pruning where the provider permits.
They retain car access, one-way, and turn restrictions. If precise footprint
exclusions return the same exposed route, the search retries with 200 m then
350 m camera-area buffers, capped to leave space around requested stops. These
broader search exclusions do not change the reported exposure footprints.

Finding one successful route does not end the search. The planner explores
deviations at separated points along successful paths, carrying forward each
branch's road exclusions. Every new route is queried and analyzed again,
including cameras discovered on a different branch. Duplicate geometry is
discarded. Within the original detour limit, the top three successful routes
are retained by travel time, then distance. Exposed alternatives are omitted
when successful routes exist. If none qualify, the best checked fallbacks
remain visible with the existing constraint status. The original fastest time
remains the detour reference; it is never silently relaxed.

Valhalla polygon exclusions may remove both directions of an intersecting road
edge. Broader retries may also exclude nearby roads outside the facing footprint.
This implementation
does **not** provide lane-specific or independently weighted directed-edge
costs. That requires additional capture-direction data and a routing backend
with a verified directed-cost interface. The bounded detour search is not an
exhaustive optimizer and cannot prove that no qualifying route exists.

Camera queries cover 0.05° grid cells around every route segment with at least
200 m padding. Requests are capped at 120 cells and 10,000 camera records.
Oversized corridors, malformed records, timeouts, and partial Overpass responses
are marked incomplete. The app then shows ordinary routes with unverified
camera coverage, without claiming avoidance. Camera querying is independent
of viewport zoom, county boundaries, and the visibility of the ALPR layer.

## Services and configuration

Defaults for modest interactive prototype use:

| Setting | Default |
| --- | --- |
| `ATLAS_ROUTING_URL` | `https://valhalla1.openstreetmap.de/route` |
| `ATLAS_ROUTE_SNAP_URL` | Same endpoint with its last path component replaced by `locate` |
| `ATLAS_GEOCODING_URL` | `https://photon.komoot.io/api/` |
| `ATLAS_ROUTE_CAMERA_URL` | `https://overpass-api.de/api/interpreter` |

Use full endpoint URLs. Snapping retains the routing endpoint’s query options;
set `ATLAS_ROUTE_SNAP_URL` when a proxy uses a different locate URL. Native builds accept environment variables; native and
web builds accept `--dart-define`. For example:

```sh
flutter run -d macos \
  --dart-define=ATLAS_ROUTING_URL=http://localhost:8002/route
```

Self-host or arrange suitable hosted capacity before broad deployment. Public
demo services can throttle or become unavailable. Geocoding is explicitly
submitted, not requested on every keystroke. Routing/camera requests have
timeouts and bounded retry-by-detour counts. Web endpoints must support CORS;
HTTPS applications need HTTPS endpoints or a suitable same-origin proxy.

Endpoints receive the requested places/stops/corridor areas. No route history
or plate-read data is stored. Route and camera services remain online even if
parcel data uses an offline snapshot; the route panel identifies online routing.

The engine returns route geometry and turn instructions; the AI does not
invent roads or directions. Provider-independent contracts are in
`lib/domain/repositories/routing_repository.dart`; exposure and orchestration
are in `lib/domain/services`; Flutter state and widgets are under the map feature.
County changes dispose and cancel that county's route state. Editing, clearing,
or cancelling invalidates pending results so late responses cannot overwrite
the current route.

## References

- [Valhalla route API](https://valhalla.github.io/valhalla/api/route/api-reference/)
- [Photon usage and demo-server limits](https://github.com/komoot/photon)
- [OpenStreetMap attribution](https://www.openstreetmap.org/copyright)

## Verification

```sh
flutter analyze --no-pub
flutter test --no-pub test/route_exposure_test.dart test/route_planner_test.dart \
  test/routing_services_test.dart test/route_assistant_tools_test.dart \
  test/route_builder_widget_test.dart test/route_editing_test.dart \
  test/route_drag_widget_test.dart test/route_snapping_service_test.dart
```

To run an explicit live-service smoke test (makes public API requests):

```sh
flutter test --no-pub tool/check_routing_test.dart tool/check_route_editing_test.dart
```

Platform interaction checks (the native smoke test uses deterministic routing
and camera fixtures to exercise dragging and Undo in the actual map screen):

```sh
flutter test --no-pub --platform chrome test/route_drag_widget_test.dart
flutter test --no-pub -d macos integration_test/route_editing_test.dart
```

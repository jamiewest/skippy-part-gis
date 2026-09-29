"""Downloads the national state and county tables from Census TIGERweb.

The app needs three facts about every county before it can draw anything:
a stable identifier, a point to open the map on, and a rectangle to frame.
None of them change often, and all three must be available before the first
network call succeeds, so they are captured here and written into Dart rather
than fetched at runtime.

Writes `.work/geography.json`. `generate_dart.py` turns that into
`lib/data/services/us_geography.g.dart`.

Standard library only, in keeping with tool/gis_inventory.

    python3 tool/us_geography/fetch_geography.py
"""

import json
import pathlib
import time
import urllib.parse
import urllib.request

TIGERWEB = (
    "https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/"
    "State_County/MapServer"
)

# Layer 0 is States and layer 1 Counties at the finest of the seven scale
# bands the service publishes. The coarser bands hold the same rows with
# progressively simpler outlines, so either would give the same identifiers;
# the finest is used because the bounding boxes come from these outlines.
STATES_LAYER = 0
COUNTIES_LAYER = 1

# Douglas-Peucker tolerance in degrees, applied server-side. The geometry is
# thrown away after the bounding box is computed, so the only thing this
# affects is how far a box can fall inside the true outline: about 0.006 deg
# (600 m) at the extremes, against a 100x saving in transfer. Riverside County
# measures 158 KB unsimplified and 1.3 KB at this tolerance.
SIMPLIFY_DEGREES = 0.01

PAGE = 200
WORK = pathlib.Path(__file__).parent / ".work"


def fetch(layer, fields):
    """Every row in `layer`, paged, with a bounding box computed per row."""
    rows = []
    offset = 0
    while True:
        query = urllib.parse.urlencode(
            {
                "where": "1=1",
                "outFields": ",".join(fields),
                "returnGeometry": "true",
                "outSR": "4326",
                "maxAllowableOffset": SIMPLIFY_DEGREES,
                "geometryPrecision": "5",
                "orderByFields": "GEOID",
                "resultOffset": offset,
                "resultRecordCount": PAGE,
                "f": "json",
            }
        )
        url = f"{TIGERWEB}/{layer}/query?{query}"
        with urllib.request.urlopen(url, timeout=180) as response:
            payload = json.load(response)
        if "error" in payload:
            raise SystemExit(f"TIGERweb refused layer {layer}: {payload['error']}")
        features = payload.get("features", [])
        if not features:
            break
        for feature in features:
            box = bounds(feature.get("geometry"))
            if box is None:
                # A row with no outline cannot be framed on a map. Dropping it
                # is right: it would otherwise appear in the picker and open on
                # a rectangle of zero area.
                continue
            rows.append({**feature["attributes"], "bounds": box})
        print(f"  layer {layer}: {len(rows)} rows", flush=True)
        if len(features) < PAGE:
            break
        offset += PAGE
        time.sleep(0.1)
    return rows


def bounds(geometry):
    """The west/south/east/north box enclosing every ring of `geometry`."""
    if not geometry or not geometry.get("rings"):
        return None
    xs = [point[0] for ring in geometry["rings"] for point in ring]
    ys = [point[1] for ring in geometry["rings"] for point in ring]
    if not xs:
        return None
    return [
        round(min(xs), 4),
        round(min(ys), 4),
        round(max(xs), 4),
        round(max(ys), 4),
    ]


def main():
    WORK.mkdir(exist_ok=True)
    print("states...")
    states = fetch(STATES_LAYER, ["GEOID", "BASENAME", "STUSAB", "INTPTLAT", "INTPTLON"])
    print("counties...")
    counties = fetch(
        COUNTIES_LAYER,
        ["GEOID", "BASENAME", "NAME", "STATE", "COUNTY", "INTPTLAT", "INTPTLON"],
    )
    out = WORK / "geography.json"
    out.write_text(json.dumps({"states": states, "counties": counties}, indent=1))
    print(f"wrote {out}: {len(states)} states, {len(counties)} counties")


if __name__ == "__main__":
    main()

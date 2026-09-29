"""Sorting service names into themes a person would recognise.

Twenty-six thousand services is not a list anybody can read. Grouping them by
subject is what turns the catalogue into something browsable, and doing it by
keyword over the service name is the only option: county services carry no
category field, and their descriptions are empty more often than not.

This is a heuristic and is wrong at the edges — `Mesocarnivore Photo Stations`
lands in aerial imagery. It is good enough to group a list and must never be
used to decide what a layer *is*.
"""
import re

PATTERNS = {
    'parcels & assessor': r'parcel|assessor|apn|ownership|taxrate|tax_rate|'
                          r'situs|subdivision|lot|condo',
    'addressing': r'address|situs_?point|centerline|street_?name|road_?name',
    'zoning & land use': r'zoning|rezone|landuse|land_?use|general_?plan|'
                         r'specific_?plan|overlay_?district|entitlement',
    'aerial imagery': r'aerial|imagery|ortho|naip|pictometry|satellite|'
                      r'y\d{4}|_wm$|_is$|photo',
    'flood & water': r'flood|fema|firm|dfirm|watershed|creek|river|hydro|'
                     r'levee|storm|drain|water|well|groundwater|basin',
    'fire & hazard': r'fire|hazard|fhsz|burn|evacuation|seismic|fault|'
                     r'liquefaction|landslide|earthquake|hazmat',
    'environment & habitat': r'habitat|species|wetland|vegetation|tree|'
                             r'agricult|williamson|soil|conservation|'
                             r'open_?space|biolog|environment',
    'transportation': r'road|street|highway|transit|bike|trail|traffic|'
                      r'bridge|rail|airport|route|pavement|sidewalk',
    'boundaries & districts': r'boundar|district|supervisor|city|cities|'
                              r'census|tract|block|precinct|school|'
                              r'special_?dist|sphere|annex|municipal|'
                              r'jurisdiction|zip',
    'public safety': r'police|sheriff|crime|fire_?station|ems|ambulance|'
                     r'emergency|evac|911|dispatch',
    'utilities & infrastructure': r'sewer|utility|utilities|electric|power|'
                                  r'gas|broadband|fiber|telecom|streetlight|'
                                  r'facilit|infrastructure',
    'permits & code': r'permit|code_?enforce|violation|inspection|'
                      r'building|cannabis|license|business',
    'recreation & parks': r'park|recreation|golf|campground|open_?space|'
                          r'playground',
    'basemap & reference': r'basemap|base_?map|topo|contour|elevation|dem|'
                           r'lidar|hillshade|terrain|survey|section|township|'
                           r'benchmark|monument|grid',
}

COMPILED = {name: re.compile(pattern, re.I)
            for name, pattern in PATTERNS.items()}


def themes_of(text):
    """Every theme matching `text`. A name can belong to several."""
    subject = (text or '').replace('_', ' ')
    return [name for name, pattern in COMPILED.items()
            if pattern.search(subject)]

# Sample parcel data — Riverside vs San Bernardino

Pulled live from the county services this app reads. Geometry and shape
columns omitted. `outFields=*`, so this is everything each layer publishes.

## Summary of what matters for addresses

| | Riverside parcel layer | San Bernardino parcel layer |
|---|---|---|
| Street address on the parcel | **Yes** — `SITUS_STREET`, plus split `STREET_NUMBER`/`STREET_NAME`/`STREET_TYPE`/`UNIT_NUMBER` | **No such field at all** |
| City / ZIP | `CITY`, `ZIP_CODE`, `SITUS_CITY` | `Jurisdiction` only (no ZIP) |
| Owner name | not published in this layer | `OwnerName`, but 100% redacted |
| Owner mailing address | **Yes** — `MAIL_STREET`, `MAIL_CITY` | no |
| Assessed values | `LAND`, `STRUCTURES` | `LandValue`, `ImprovementValue`, exemptions |
| Join to address points | `APN` -> address layer `APN` | `ParcelNumber` -> address layer `PRCLNUM` |

Coverage measured against the live services:

- Riverside parcels total **846,251**; blank `SITUS_STREET` on **145,812 (17%)**.
  Those blanks have no `STREET_NUMBER` either — no address exists for them.
- San Bernardino parcels total **839,806**; `OwnerName` non-redacted on **0**.
- San Bernardino address points total **868,122**; carrying a real `PRCLNUM`: **647,531 (75%)**.

---

# Riverside County

## Parcel layer (`OpenData/Assessor/MapServer/50`)

### A normal urban parcel — APN 213191035
```
OBJECTID                 124438
APN                      "213191035"
FLAG                     "EX"
MAIL_STREET              "26569 COMMUNITY CENTER DR"
MAIL_CITY                "HIGHLAND CA 92346"
SITUS_STREET             "3641 6TH ST"
SITUS_CITY               "RIVERSIDE  CA 92501"
STREET_NUMBER            3641
STREET_PREDIRECTION      ""
STREET_NAME              "6TH"
STREET_TYPE              "ST"
STREET_SUFFIX            ""
UNIT_NUMBER              ""
CITY                     "RIVERSIDE"
ZIP_CODE                 "92501"
CLASS_CODE               "CT-Commercial Land / Misc Imps"
MULTIPLE                 "Single"
SUBDIVISION_NAME         "PM 29619"
ACREAGE                  1.83
RECORDER_MAP_TYPE        "PM"
BOOK                     "197"
PAGE                     "71"
MAP_BOOK_PAGE            "PM 197/71"
COUNTY_CODE              ""
LOT_TYPE                 "Parcel"
LOT                      "1"
BLOCK                    ""
CAME_FROM                "213191033"
TAX_RATE_AREA            "009033"
LAND                     1329443.0
STRUCTURES               1569879.0
```
This is the case you are clicking. `SITUS_STREET` = `3641 6TH ST` is already
fetched and mapped to `Parcel.situsAddress` — the panel just never shows it.
Note `MAIL_STREET` is in Highland, i.e. an absentee owner.

### Two more, arbitrary
```
OBJECTID                 3
APN                      "101030001"
FLAG                     null
MAIL_STREET              "P O BOX 8300"
MAIL_CITY                "FOUNTAIN VALLEY CA 92708"
SITUS_STREET             "14995 RIVER RD"
SITUS_CITY               "CORONA  CA 92880"
STREET_NUMBER            14995
STREET_PREDIRECTION      ""
STREET_NAME              "RIVER"
STREET_TYPE              "RD"
STREET_SUFFIX            ""
UNIT_NUMBER              ""
CITY                     "CORONA"
ZIP_CODE                 "92880"
CLASS_CODE               "Vacant Land - Predominate Agricultural Use"
MULTIPLE                 ""
SUBDIVISION_NAME         ""
ACREAGE                  99.2
RECORDER_MAP_TYPE        ""
BOOK                     ""
PAGE                     ""
MAP_BOOK_PAGE            ""
COUNTY_CODE              ""
LOT_TYPE                 ""
LOT                      ""
BLOCK                    ""
CAME_FROM                "092600025"
TAX_RATE_AREA            "059002"
LAND                     0.0
STRUCTURES               0.0
```
```
OBJECTID                 5
APN                      "101040004"
FLAG                     "EX"
MAIL_STREET              "U S DEPT OF INTERIOR"
MAIL_CITY                "WASHINGTON, DC 21401"
SITUS_STREET             "11903 HIGHWAY 71"
SITUS_CITY               "CORONA  CA 92880"
STREET_NUMBER            11903
STREET_PREDIRECTION      ""
STREET_NAME              "HIGHWAY 71"
STREET_TYPE              ""
STREET_SUFFIX            ""
UNIT_NUMBER              ""
CITY                     "CORONA"
ZIP_CODE                 "92880"
CLASS_CODE               "Vacant Residential Land - Other"
MULTIPLE                 ""
SUBDIVISION_NAME         ""
ACREAGE                  81.1
RECORDER_MAP_TYPE        ""
BOOK                     ""
PAGE                     ""
MAP_BOOK_PAGE            ""
COUNTY_CODE              ""
LOT_TYPE                 ""
LOT                      ""
BLOCK                    ""
CAME_FROM                "092800013"
TAX_RATE_AREA            null
LAND                     null
STRUCTURES               null
```
### A parcel with no address at all — APN 300090005
```
OBJECTID                 846186
APN                      "300090005"
FLAG                     null
MAIL_STREET              ""
MAIL_CITY                ""
SITUS_STREET             null
SITUS_CITY               null
STREET_NUMBER            null
STREET_PREDIRECTION      null
STREET_NAME              null
STREET_TYPE              null
STREET_SUFFIX            null
UNIT_NUMBER              null
CITY                     null
ZIP_CODE                 null
CLASS_CODE               null
MULTIPLE                 null
SUBDIVISION_NAME         null
ACREAGE                  null
RECORDER_MAP_TYPE        null
BOOK                     null
PAGE                     null
MAP_BOOK_PAGE            null
COUNTY_CODE              null
LOT_TYPE                 null
LOT                      null
BLOCK                    null
CAME_FROM                null
TAX_RATE_AREA            null
LAND                     null
STRUCTURES               null
```
Everything address-shaped is null. 17% of Riverside parcels look like this.
No amount of geocoding invents a real address here.

## Address-point layer (`OpenData/ADDRESS/FeatureServer/8`)

### Joined to the parcel above by APN
```
OBJECTID                 16029
APN                      "213191035"
ADDRESS                  "3641 6TH ST"
HOUSE_NUMBER             3641
STREET_NAME              "6TH"
STREET_TYPE              "ST"
UNIT                     ""
CITY                     "RIVERSIDE"
ZIP                      "92501"
ADDRESS_TYPE             "6"
NUMBER_OF_UNITS          1
ADDRESS_ID               16055
```
One point, exact match. This is the fallback when a parcel has no situs.

---

# San Bernardino County

## Parcel layer (`Parcels_for_San_Bernardino_County/FeatureServer/0`)

### APN 048512106
```
OBJECTID                 1
ParcelNumber             "048512106"
OwnerName                "Protected Per CA Gov Code 7928.205 "
LandValue                "9,194"
ImprovementValue         "28,896"
PersonalPropertyValue    "0"
ExemptionValue           "7,000"
HomeOwnerExemption       "Y"
Acreage                  0.16
TaxStatus                "ASSESSED BY COUNTY"
TaxRateArea              "0111004"
Zoning                   "RS"
ZoningDescription        "Single Residential "
Jurisdiction             "County Land Use Services office"
JurisdictionURL          "http://cms.sbcounty.gov/lus/Home.aspx"
BaseYear                 "2008"
PageMap                  "048512"
AssessDescription        "SFR"
AssessClass              "SINGLE FAMILY RESIDENTIAL"
```
A single-family residence. No address field exists anywhere in this record —
the closest thing is `Jurisdiction`, which is an office name, not a place.

### APN 048501125
```
OBJECTID                 2
ParcelNumber             "048501125"
OwnerName                "Protected Per CA Gov Code 7928.205 "
LandValue                "11,600"
ImprovementValue         "0"
PersonalPropertyValue    "0"
ExemptionValue           "0"
HomeOwnerExemption       null
Acreage                  13
TaxStatus                "ASSESSED BY COUNTY"
TaxRateArea              "0111004"
Zoning                   "RC"
ZoningDescription        "Resource Conservation"
Jurisdiction             "County Land Use Services office"
JurisdictionURL          "http://cms.sbcounty.gov/lus/Home.aspx"
BaseYear                 "2007"
PageMap                  "048501"
AssessDescription        "CHEMICAL PRODUCTION"
AssessClass              "SINGLE FAMILY RESIDENTIAL"
```
13 acres of chemical production. Also no address, and no address point
exists for it either (see below).

### APN 054401114
```
OBJECTID                 23003
ParcelNumber             "054401114"
OwnerName                "Protected Per CA Gov Code 7928.205 "
LandValue                "0"
ImprovementValue         "0"
PersonalPropertyValue    "0"
ExemptionValue           "0"
HomeOwnerExemption       null
Acreage                  0
TaxStatus                "EXEMPT FROM ASSESSMENT"
TaxRateArea              "0109028"
Zoning                   "RC"
ZoningDescription        "Resource Conservation"
Jurisdiction             "County Land Use Services office"
JurisdictionURL          "http://cms.sbcounty.gov/lus/Home.aspx"
BaseYear                 "0"
PageMap                  "054401"
AssessDescription        "VACANT LAND"
AssessClass              "RESTRICTED"
```
Fort Irwin military housing — this one parcel has **376** address points.

## Address-point layer (`SBC_Site_Addresses/FeatureServer/0`)

### PRCLNUM 048512106 — 1 matching address point(s)
```
OBJECTID                 357283
SITEADDID                "SID-357285"
ADDRNUM                  "13660"
UNITTYPE                 null
UNITID                   null
ALTUNITTYPE              null
ALTUNITID                null
FULLNAME                 "Birch St"
FULLADDR                 "13660 Birch St "
COUNTRY                  "US"
MUNICIPALITY             "Trona"
POINTTYPE                null
STATUS                   "Current"
CREATED_DATE             1716575709000
LAST_EDITED_DATE         1765911569000
ROV_ID                   1420589
ROV_ZIPC                 "93562"
PRCLNUM                  "048512106"
CONFIRESTPREDIR          null
CONFIRESTNAME            "BIRCH"
CONFIRESTTYPE            "ST"
CONFIRESTDIR             null
GLOBALID                 "{86F00CDE-D181-4060-9B10-5FC45B26B159}"
```
### PRCLNUM 018325141 — 1 matching address point(s)
```
OBJECTID                 289975
SITEADDID                "SID-289977"
ADDRNUM                  "1040"
UNITTYPE                 null
UNITID                   null
ALTUNITTYPE              null
ALTUNITID                null
FULLNAME                 "Monterey Ave"
FULLADDR                 "1040 Monterey Ave "
COUNTRY                  "US"
MUNICIPALITY             "Barstow"
POINTTYPE                null
STATUS                   "Current"
CREATED_DATE             1716575709000
LAST_EDITED_DATE         1765843085000
ROV_ID                   1414437
ROV_ZIPC                 "92311"
PRCLNUM                  "018325141"
CONFIRESTPREDIR          null
CONFIRESTNAME            "MONTEREY"
CONFIRESTTYPE            "AVE"
CONFIRESTDIR             null
GLOBALID                 "{CBDF371A-6541-41F4-A6F4-32FDFC6F9D50}"
```
### PRCLNUM 048501125 — 0 matching address point(s)
None. The parcel exists but the county has mapped no address to it.

### PRCLNUM 054401114 — 376 matching address point(s)
```
OBJECTID                 32
SITEADDID                "SID-34"
ADDRNUM                  "9161"
UNITTYPE                 "UNIT"
UNITID                   "B"
ALTUNITTYPE              null
ALTUNITID                null
FULLNAME                 "Apache Dr"
FULLADDR                 "9161 Apache Dr Unit B"
COUNTRY                  "US"
MUNICIPALITY             "Fort Irwin"
POINTTYPE                null
STATUS                   "Current"
CREATED_DATE             1716575709000
LAST_EDITED_DATE         1765833295000
ROV_ID                   3184219
ROV_ZIPC                 "92310"
PRCLNUM                  "054401114"
CONFIRESTPREDIR          " "
CONFIRESTNAME            "APACHE"
CONFIRESTTYPE            "DR"
CONFIRESTDIR             " "
GLOBALID                 "{D43F6CC9-0962-44E0-916E-DF42DFDD10C8}"
```
```
OBJECTID                 34
SITEADDID                "SID-36"
ADDRNUM                  "3897"
UNITTYPE                 "UNIT"
UNITID                   "A"
ALTUNITTYPE              null
ALTUNITID                null
FULLNAME                 "Granite Pass Rd"
FULLADDR                 "3897 Granite Pass Rd Unit A"
COUNTRY                  "US"
MUNICIPALITY             "Fort Irwin"
POINTTYPE                null
STATUS                   "Current"
CREATED_DATE             1716575709000
LAST_EDITED_DATE         1765833295000
ROV_ID                   3185822
ROV_ZIPC                 "92310"
PRCLNUM                  "054401114"
CONFIRESTPREDIR          " "
CONFIRESTNAME            "GRANITE PASS"
CONFIRESTTYPE            "RD"
CONFIRESTDIR             " "
GLOBALID                 "{4EA98673-BD20-4D5C-905C-7C9EEC6B25BD}"
```
```
OBJECTID                 301506
SITEADDID                "SID-301508"
ADDRNUM                  "9081"
UNITTYPE                 "UNIT"
UNITID                   "A"
ALTUNITTYPE              null
ALTUNITID                null
FULLNAME                 "Langford Lake Rd"
FULLADDR                 "9081 Langford Lake Rd Unit A"
COUNTRY                  "US"
MUNICIPALITY             "Fort Irwin"
POINTTYPE                null
STATUS                   "Current"
CREATED_DATE             1716575709000
LAST_EDITED_DATE         1765909763000
ROV_ID                   3184172
ROV_ZIPC                 "92310"
PRCLNUM                  "054401114"
CONFIRESTPREDIR          " "
CONFIRESTNAME            "LANGFORD LAKE"
CONFIRESTTYPE            "RD"
CONFIRESTDIR             " "
GLOBALID                 "{C6C3B2FE-C04E-42AB-A1AE-7D70BBF72C40}"
```
...showing 3 of 376.

Note `054401114`: 376 points on one parcel. Any single "the address" for that
parcel is a fiction, which is why the join needs an explicit display policy.


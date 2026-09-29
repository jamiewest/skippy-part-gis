# Maricopa parcel inspection fixtures

Captured on 2026-09-26 from the public Maricopa County GIS service:

- `https://gis.maricopa.gov/arcgis/rest/services/IndividualService/Parcel/MapServer?f=json`
- Layer `0`: Subdivision metadata.
- Layer `1`: Parcel metadata, including OID type and advanced query capabilities.
- `maricopa_sample.json`: layer 1 query, `where=1=1`, 250 records, no geometry, WGS84 envelope `-113.36,32.5,-111.03,34.05`; only OID, APN, situs, city, ZIP and published owner attributes retained.

Metadata and records are fixtures of a changing public source, not a statement that the contents remain current.

Also captured on the same date:

- `king_parcels.json`: `https://services.arcgis.com/Ej0PsM5Aw677QF1W/arcgis/rest/services/PARCEL_ADDRESS_PUB_AREA_3069/FeatureServer/0?f=json`
- `hennepin_parcels.json`: `https://arcgis.metc.state.mn.us/data1/rest/services/parcels/Parcels/FeatureServer/3?f=json`

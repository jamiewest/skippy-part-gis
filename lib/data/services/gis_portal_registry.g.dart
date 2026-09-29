// GENERATED — do not edit by hand.
//
// Written by tool/gis_inventory/generate_dart.py from
// docs/county-gis-inventory.json. To change what is here, re-run the
// inventory pipeline and regenerate:
//
//     python3 tool/gis_inventory/run.py
//     python3 tool/gis_inventory/generate_dart.py

import 'package:riverside_atlas/domain/models/geo_bounds.dart';
import 'package:riverside_atlas/domain/models/gis_portal.dart';

/// Public map catalogues, keyed by county id.
///
/// A county absent from this map published nothing this build could find,
/// which is not the same as publishing nothing. Those counties still get
/// [nationalPortals], and their state's entry in [statePortals].
const countyPortals = <String, List<GisPortal>>{
  'ca_alameda': [
    GisPortal(
      root:
          'https://services3.arcgis.com/i2dkYWmb4wHvYPda/ArcGIS/rest/services',
      publisher: 'MTC/ABAG',
      tier: PortalTier.partner,
      serviceCount: 525,
    ),
    GisPortal(
      root:
          'https://services1.arcgis.com/Hp6G80Pky0om7QvQ/arcgis/rest/services',
      publisher: 'GeoPlatform ArcGIS Online',
      tier: PortalTier.partner,
      serviceCount: 512,
    ),
    GisPortal(
      root:
          'https://services5.arcgis.com/ROBnTHSNjoZ2Wm1P/arcgis/rest/services',
      publisher: 'services5.arcgis.com',
      tier: PortalTier.partner,
      serviceCount: 226,
    ),
    GisPortal(
      root:
          'https://services9.arcgis.com/ucDLsG1EwPnOGY4c/arcgis/rest/services',
      publisher: 'City of Alameda',
      tier: PortalTier.partner,
      serviceCount: 98,
    ),
    GisPortal(
      root:
          'https://services2.arcgis.com/4Z9x989NrBVrvFwm/arcgis/rest/services',
      publisher: 'San Francisco Bay Conservation & Development Commission',
      tier: PortalTier.partner,
      serviceCount: 72,
    ),
    GisPortal(
      root: 'https://mobile.alamedaca.gov/arcgis/rest/services',
      publisher: 'mobile.alamedaca.gov',
      tier: PortalTier.partner,
      serviceCount: 62,
    ),
    GisPortal(
      root: 'https://gis.alamedaca.gov/server/rest/services',
      publisher: 'gis.alamedaca.gov',
      tier: PortalTier.partner,
      serviceCount: 14,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/ucDLsG1EwPnOGY4c/arcgis/rest/services',
      publisher: 'City of Alameda',
      tier: PortalTier.partner,
      serviceCount: 1,
    ),
  ],
  'ca_alpine': [
    GisPortal(
      root:
          'https://services1.arcgis.com/9z9tEfqo0TExR9C8/arcgis/rest/services',
      publisher: 'Alpine County',
      tier: PortalTier.countyPortal,
      serviceCount: 93,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/9z9tEfqo0TExR9C8/arcgis/rest/services',
      publisher: 'Alpine County',
      tier: PortalTier.countyPortal,
      serviceCount: 25,
    ),
  ],
  'ca_amador': [
    GisPortal(
      root:
          'https://services8.arcgis.com/uzb563eo87NppqyM/arcgis/rest/services',
      publisher: 'Amador County',
      tier: PortalTier.countyPortal,
      serviceCount: 54,
    ),
  ],
  'ca_butte': [
    GisPortal(
      root: 'https://gisportal.buttecounty.ca.gov/arcgis/rest/services',
      publisher: 'Butte County',
      tier: PortalTier.countyPortal,
      serviceCount: 142,
    ),
  ],
  'ca_calaveras': [
    GisPortal(
      root: 'https://gisportal.calaverascounty.gov/server/rest/services',
      publisher: 'Calaveras County',
      tier: PortalTier.countyPortal,
      serviceCount: 181,
    ),
    GisPortal(
      root:
          'https://services6.arcgis.com/rNuo8nvF17v2dPFX/arcgis/rest/services',
      publisher: 'Calaveras County',
      tier: PortalTier.countyPortal,
      serviceCount: 83,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/rNuo8nvF17v2dPFX/arcgis/rest/services',
      publisher: 'Calaveras County',
      tier: PortalTier.countyPortal,
      serviceCount: 9,
    ),
  ],
  'ca_colusa': [
    GisPortal(
      root: 'https://services.arcgis.com/BLN4oKB0N1YSgvY8/arcgis/rest/services',
      publisher: 'CA Governor\'s Office of Emergency Services',
      tier: PortalTier.partner,
      serviceCount: 999,
    ),
    GisPortal(
      root:
          'https://services3.arcgis.com/GUHJKBhKMcD5JjTe/arcgis/rest/services',
      publisher: 'Glenn County | GIS',
      tier: PortalTier.partner,
      serviceCount: 65,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/BLN4oKB0N1YSgvY8/arcgis/rest/services',
      publisher: 'CA Governor\'s Office of Emergency Services',
      tier: PortalTier.partner,
      serviceCount: 29,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/GUHJKBhKMcD5JjTe/arcgis/rest/services',
      publisher: 'Glenn County | GIS',
      tier: PortalTier.partner,
      serviceCount: 1,
    ),
  ],
  'ca_contra_costa': [
    GisPortal(
      root: 'https://gis.cccounty.us/arcgis/rest/services',
      publisher: 'Contra Costa County',
      tier: PortalTier.countyPortal,
      serviceCount: 67,
    ),
  ],
  'ca_del_norte': [
    GisPortal(
      root: 'https://services.arcgis.com/BLN4oKB0N1YSgvY8/arcgis/rest/services',
      publisher: 'CA Governor\'s Office of Emergency Services',
      tier: PortalTier.partner,
      serviceCount: 999,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/BLN4oKB0N1YSgvY8/arcgis/rest/services',
      publisher: 'CA Governor\'s Office of Emergency Services',
      tier: PortalTier.partner,
      serviceCount: 29,
    ),
  ],
  'ca_el_dorado': [
    GisPortal(
      root: 'https://services.arcgis.com/UHg8l1wC48WQyDSO/arcgis/rest/services',
      publisher: 'El Dorado County',
      tier: PortalTier.countyPortal,
      serviceCount: 283,
    ),
    GisPortal(
      root: 'https://see-eldorado.edcgov.us/arcgis/rest/services',
      publisher: 'El Dorado County',
      tier: PortalTier.countyPortal,
      serviceCount: 100,
    ),
  ],
  'ca_fresno': [
    GisPortal(
      root:
          'https://services3.arcgis.com/ibgDyuD2DLBge82s/arcgis/rest/services',
      publisher: 'Fresno County',
      tier: PortalTier.countyPortal,
      serviceCount: 405,
    ),
    GisPortal(
      root: 'https://gisprod10.co.fresno.ca.us/server/rest/services',
      publisher: 'Fresno County',
      tier: PortalTier.countyPortal,
      serviceCount: 171,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/ibgDyuD2DLBge82s/arcgis/rest/services',
      publisher: 'Fresno County',
      tier: PortalTier.countyPortal,
      serviceCount: 6,
    ),
    GisPortal(
      root:
          'https://vectortileservices3.arcgis.com/ibgDyuD2DLBge82s/arcgis/rest/services',
      publisher: 'Fresno County',
      tier: PortalTier.countyPortal,
      serviceCount: 0,
    ),
  ],
  'ca_glenn': [
    GisPortal(
      root:
          'https://services3.arcgis.com/GUHJKBhKMcD5JjTe/arcgis/rest/services',
      publisher: 'Glenn County',
      tier: PortalTier.countyPortal,
      serviceCount: 65,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/GUHJKBhKMcD5JjTe/arcgis/rest/services',
      publisher: 'Glenn County',
      tier: PortalTier.countyPortal,
      serviceCount: 1,
    ),
  ],
  'ca_humboldt': [
    GisPortal(
      root: 'https://gis.co.humboldt.ca.us/arcgis/rest/services',
      publisher: 'Humboldt County',
      tier: PortalTier.countyPortal,
      serviceCount: 222,
    ),
  ],
  'ca_imperial': [
    GisPortal(
      root:
          'https://services7.arcgis.com/RomaVqqozKczDNgd/arcgis/rest/services',
      publisher: 'Imperial County',
      tier: PortalTier.countyPortal,
      serviceCount: 161,
    ),
    GisPortal(
      root:
          'https://services1.arcgis.com/fwUrSNrE506Uxp7v/arcgis/rest/services',
      publisher: 'Imperial County',
      tier: PortalTier.countyPortal,
      serviceCount: 43,
    ),
    GisPortal(
      root: 'https://gis.imperial.ca.gov/server/rest/services',
      publisher: 'Imperial County',
      tier: PortalTier.countyPortal,
      serviceCount: 0,
    ),
  ],
  'ca_inyo': [
    GisPortal(
      root: 'https://gis.inyo.gov/server/rest/services',
      publisher: 'Inyo County',
      tier: PortalTier.countyPortal,
      serviceCount: 243,
    ),
    GisPortal(
      root: 'https://services.arcgis.com/0jRlQ17Qmni5zEMr/arcgis/rest/services',
      publisher: 'Inyo County',
      tier: PortalTier.countyPortal,
      serviceCount: 162,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/0jRlQ17Qmni5zEMr/arcgis/rest/services',
      publisher: 'Inyo County',
      tier: PortalTier.countyPortal,
      serviceCount: 13,
    ),
  ],
  'ca_kern': [
    GisPortal(
      root: 'https://maps.co.kern.ca.us/arcgis/rest/services',
      publisher: 'Kern County',
      tier: PortalTier.countyPortal,
      serviceCount: 42,
    ),
  ],
  'ca_kings': [
    GisPortal(
      root:
          'https://services1.arcgis.com/sTaVXkn06Nqew9yU/arcgis/rest/services',
      publisher: 'Sierra Nevada Conservancy',
      tier: PortalTier.partner,
      serviceCount: 69,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/sTaVXkn06Nqew9yU/arcgis/rest/services',
      publisher: 'Sierra Nevada Conservancy',
      tier: PortalTier.partner,
      serviceCount: 5,
    ),
  ],
  'ca_lake': [
    GisPortal(
      root: 'https://gis.lakecountyca.gov/server/rest/services',
      publisher: 'Lake County',
      tier: PortalTier.countyPortal,
      serviceCount: 156,
    ),
  ],
  'ca_lassen': [
    GisPortal(
      root:
          'https://services7.arcgis.com/RUPP32QG1q5ljV4l/arcgis/rest/services',
      publisher: 'Lassen County',
      tier: PortalTier.countyPortal,
      serviceCount: 4,
    ),
  ],
  'ca_los_angeles': [
    GisPortal(
      root: 'https://services.arcgis.com/RmCCgQtiZLDCtblq/arcgis/rest/services',
      publisher: 'Los Angeles County',
      tier: PortalTier.countyPortal,
      serviceCount: 4754,
    ),
    GisPortal(
      root: 'https://dpw.gis.lacounty.gov/dpw/rest/services',
      publisher: 'Los Angeles County',
      tier: PortalTier.countyPortal,
      serviceCount: 128,
    ),
    GisPortal(
      root: 'https://arcgis.gis.lacounty.gov/arcgis/rest/services',
      publisher: 'Los Angeles County',
      tier: PortalTier.countyPortal,
      serviceCount: 103,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/RmCCgQtiZLDCtblq/arcgis/rest/services',
      publisher: 'Los Angeles County',
      tier: PortalTier.countyPortal,
      serviceCount: 87,
    ),
    GisPortal(
      root: 'https://public.gis.lacounty.gov/public/rest/services',
      publisher: 'Los Angeles County',
      tier: PortalTier.countyPortal,
      serviceCount: 26,
    ),
    GisPortal(
      root: 'https://image.gis.lacounty.gov/image/rest/services',
      publisher: 'Los Angeles County',
      tier: PortalTier.countyPortal,
      serviceCount: 25,
    ),
    GisPortal(
      root: 'https://cache.gis.lacounty.gov/cache/rest/services',
      publisher: 'Los Angeles County',
      tier: PortalTier.countyPortal,
      serviceCount: 22,
    ),
    GisPortal(
      root: 'https://assessor.gis.lacounty.gov/assessor/rest/services',
      publisher: 'Los Angeles County',
      tier: PortalTier.countyPortal,
      serviceCount: 10,
    ),
    GisPortal(
      root:
          'https://vectortileservices.arcgis.com/RmCCgQtiZLDCtblq/arcgis/rest/services',
      publisher: 'Los Angeles County',
      tier: PortalTier.countyPortal,
      serviceCount: 0,
    ),
  ],
  'ca_marin': [
    GisPortal(
      root:
          'https://services6.arcgis.com/T8eS7sop5hLmgRRH/arcgis/rest/services',
      publisher: 'Marin County',
      tier: PortalTier.countyPortal,
      serviceCount: 493,
    ),
    GisPortal(
      root: 'https://gis.marinpublic.com/arcgis/rest/services',
      publisher: 'Marin County',
      tier: PortalTier.countyPortal,
      serviceCount: 173,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/T8eS7sop5hLmgRRH/arcgis/rest/services',
      publisher: 'Marin County',
      tier: PortalTier.countyPortal,
      serviceCount: 28,
    ),
  ],
  'ca_mariposa': [
    GisPortal(
      root:
          'https://services2.arcgis.com/wEula7SYiezXcdRv/arcgis/rest/services',
      publisher: 'Mariposa County',
      tier: PortalTier.countyPortal,
      serviceCount: 354,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/wEula7SYiezXcdRv/arcgis/rest/services',
      publisher: 'Mariposa County',
      tier: PortalTier.countyPortal,
      serviceCount: 3,
    ),
  ],
  'ca_mendocino': [
    GisPortal(
      root:
          'https://services5.arcgis.com/8y4r60VTvWj2wnDH/arcgis/rest/services',
      publisher: 'Mendocino County',
      tier: PortalTier.countyPortal,
      serviceCount: 42,
    ),
  ],
  'ca_merced': [
    GisPortal(
      root:
          'https://services6.arcgis.com/LYh3hRvKq5ASgAVM/arcgis/rest/services',
      publisher: 'Merced County',
      tier: PortalTier.countyPortal,
      serviceCount: 777,
    ),
    GisPortal(
      root: 'https://gis.countyofmerced.com/server/rest/services',
      publisher: 'Merced County',
      tier: PortalTier.countyPortal,
      serviceCount: 203,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/LYh3hRvKq5ASgAVM/arcgis/rest/services',
      publisher: 'Merced County',
      tier: PortalTier.countyPortal,
      serviceCount: 75,
    ),
    GisPortal(
      root:
          'https://vectortileservices6.arcgis.com/LYh3hRvKq5ASgAVM/arcgis/rest/services',
      publisher: 'Merced County',
      tier: PortalTier.countyPortal,
      serviceCount: 0,
    ),
  ],
  'ca_modoc': [
    GisPortal(
      root:
          'https://services6.arcgis.com/MIuDOWgDqUpHjCEg/arcgis/rest/services',
      publisher: 'Modoc County',
      tier: PortalTier.countyPortal,
      serviceCount: 5,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/MIuDOWgDqUpHjCEg/arcgis/rest/services',
      publisher: 'Modoc County',
      tier: PortalTier.countyPortal,
      serviceCount: 1,
    ),
  ],
  'ca_monterey': [
    GisPortal(
      root: 'https://maps.co.monterey.ca.us/server/rest/services',
      publisher: 'Monterey County',
      tier: PortalTier.countyPortal,
      serviceCount: 652,
    ),
    GisPortal(
      root:
          'https://services2.arcgis.com/nOGTdfb4kF4dZljH/arcgis/rest/services',
      publisher: 'Monterey County',
      tier: PortalTier.countyPortal,
      serviceCount: 442,
    ),
  ],
  'ca_napa': [
    GisPortal(
      root:
          'https://services1.arcgis.com/Ko5rxt00spOfjMqj/arcgis/rest/services',
      publisher: 'Napa County',
      tier: PortalTier.countyPortal,
      serviceCount: 379,
    ),
    GisPortal(
      root: 'https://gis.napacounty.gov/arcgis/rest/services',
      publisher: 'Napa County',
      tier: PortalTier.countyPortal,
      serviceCount: 199,
    ),
    GisPortal(
      root: 'https://gis.napa.ca.gov/arcgis/rest/services',
      publisher: 'Napa County',
      tier: PortalTier.countyPortal,
      serviceCount: 74,
    ),
    GisPortal(
      root: 'https://gis.cityofnapa.org/arcgis/rest/services',
      publisher: 'Napa County',
      tier: PortalTier.countyPortal,
      serviceCount: 57,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/Ko5rxt00spOfjMqj/arcgis/rest/services',
      publisher: 'Napa County',
      tier: PortalTier.countyPortal,
      serviceCount: 1,
    ),
  ],
  'ca_nevada': [
    GisPortal(
      root:
          'https://services1.arcgis.com/UvqJJ6GFv4u5BZQj/arcgis/rest/services',
      publisher: 'Nevada County',
      tier: PortalTier.countyPortal,
      serviceCount: 187,
    ),
    GisPortal(
      root: 'https://maps.nevadacountyca.gov/arcgis/rest/services',
      publisher: 'Nevada County',
      tier: PortalTier.countyPortal,
      serviceCount: 51,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/UvqJJ6GFv4u5BZQj/arcgis/rest/services',
      publisher: 'Nevada County',
      tier: PortalTier.countyPortal,
      serviceCount: 6,
    ),
    GisPortal(
      root:
          'https://vectortileservices1.arcgis.com/UvqJJ6GFv4u5BZQj/arcgis/rest/services',
      publisher: 'Nevada County',
      tier: PortalTier.countyPortal,
      serviceCount: 0,
    ),
  ],
  'ca_orange': [
    GisPortal(
      root: 'https://ocgis.com/arcpub/rest/services',
      publisher: 'Orange County',
      tier: PortalTier.countyPortal,
      serviceCount: 652,
    ),
    GisPortal(
      root: 'https://www.ocgis.com/survey/rest/services',
      publisher: 'Orange County',
      tier: PortalTier.countyPortal,
      serviceCount: 187,
    ),
  ],
  'ca_placer': [
    GisPortal(
      root: 'https://services.sacog.org/hosting/rest/services',
      publisher: 'services.sacog.org',
      tier: PortalTier.partner,
      serviceCount: 646,
    ),
    GisPortal(
      root: 'https://services.sacog.org/hosting/rest/services',
      publisher: 'services.sacog.org',
      tier: PortalTier.partner,
      serviceCount: 646,
    ),
    GisPortal(
      root:
          'https://services6.arcgis.com/YBp5dUuxCMd8W1EI/arcgis/rest/services',
      publisher: 'Sacramento Area Council of Governments',
      tier: PortalTier.partner,
      serviceCount: 472,
    ),
    GisPortal(
      root:
          'https://services9.arcgis.com/NENkjkswKTzMfG3A/arcgis/rest/services',
      publisher: 'services9.arcgis.com',
      tier: PortalTier.partner,
      serviceCount: 229,
    ),
    GisPortal(
      root: 'https://maps.trpa.org/server/rest/services',
      publisher: 'maps.trpa.org',
      tier: PortalTier.partner,
      serviceCount: 134,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/YBp5dUuxCMd8W1EI/arcgis/rest/services',
      publisher: 'Sacramento Area Council of Governments',
      tier: PortalTier.partner,
      serviceCount: 10,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/NENkjkswKTzMfG3A/arcgis/rest/services',
      publisher: 'tiles.arcgis.com',
      tier: PortalTier.partner,
      serviceCount: 1,
    ),
  ],
  'ca_plumas': [
    GisPortal(
      root: 'https://services.arcgis.com/BLN4oKB0N1YSgvY8/arcgis/rest/services',
      publisher: 'CA Governor\'s Office of Emergency Services',
      tier: PortalTier.partner,
      serviceCount: 999,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/BLN4oKB0N1YSgvY8/arcgis/rest/services',
      publisher: 'CA Governor\'s Office of Emergency Services',
      tier: PortalTier.partner,
      serviceCount: 29,
    ),
  ],
  'ca_riverside': [
    GisPortal(
      root:
          'https://services1.arcgis.com/pWmBUdSlVpXStHU6/arcgis/rest/services',
      publisher: 'Riverside County',
      tier: PortalTier.countyPortal,
      serviceCount: 1370,
    ),
    GisPortal(
      root: 'https://gis.countyofriverside.us/arcgis_mapping/rest/services',
      publisher: 'Riverside County',
      tier: PortalTier.countyPortal,
      serviceCount: 66,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/pWmBUdSlVpXStHU6/arcgis/rest/services',
      publisher: 'Riverside County',
      tier: PortalTier.countyPortal,
      serviceCount: 56,
    ),
    GisPortal(
      root: 'https://gis1.countyofriverside.us/arcgis/rest/services',
      publisher: 'Riverside County',
      tier: PortalTier.countyPortal,
      serviceCount: 48,
    ),
    GisPortal(
      root: 'https://gis.countyofriverside.us/arcgis/rest/services',
      publisher: 'Riverside County',
      tier: PortalTier.countyPortal,
      serviceCount: 41,
    ),
    GisPortal(
      root:
          'https://vectortileservices1.arcgis.com/pWmBUdSlVpXStHU6/arcgis/rest/services',
      publisher: 'Riverside County',
      tier: PortalTier.countyPortal,
      serviceCount: 0,
    ),
  ],
  'ca_sacramento': [
    GisPortal(
      root:
          'https://services1.arcgis.com/5NARefyPVtAeuJPU/arcgis/rest/services',
      publisher: 'Sacramento County',
      tier: PortalTier.countyPortal,
      serviceCount: 222,
    ),
    GisPortal(
      root: 'https://mapservices.gis.saccounty.gov/ArcGIS/rest/services',
      publisher: 'Sacramento County',
      tier: PortalTier.countyPortal,
      serviceCount: 43,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/5NARefyPVtAeuJPU/arcgis/rest/services',
      publisher: 'Sacramento County',
      tier: PortalTier.countyPortal,
      serviceCount: 3,
    ),
  ],
  'ca_san_benito': [
    GisPortal(
      root:
          'https://services2.arcgis.com/NjMFCzThTMQy3AJa/arcgis/rest/services',
      publisher: 'San Benito County',
      tier: PortalTier.countyPortal,
      serviceCount: 426,
    ),
    GisPortal(
      root: 'https://gisweb.cosb.us/arcgis/rest/services',
      publisher: 'San Benito County',
      tier: PortalTier.countyPortal,
      serviceCount: 55,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/NjMFCzThTMQy3AJa/arcgis/rest/services',
      publisher: 'San Benito County',
      tier: PortalTier.countyPortal,
      serviceCount: 1,
    ),
  ],
  'ca_san_bernardino': [
    GisPortal(
      root: 'https://services.arcgis.com/aA3snZwJfFkVyDuP/arcgis/rest/services',
      publisher: 'San Bernardino County',
      tier: PortalTier.countyPortal,
      serviceCount: 1096,
    ),
    GisPortal(
      root: 'https://maps.sbcounty.gov/arcgis/rest/services',
      publisher: 'San Bernardino County',
      tier: PortalTier.countyPortal,
      serviceCount: 85,
    ),
    GisPortal(
      root: 'https://maps.sbcounty.gov/img/rest/services',
      publisher: 'San Bernardino County',
      tier: PortalTier.countyPortal,
      serviceCount: 69,
    ),
    GisPortal(
      root: 'https://maps.sbcounty.gov/gis/rest/services',
      publisher: 'San Bernardino County',
      tier: PortalTier.countyPortal,
      serviceCount: 16,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/aA3snZwJfFkVyDuP/arcgis/rest/services',
      publisher: 'San Bernardino County',
      tier: PortalTier.countyPortal,
      serviceCount: 8,
    ),
  ],
  'ca_san_diego': [
    GisPortal(
      root:
          'https://services1.arcgis.com/1vIhDJwtG5eNmiqX/arcgis/rest/services',
      publisher: 'San Diego County',
      tier: PortalTier.countyPortal,
      serviceCount: 197,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/1vIhDJwtG5eNmiqX/arcgis/rest/services',
      publisher: 'San Diego County',
      tier: PortalTier.countyPortal,
      serviceCount: 18,
    ),
  ],
  'ca_san_francisco': [
    GisPortal(
      root: 'https://services.arcgis.com/Zs2aNLFN00jrS4gG/arcgis/rest/services',
      publisher: 'San Francisco County',
      tier: PortalTier.countyPortal,
      serviceCount: 2075,
    ),
    GisPortal(
      root: 'https://maps.sfdpw.org/arcgis/rest/services',
      publisher: 'San Francisco County',
      tier: PortalTier.countyPortal,
      serviceCount: 57,
    ),
    GisPortal(
      root: 'https://services.sfmta.com/arcgis/rest/services',
      publisher: 'San Francisco County',
      tier: PortalTier.countyPortal,
      serviceCount: 53,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/Zs2aNLFN00jrS4gG/arcgis/rest/services',
      publisher: 'San Francisco County',
      tier: PortalTier.countyPortal,
      serviceCount: 36,
    ),
    GisPortal(
      root:
          'https://tiledimageservices.arcgis.com/Zs2aNLFN00jrS4gG/arcgis/rest/services',
      publisher: 'San Francisco County',
      tier: PortalTier.countyPortal,
      serviceCount: 0,
    ),
  ],
  'ca_san_joaquin': [
    GisPortal(
      root:
          'https://services2.arcgis.com/GQhSReJEO6f7tsvy/arcgis/rest/services',
      publisher: 'San Joaquin County',
      tier: PortalTier.countyPortal,
      serviceCount: 488,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/GQhSReJEO6f7tsvy/arcgis/rest/services',
      publisher: 'San Joaquin County',
      tier: PortalTier.countyPortal,
      serviceCount: 1,
    ),
  ],
  'ca_san_luis_obispo': [
    GisPortal(
      root:
          'https://services6.arcgis.com/M6e56DqzbdJf20YO/arcgis/rest/services',
      publisher: 'San Luis Obispo County',
      tier: PortalTier.countyPortal,
      serviceCount: 71,
    ),
    GisPortal(
      root: 'https://gis.slocounty.ca.gov/arcgis/rest/services',
      publisher: 'San Luis Obispo County',
      tier: PortalTier.countyPortal,
      serviceCount: 59,
    ),
  ],
  'ca_san_mateo': [
    GisPortal(
      root: 'https://services.arcgis.com/yq3FgOI44hYHAFVZ/arcgis/rest/services',
      publisher: 'San Mateo County',
      tier: PortalTier.countyPortal,
      serviceCount: 1046,
    ),
    GisPortal(
      root: 'https://gis.smcgov.org/maps/rest/services',
      publisher: 'San Mateo County',
      tier: PortalTier.countyPortal,
      serviceCount: 100,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/yq3FgOI44hYHAFVZ/arcgis/rest/services',
      publisher: 'San Mateo County',
      tier: PortalTier.countyPortal,
      serviceCount: 16,
    ),
    GisPortal(
      root: 'https://gis.smcgov.org/image/rest/services',
      publisher: 'San Mateo County',
      tier: PortalTier.countyPortal,
      serviceCount: 15,
    ),
    GisPortal(
      root:
          'https://tiledimageservices.arcgis.com/yq3FgOI44hYHAFVZ/arcgis/rest/services',
      publisher: 'San Mateo County',
      tier: PortalTier.countyPortal,
      serviceCount: 0,
    ),
  ],
  'ca_santa_barbara': [
    GisPortal(
      root: 'https://services.arcgis.com/KkJhFbLnXVqahKz2/arcgis/rest/services',
      publisher: 'Santa Barbara County',
      tier: PortalTier.countyPortal,
      serviceCount: 389,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/KkJhFbLnXVqahKz2/arcgis/rest/services',
      publisher: 'Santa Barbara County',
      tier: PortalTier.countyPortal,
      serviceCount: 21,
    ),
  ],
  'ca_santa_clara': [
    GisPortal(
      root: 'https://services.arcgis.com/NkcnS0qk4w2wasOJ/arcgis/rest/services',
      publisher: 'Santa Clara County',
      tier: PortalTier.countyPortal,
      serviceCount: 188,
    ),
    GisPortal(
      root:
          'https://services2.arcgis.com/tcv2cMrq63AgvbHF/ArcGIS/rest/services',
      publisher: 'Santa Clara County',
      tier: PortalTier.countyPortal,
      serviceCount: 148,
    ),
    GisPortal(
      root: 'https://maps.santaclaracounty.gov/server/rest/services',
      publisher: 'Santa Clara County',
      tier: PortalTier.countyPortal,
      serviceCount: 61,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/NkcnS0qk4w2wasOJ/arcgis/rest/services',
      publisher: 'Santa Clara County',
      tier: PortalTier.countyPortal,
      serviceCount: 7,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/tcv2cMrq63AgvbHF/arcgis/rest/services',
      publisher: 'Santa Clara County',
      tier: PortalTier.countyPortal,
      serviceCount: 7,
    ),
    GisPortal(
      root:
          'https://tiledimageservices2.arcgis.com/tcv2cMrq63AgvbHF/arcgis/rest/services',
      publisher: 'Santa Clara County',
      tier: PortalTier.countyPortal,
      serviceCount: 0,
    ),
  ],
  'ca_santa_cruz': [
    GisPortal(
      root:
          'https://services5.arcgis.com/RjgxPpXv8MHiv19f/arcgis/rest/services',
      publisher: 'Santa Cruz County',
      tier: PortalTier.countyPortal,
      serviceCount: 96,
    ),
    GisPortal(
      root: 'https://vwgisportal2.santacruzca.gov/arcgis/rest/services',
      publisher: 'Santa Cruz County',
      tier: PortalTier.countyPortal,
      serviceCount: 69,
    ),
    GisPortal(
      root: 'https://gis.santacruzcountyca.gov/server/rest/services',
      publisher: 'Santa Cruz County',
      tier: PortalTier.countyPortal,
      serviceCount: 34,
    ),
  ],
  'ca_shasta': [
    GisPortal(
      root:
          'https://services2.arcgis.com/22p1CUjMjjRWlw6O/arcgis/rest/services',
      publisher: 'Shasta County',
      tier: PortalTier.countyPortal,
      serviceCount: 162,
    ),
    GisPortal(
      root: 'https://gis.shastacounty.gov/arcgis/rest/services',
      publisher: 'Shasta County',
      tier: PortalTier.countyPortal,
      serviceCount: 156,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/22p1CUjMjjRWlw6O/arcgis/rest/services',
      publisher: 'Shasta County',
      tier: PortalTier.countyPortal,
      serviceCount: 2,
    ),
  ],
  'ca_sierra': [
    GisPortal(
      root:
          'https://services6.arcgis.com/MtSzpOZ2FMytnchL/arcgis/rest/services',
      publisher: 'Sierra County',
      tier: PortalTier.countyPortal,
      serviceCount: 37,
    ),
  ],
  'ca_siskiyou': [
    GisPortal(
      root:
          'https://services3.arcgis.com/JmPiYilyU1x5zuxM/arcgis/rest/services',
      publisher: 'Siskiyou County',
      tier: PortalTier.countyPortal,
      serviceCount: 138,
    ),
    GisPortal(
      root:
          'https://vectortileservices3.arcgis.com/JmPiYilyU1x5zuxM/arcgis/rest/services',
      publisher: 'Siskiyou County',
      tier: PortalTier.countyPortal,
      serviceCount: 0,
    ),
  ],
  'ca_sonoma': [
    GisPortal(
      root:
          'https://services1.arcgis.com/P5Mv5GY5S66M8Z1Q/arcgis/rest/services',
      publisher: 'Sonoma County',
      tier: PortalTier.countyPortal,
      serviceCount: 717,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/P5Mv5GY5S66M8Z1Q/arcgis/rest/services',
      publisher: 'Sonoma County',
      tier: PortalTier.countyPortal,
      serviceCount: 39,
    ),
  ],
  'ca_stanislaus': [
    GisPortal(
      root: 'https://services.arcgis.com/EeYBJFxLdUojipYa/arcgis/rest/services',
      publisher: 'Stanislaus County',
      tier: PortalTier.countyPortal,
      serviceCount: 99,
    ),
    GisPortal(
      root: 'https://gis.stancounty.com/arcgis1/rest/services',
      publisher: 'Stanislaus County',
      tier: PortalTier.countyPortal,
      serviceCount: 32,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/EeYBJFxLdUojipYa/arcgis/rest/services',
      publisher: 'Stanislaus County',
      tier: PortalTier.countyPortal,
      serviceCount: 2,
    ),
    GisPortal(
      root:
          'https://vectortileservices.arcgis.com/EeYBJFxLdUojipYa/arcgis/rest/services',
      publisher: 'Stanislaus County',
      tier: PortalTier.countyPortal,
      serviceCount: 0,
    ),
  ],
  'ca_sutter': [
    GisPortal(
      root: 'https://gis.suttercounty.org/server/rest/services',
      publisher: 'Sutter County',
      tier: PortalTier.countyPortal,
      serviceCount: 142,
    ),
    GisPortal(
      root:
          'https://services6.arcgis.com/rHMUPKWdiOvdGXkw/arcgis/rest/services',
      publisher: 'Sutter County',
      tier: PortalTier.countyPortal,
      serviceCount: 121,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/rHMUPKWdiOvdGXkw/arcgis/rest/services',
      publisher: 'Sutter County',
      tier: PortalTier.countyPortal,
      serviceCount: 3,
    ),
  ],
  'ca_tehama': [
    GisPortal(
      root:
          'https://services2.arcgis.com/3iNbxbY9zhyxPvde/arcgis/rest/services',
      publisher: 'Tehama County Transportation Commission Geospatial Data',
      tier: PortalTier.partner,
      serviceCount: 249,
    ),
    GisPortal(
      root:
          'https://services6.arcgis.com/snwvZ3EmaoXJiugR/arcgis/rest/services',
      publisher: 'California Department of Tax and Fee Administration',
      tier: PortalTier.partner,
      serviceCount: 16,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/3iNbxbY9zhyxPvde/arcgis/rest/services',
      publisher: 'Tehama County Transportation Commission Geospatial Data',
      tier: PortalTier.partner,
      serviceCount: 2,
    ),
  ],
  'ca_tulare': [
    GisPortal(
      root:
          'https://services2.arcgis.com/bYBANhmQGwSSLC0l/arcgis/rest/services',
      publisher: 'Tulare County',
      tier: PortalTier.countyPortal,
      serviceCount: 259,
    ),
    GisPortal(
      root: 'https://maps.tulare.ca.gov/server/rest/services',
      publisher: 'Tulare County',
      tier: PortalTier.countyPortal,
      serviceCount: 56,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/bYBANhmQGwSSLC0l/arcgis/rest/services',
      publisher: 'Tulare County',
      tier: PortalTier.countyPortal,
      serviceCount: 8,
    ),
    GisPortal(
      root:
          'https://vectortileservices2.arcgis.com/bYBANhmQGwSSLC0l/arcgis/rest/services',
      publisher: 'Tulare County',
      tier: PortalTier.countyPortal,
      serviceCount: 0,
    ),
  ],
  'ca_tuolumne': [
    GisPortal(
      root:
          'https://services3.arcgis.com/afQpMaliVrwHS7Ud/arcgis/rest/services',
      publisher: 'Tuolumne County',
      tier: PortalTier.countyPortal,
      serviceCount: 253,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/afQpMaliVrwHS7Ud/arcgis/rest/services',
      publisher: 'Tuolumne County',
      tier: PortalTier.countyPortal,
      serviceCount: 1,
    ),
  ],
  'ca_ventura': [
    GisPortal(
      root: 'https://gis.ventura.org/arcgis/rest/services',
      publisher: 'Ventura County',
      tier: PortalTier.countyPortal,
      serviceCount: 245,
    ),
    GisPortal(
      root: 'https://maps.venturacounty.gov/arcgis/rest/services',
      publisher: 'Ventura County',
      tier: PortalTier.countyPortal,
      serviceCount: 242,
    ),
    GisPortal(
      root:
          'https://services2.arcgis.com/XJ5Tb7dTYtAMoyYT/arcgis/rest/services',
      publisher: 'Ventura County',
      tier: PortalTier.countyPortal,
      serviceCount: 145,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/XJ5Tb7dTYtAMoyYT/arcgis/rest/services',
      publisher: 'Ventura County',
      tier: PortalTier.countyPortal,
      serviceCount: 13,
    ),
  ],
  'ca_yolo': [
    GisPortal(
      root:
          'https://services9.arcgis.com/mt4kvYhNXSa5AqLG/arcgis/rest/services',
      publisher: 'UC Davis',
      tier: PortalTier.partner,
      serviceCount: 2017,
    ),
    GisPortal(
      root: 'https://services.sacog.org/hosting/rest/services',
      publisher: 'services.sacog.org',
      tier: PortalTier.partner,
      serviceCount: 646,
    ),
    GisPortal(
      root:
          'https://services6.arcgis.com/YBp5dUuxCMd8W1EI/arcgis/rest/services',
      publisher: 'Sacramento Area Council of Governments',
      tier: PortalTier.partner,
      serviceCount: 472,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/mt4kvYhNXSa5AqLG/arcgis/rest/services',
      publisher: 'UC Davis',
      tier: PortalTier.partner,
      serviceCount: 99,
    ),
    GisPortal(
      root: 'https://gis.ucdavis.edu/server/rest/services',
      publisher: 'gis.ucdavis.edu',
      tier: PortalTier.partner,
      serviceCount: 45,
    ),
    GisPortal(
      root:
          'https://tiles.arcgis.com/tiles/YBp5dUuxCMd8W1EI/arcgis/rest/services',
      publisher: 'Sacramento Area Council of Governments',
      tier: PortalTier.partner,
      serviceCount: 10,
    ),
  ],
  'ca_yuba': [
    GisPortal(
      root: 'https://gis.yuba.org/arcgis/rest/services',
      publisher: 'Yuba County',
      tier: PortalTier.countyPortal,
      serviceCount: 35,
    ),
  ],
};

/// Incorporated city catalogues, keyed by county id.
///
/// A city's catalogue applies to the city, not the county, so each carries
/// the bounds that say where it is worth offering. A city absent here
/// published nothing this build could find — or publishes through a root the
/// county tier already lists, which is deliberately not repeated.
const cityPortals = <String, List<CityPortals>>{
  'ca_alameda': [
    CityPortals(
      name: 'Berkeley',
      bounds: GeoBounds(
        west: -122.3241,
        south: 37.8467,
        east: -122.2342,
        north: 37.9058,
      ),
      portals: [
        GisPortal(
          root:
              'https://services1.arcgis.com/IYiCpZoSIq9lAxi8/arcgis/rest/services',
          publisher: 'City of Berkeley',
          tier: PortalTier.city,
          serviceCount: 465,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/IYiCpZoSIq9lAxi8/arcgis/rest/services',
          publisher: 'City of Berkeley',
          tier: PortalTier.city,
          serviceCount: 21,
        ),
      ],
    ),
    CityPortals(
      name: 'Dublin',
      bounds: GeoBounds(
        west: -121.9878,
        south: 37.6978,
        east: -121.8326,
        north: 37.7451,
      ),
      portals: [
        GisPortal(
          root: 'https://gis.dublin.ca.gov/arcgis/rest/services',
          publisher: 'City of Dublin',
          tier: PortalTier.city,
          serviceCount: 101,
        ),
        GisPortal(
          root: 'https://gis111.dublin.ca.gov/arcgis/rest/services',
          publisher: 'City of Dublin',
          tier: PortalTier.city,
          serviceCount: 68,
        ),
        GisPortal(
          root:
              'https://services3.arcgis.com/YduA3dd0porqlP5K/arcgis/rest/services',
          publisher: 'City of Dublin',
          tier: PortalTier.city,
          serviceCount: 11,
        ),
      ],
    ),
    CityPortals(
      name: 'Emeryville',
      bounds: GeoBounds(
        west: -122.3144,
        south: 37.8271,
        east: -122.2756,
        north: 37.85,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/ljOdqLVbHpS7dOJQ/arcgis/rest/services',
          publisher: 'City of Emeryville',
          tier: PortalTier.city,
          serviceCount: 193,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/ljOdqLVbHpS7dOJQ/arcgis/rest/services',
          publisher: 'City of Emeryville',
          tier: PortalTier.city,
          serviceCount: 6,
        ),
      ],
    ),
    CityPortals(
      name: 'Hayward',
      bounds: GeoBounds(
        west: -122.1605,
        south: 37.5606,
        east: -121.9204,
        north: 37.6899,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/VRO5V8PH7DzSE6AU/arcgis/rest/services',
          publisher: 'City of Hayward',
          tier: PortalTier.city,
          serviceCount: 154,
        ),
        GisPortal(
          root: 'https://maps.hayward-ca.gov/arcgis/rest/services',
          publisher: 'City of Hayward',
          tier: PortalTier.city,
          serviceCount: 134,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/VRO5V8PH7DzSE6AU/arcgis/rest/services',
          publisher: 'City of Hayward',
          tier: PortalTier.city,
          serviceCount: 6,
        ),
      ],
    ),
    CityPortals(
      name: 'San Leandro',
      bounds: GeoBounds(
        west: -122.2022,
        south: 37.6679,
        east: -122.1224,
        north: 37.7424,
      ),
      portals: [
        GisPortal(
          root:
              'https://services.arcgis.com/nFaSPZoTjS78xXjw/arcgis/rest/services',
          publisher: 'City of San Leandro',
          tier: PortalTier.city,
          serviceCount: 59,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/nFaSPZoTjS78xXjw/arcgis/rest/services',
          publisher: 'City of San Leandro',
          tier: PortalTier.city,
          serviceCount: 6,
        ),
      ],
    ),
  ],
  'ca_contra_costa': [
    CityPortals(
      name: 'Antioch',
      bounds: GeoBounds(
        west: -121.8606,
        south: 37.9207,
        east: -121.7324,
        north: 38.0291,
      ),
      portals: [
        GisPortal(
          root:
              'https://services5.arcgis.com/9wr5naT5FqBDBXHa/arcgis/rest/services',
          publisher: 'City of Antioch',
          tier: PortalTier.city,
          serviceCount: 13,
        ),
      ],
    ),
    CityPortals(
      name: 'Oakley',
      bounds: GeoBounds(
        west: -121.7563,
        south: 37.9688,
        east: -121.6226,
        north: 38.0211,
      ),
      portals: [
        GisPortal(
          root:
              'https://services8.arcgis.com/ql5SF28UZRL4qU2a/arcgis/rest/services',
          publisher: 'City of Oakley',
          tier: PortalTier.city,
          serviceCount: 84,
        ),
      ],
    ),
    CityPortals(
      name: 'Pittsburg',
      bounds: GeoBounds(
        west: -121.9861,
        south: 37.9832,
        east: -121.8332,
        north: 38.0438,
      ),
      portals: [
        GisPortal(
          root:
              'https://services6.arcgis.com/X3LnFc9yy269fH43/arcgis/rest/services',
          publisher: 'City of Pittsburg',
          tier: PortalTier.city,
          serviceCount: 36,
        ),
      ],
    ),
  ],
  'ca_fresno': [
    CityPortals(
      name: 'Coalinga',
      bounds: GeoBounds(
        west: -120.3743,
        south: 36.1154,
        east: -120.2361,
        north: 36.1799,
      ),
      portals: [
        GisPortal(
          root:
              'https://services5.arcgis.com/vHqEEjP5zUpYwtVC/arcgis/rest/services',
          publisher: 'City of Coalinga',
          tier: PortalTier.city,
          serviceCount: 21,
        ),
      ],
    ),
    CityPortals(
      name: 'Fresno',
      bounds: GeoBounds(
        west: -119.9344,
        south: 36.6627,
        east: -119.6505,
        north: 36.9106,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/WkBUojyNPhsWOk1W/arcgis/rest/services',
          publisher: 'City of Fresno',
          tier: PortalTier.city,
          serviceCount: 328,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/WkBUojyNPhsWOk1W/arcgis/rest/services',
          publisher: 'City of Fresno',
          tier: PortalTier.city,
          serviceCount: 29,
        ),
        GisPortal(
          root: 'https://gis4u.fresno.gov/arcgis/rest/services',
          publisher: 'City of Fresno',
          tier: PortalTier.city,
          serviceCount: 5,
        ),
      ],
    ),
    CityPortals(
      name: 'Kerman',
      bounds: GeoBounds(
        west: -120.0831,
        south: 36.7057,
        east: -120.0367,
        north: 36.7367,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/FwA5y09TyGR18Fl8/arcgis/rest/services',
          publisher: 'City of Kerman',
          tier: PortalTier.city,
          serviceCount: 7,
        ),
      ],
    ),
    CityPortals(
      name: 'Sanger',
      bounds: GeoBounds(
        west: -119.5832,
        south: 36.6412,
        east: -119.5293,
        north: 36.7365,
      ),
      portals: [
        GisPortal(
          root:
              'https://services7.arcgis.com/SR9egBwblQbNUJ8C/arcgis/rest/services',
          publisher: 'City of Sanger',
          tier: PortalTier.city,
          serviceCount: 15,
        ),
      ],
    ),
  ],
  'ca_kern': [
    CityPortals(
      name: 'Bakersfield',
      bounds: GeoBounds(
        west: -119.2653,
        south: 35.194,
        east: -118.7727,
        north: 35.4472,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/OKildAHLkXjQX8Ca/arcgis/rest/services',
          publisher: 'City of Bakersfield',
          tier: PortalTier.city,
          serviceCount: 203,
        ),
        GisPortal(
          root: 'https://gis.bakersfieldcity.us/webmaps/rest/services',
          publisher: 'City of Bakersfield',
          tier: PortalTier.city,
          serviceCount: 118,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/OKildAHLkXjQX8Ca/arcgis/rest/services',
          publisher: 'City of Bakersfield',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
    CityPortals(
      name: 'California',
      bounds: GeoBounds(
        west: -118.1354,
        south: 35.0131,
        east: -117.6312,
        north: 35.2762,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/uknczv4rpevve42E/arcgis/rest/services',
          publisher: 'City of California',
          tier: PortalTier.city,
          serviceCount: 165,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/uknczv4rpevve42E/arcgis/rest/services',
          publisher: 'City of California',
          tier: PortalTier.city,
          serviceCount: 15,
        ),
        GisPortal(
          root: 'https://apps.geo.fpac.usda.gov/geo-imagery/rest/services',
          publisher: 'City of California',
          tier: PortalTier.city,
          serviceCount: 4,
        ),
      ],
    ),
    CityPortals(
      name: 'Shafter',
      bounds: GeoBounds(
        west: -119.3505,
        south: 35.4414,
        east: -119.0994,
        north: 35.5332,
      ),
      portals: [
        GisPortal(
          root: 'https://gis.shafter.com/server/rest/services',
          publisher: 'City of Shafter',
          tier: PortalTier.city,
          serviceCount: 97,
        ),
        GisPortal(
          root:
              'https://services2.arcgis.com/LukbLC9Gps89zZa7/arcgis/rest/services',
          publisher: 'City of Shafter',
          tier: PortalTier.city,
          serviceCount: 39,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/LukbLC9Gps89zZa7/arcgis/rest/services',
          publisher: 'City of Shafter',
          tier: PortalTier.city,
          serviceCount: 3,
        ),
      ],
    ),
  ],
  'ca_kings': [
    CityPortals(
      name: 'Corcoran',
      bounds: GeoBounds(
        west: -119.5899,
        south: 36.0414,
        east: -119.5363,
        north: 36.1379,
      ),
      portals: [
        GisPortal(
          root:
              'https://services7.arcgis.com/dW1BZDzLPc20qEPO/arcgis/rest/services',
          publisher: 'City of Corcoran',
          tier: PortalTier.city,
          serviceCount: 16,
        ),
      ],
    ),
    CityPortals(
      name: 'Hanford',
      bounds: GeoBounds(
        west: -119.6911,
        south: 36.2607,
        east: -119.5923,
        north: 36.3719,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/xJA6NTvwhTUZnE2Z/arcgis/rest/services',
          publisher: 'City of Hanford',
          tier: PortalTier.city,
          serviceCount: 11,
        ),
        GisPortal(
          root: 'https://maps.hanfordca.gov/server/rest/services',
          publisher: 'City of Hanford',
          tier: PortalTier.city,
          serviceCount: 10,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/xJA6NTvwhTUZnE2Z/arcgis/rest/services',
          publisher: 'City of Hanford',
          tier: PortalTier.city,
          serviceCount: 3,
        ),
      ],
    ),
    CityPortals(
      name: 'Lemoore',
      bounds: GeoBounds(
        west: -119.8435,
        south: 36.2549,
        east: -119.7643,
        north: 36.3896,
      ),
      portals: [
        GisPortal(
          root:
              'https://services8.arcgis.com/IX3Ksbq0XGWYwFfK/arcgis/rest/services',
          publisher: 'City of Lemoore',
          tier: PortalTier.city,
          serviceCount: 26,
        ),
      ],
    ),
  ],
  'ca_lake': [
    CityPortals(
      name: 'Clearlake',
      bounds: GeoBounds(
        west: -122.6997,
        south: 38.9198,
        east: -122.5764,
        north: 38.9943,
      ),
      portals: [
        GisPortal(
          root:
              'https://services5.arcgis.com/rMwJb9lQnwJCsC23/arcgis/rest/services',
          publisher: 'City of Clearlake',
          tier: PortalTier.city,
          serviceCount: 13,
        ),
      ],
    ),
  ],
  'ca_los_angeles': [
    CityPortals(
      name: 'Avalon',
      bounds: GeoBounds(
        west: -118.3467,
        south: 33.3181,
        east: -118.3082,
        north: 33.3562,
      ),
      portals: [
        GisPortal(
          root:
              'https://services6.arcgis.com/AmaMX17fQiEwdFuX/arcgis/rest/services',
          publisher: 'City of Avalon',
          tier: PortalTier.city,
          serviceCount: 4,
        ),
      ],
    ),
    CityPortals(
      name: 'Calabasas',
      bounds: GeoBounds(
        west: -118.7198,
        south: 34.1039,
        east: -118.6062,
        north: 34.1686,
      ),
      portals: [
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/SpdLoVK6cxWCmNhU/arcgis/rest/services',
          publisher: 'City of Calabasas',
          tier: PortalTier.city,
          serviceCount: 9,
        ),
        GisPortal(
          root:
              'https://services3.arcgis.com/SpdLoVK6cxWCmNhU/arcgis/rest/services',
          publisher: 'City of Calabasas',
          tier: PortalTier.city,
          serviceCount: 4,
        ),
      ],
    ),
    CityPortals(
      name: 'Carson',
      bounds: GeoBounds(
        west: -118.2865,
        south: 33.7926,
        east: -118.2059,
        north: 33.8862,
      ),
      portals: [
        GisPortal(
          root:
              'https://services1.arcgis.com/D9ezssdp37tr9wbT/arcgis/rest/services',
          publisher: 'City of Carson',
          tier: PortalTier.city,
          serviceCount: 88,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/D9ezssdp37tr9wbT/arcgis/rest/services',
          publisher: 'City of Carson',
          tier: PortalTier.city,
          serviceCount: 2,
        ),
      ],
    ),
    CityPortals(
      name: 'Cerritos',
      bounds: GeoBounds(
        west: -118.1086,
        south: 33.8459,
        east: -118.0287,
        north: 33.8874,
      ),
      portals: [
        GisPortal(
          root:
              'https://services7.arcgis.com/ARSJY3IpcOAaTE5R/arcgis/rest/services',
          publisher: 'City of Cerritos',
          tier: PortalTier.city,
          serviceCount: 16,
        ),
      ],
    ),
    CityPortals(
      name: 'Culver City',
      bounds: GeoBounds(
        west: -118.4484,
        south: 33.9769,
        east: -118.3696,
        north: 34.0351,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/LNAhiRpezPbHTIUO/arcgis/rest/services',
          publisher: 'City of Culver City',
          tier: PortalTier.city,
          serviceCount: 70,
        ),
      ],
    ),
    CityPortals(
      name: 'Downey',
      bounds: GeoBounds(
        west: -118.1704,
        south: 33.9023,
        east: -118.0903,
        north: 33.973,
      ),
      portals: [
        GisPortal(
          root:
              'https://services8.arcgis.com/6pr2WaSuWO79zliF/arcgis/rest/services',
          publisher: 'City of Downey',
          tier: PortalTier.city,
          serviceCount: 26,
        ),
      ],
    ),
    CityPortals(
      name: 'Gardena',
      bounds: GeoBounds(
        west: -118.3265,
        south: 33.8655,
        east: -118.2916,
        north: 33.9165,
      ),
      portals: [
        GisPortal(
          root:
              'https://services6.arcgis.com/0LYnC2LP950VYCyM/arcgis/rest/services',
          publisher: 'City of Gardena',
          tier: PortalTier.city,
          serviceCount: 7,
        ),
      ],
    ),
    CityPortals(
      name: 'Glendora',
      bounds: GeoBounds(
        west: -117.8901,
        south: 34.1068,
        east: -117.7939,
        north: 34.1797,
      ),
      portals: [
        GisPortal(
          root: 'https://gis.cityofglendora.org/arcgis/rest/services',
          publisher: 'City of Glendora',
          tier: PortalTier.city,
          serviceCount: 131,
        ),
        GisPortal(
          root:
              'https://services2.arcgis.com/NQC8oBejgXkIxQpu/arcgis/rest/services',
          publisher: 'City of Glendora',
          tier: PortalTier.city,
          serviceCount: 75,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/NQC8oBejgXkIxQpu/arcgis/rest/services',
          publisher: 'City of Glendora',
          tier: PortalTier.city,
          serviceCount: 2,
        ),
      ],
    ),
    CityPortals(
      name: 'Industry',
      bounds: GeoBounds(
        west: -118.0557,
        south: 33.9895,
        east: -117.8202,
        north: 34.064,
      ),
      portals: [
        GisPortal(
          root:
              'https://services6.arcgis.com/xHZOIuVPW78WpOFQ/arcgis/rest/services',
          publisher: 'City of Industry',
          tier: PortalTier.city,
          serviceCount: 26,
        ),
        GisPortal(
          root: 'https://gis.cityofindustry.org/server/rest/services',
          publisher: 'City of Industry',
          tier: PortalTier.city,
          serviceCount: 25,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/xHZOIuVPW78WpOFQ/arcgis/rest/services',
          publisher: 'City of Industry',
          tier: PortalTier.city,
          serviceCount: 5,
        ),
        GisPortal(
          root:
              'https://laserfiche.cityofindustry.org/ArcLfFeatureService/1/rest/services',
          publisher: 'City of Industry',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
    CityPortals(
      name: 'Irwindale',
      bounds: GeoBounds(
        west: -118.0082,
        south: 34.0769,
        east: -117.9254,
        north: 34.1412,
      ),
      portals: [
        GisPortal(
          root:
              'https://services9.arcgis.com/mJeEubBYq2hk7c9K/arcgis/rest/services',
          publisher: 'City of Irwindale',
          tier: PortalTier.city,
          serviceCount: 6,
        ),
      ],
    ),
    CityPortals(
      name: 'Long Beach',
      bounds: GeoBounds(
        west: -118.2413,
        south: 33.7329,
        east: -118.0633,
        north: 33.8856,
      ),
      portals: [
        GisPortal(
          root:
              'https://services6.arcgis.com/yCArG7wGXGyWLqav/arcgis/rest/services',
          publisher: 'City of Long Beach',
          tier: PortalTier.city,
          serviceCount: 170,
        ),
      ],
    ),
    CityPortals(
      name: 'Los Angeles',
      bounds: GeoBounds(
        west: -118.6682,
        south: 33.7046,
        east: -118.1554,
        north: 34.3373,
      ),
      portals: [
        GisPortal(
          root:
              'https://services7.arcgis.com/DSSF7DFVxfZsz379/arcgis/rest/services',
          publisher: 'City of Los Angeles',
          tier: PortalTier.city,
          serviceCount: 42,
        ),
        GisPortal(
          root: 'https://maps.lacity.org/lahub/rest/services',
          publisher: 'City of Los Angeles',
          tier: PortalTier.city,
          serviceCount: 40,
        ),
      ],
    ),
    CityPortals(
      name: 'Lynwood',
      bounds: GeoBounds(
        west: -118.2295,
        south: 33.9067,
        east: -118.1768,
        north: 33.9451,
      ),
      portals: [
        GisPortal(
          root:
              'https://services8.arcgis.com/TLogqQbe6TnrHFMm/arcgis/rest/services',
          publisher: 'City of Lynwood',
          tier: PortalTier.city,
          serviceCount: 5,
        ),
      ],
    ),
    CityPortals(
      name: 'Malibu',
      bounds: GeoBounds(
        west: -118.9237,
        south: 34.0002,
        east: -118.5845,
        north: 34.0672,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/w2LtkSgyOOlg6OKZ/arcgis/rest/services',
          publisher: 'City of Malibu',
          tier: PortalTier.city,
          serviceCount: 22,
        ),
      ],
    ),
    CityPortals(
      name: 'Monterey Park',
      bounds: GeoBounds(
        west: -118.1696,
        south: 34.027,
        east: -118.0931,
        north: 34.0715,
      ),
      portals: [
        GisPortal(
          root:
              'https://services9.arcgis.com/ivAMP6vRMPA12GAA/arcgis/rest/services',
          publisher: 'City of Monterey Park',
          tier: PortalTier.city,
          serviceCount: 540,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/ivAMP6vRMPA12GAA/arcgis/rest/services',
          publisher: 'City of Monterey Park',
          tier: PortalTier.city,
          serviceCount: 10,
        ),
      ],
    ),
    CityPortals(
      name: 'Redondo Beach',
      bounds: GeoBounds(
        west: -118.4018,
        south: 33.8152,
        east: -118.3525,
        north: 33.8946,
      ),
      portals: [
        GisPortal(
          root:
              'https://services6.arcgis.com/4Y3DUWGj4Rq1ajvv/arcgis/rest/services',
          publisher: 'City of Redondo Beach',
          tier: PortalTier.city,
          serviceCount: 43,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/4Y3DUWGj4Rq1ajvv/arcgis/rest/services',
          publisher: 'City of Redondo Beach',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
    CityPortals(
      name: 'Rosemead',
      bounds: GeoBounds(
        west: -118.1081,
        south: 34.0344,
        east: -118.0558,
        north: 34.095,
      ),
      portals: [
        GisPortal(
          root:
              'https://services5.arcgis.com/0fqb8Dy41NtYm1ZO/arcgis/rest/services',
          publisher: 'City of Rosemead',
          tier: PortalTier.city,
          serviceCount: 6,
        ),
      ],
    ),
    CityPortals(
      name: 'Santa Clarita',
      bounds: GeoBounds(
        west: -118.6134,
        south: 34.3415,
        east: -118.3787,
        north: 34.5001,
      ),
      portals: [
        GisPortal(
          root: 'https://maps.santa-clarita.com/arcgis/rest/services',
          publisher: 'City of Santa Clarita',
          tier: PortalTier.city,
          serviceCount: 44,
        ),
        GisPortal(
          root:
              'https://services6.arcgis.com/VIT2lop0SYQZYGmw/arcgis/rest/services',
          publisher: 'City of Santa Clarita',
          tier: PortalTier.city,
          serviceCount: 19,
        ),
      ],
    ),
    CityPortals(
      name: 'Santa Monica',
      bounds: GeoBounds(
        west: -118.5176,
        south: 33.9952,
        east: -118.4435,
        north: 34.0506,
      ),
      portals: [
        GisPortal(
          root: 'https://gis.santamonica.gov/server/rest/services',
          publisher: 'City of Santa Monica',
          tier: PortalTier.city,
          serviceCount: 181,
        ),
        GisPortal(
          root:
              'https://services1.arcgis.com/ntb1ZybmOdA9GyKm/arcgis/rest/services',
          publisher: 'City of Santa Monica',
          tier: PortalTier.city,
          serviceCount: 147,
        ),
      ],
    ),
    CityPortals(
      name: 'Whittier',
      bounds: GeoBounds(
        west: -118.0723,
        south: 33.928,
        east: -117.7831,
        north: 34.0312,
      ),
      portals: [
        GisPortal(
          root:
              'https://services6.arcgis.com/ep2P4aOWGVVBct0i/arcgis/rest/services',
          publisher: 'City of Whittier',
          tier: PortalTier.city,
          serviceCount: 88,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/ep2P4aOWGVVBct0i/arcgis/rest/services',
          publisher: 'City of Whittier',
          tier: PortalTier.city,
          serviceCount: 2,
        ),
      ],
    ),
  ],
  'ca_marin': [
    CityPortals(
      name: 'Larkspur',
      bounds: GeoBounds(
        west: -122.5528,
        south: 37.9217,
        east: -122.5018,
        north: 37.9588,
      ),
      portals: [
        GisPortal(
          root:
              'https://services1.arcgis.com/6jeSD03lmoyjRavK/arcgis/rest/services',
          publisher: 'City of Larkspur',
          tier: PortalTier.city,
          serviceCount: 6,
        ),
      ],
    ),
    CityPortals(
      name: 'San Rafael',
      bounds: GeoBounds(
        west: -122.5897,
        south: 37.9427,
        east: -122.4526,
        north: 38.0258,
      ),
      portals: [
        GisPortal(
          root:
              'https://services5.arcgis.com/sruoiBDPu8SihcGN/arcgis/rest/services',
          publisher: 'City of San Rafael',
          tier: PortalTier.city,
          serviceCount: 129,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/sruoiBDPu8SihcGN/arcgis/rest/services',
          publisher: 'City of San Rafael',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
  ],
  'ca_monterey': [
    CityPortals(
      name: 'King City',
      bounds: GeoBounds(
        west: -121.1629,
        south: 36.192,
        east: -121.1085,
        north: 36.2353,
      ),
      portals: [
        GisPortal(
          root:
              'https://services8.arcgis.com/NsUn9YuPFCjrkDe3/arcgis/rest/services',
          publisher: 'City of King City',
          tier: PortalTier.city,
          serviceCount: 36,
        ),
      ],
    ),
    CityPortals(
      name: 'Salinas',
      bounds: GeoBounds(
        west: -121.6866,
        south: 36.639,
        east: -121.574,
        north: 36.7343,
      ),
      portals: [
        GisPortal(
          root: 'https://salinas-gis.ci.salinas.ca.us/hosting/rest/services',
          publisher: 'City of Salinas',
          tier: PortalTier.city,
          serviceCount: 229,
        ),
        GisPortal(
          root:
              'https://services2.arcgis.com/uoH0krU6mYNGfwti/arcgis/rest/services',
          publisher: 'City of Salinas',
          tier: PortalTier.city,
          serviceCount: 90,
        ),
        GisPortal(
          root: 'https://salinas-gis.ci.salinas.ca.us/arcgis/rest/services',
          publisher: 'City of Salinas',
          tier: PortalTier.city,
          serviceCount: 21,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/uoH0krU6mYNGfwti/arcgis/rest/services',
          publisher: 'City of Salinas',
          tier: PortalTier.city,
          serviceCount: 2,
        ),
      ],
    ),
  ],
  'ca_nevada': [
    CityPortals(
      name: 'Truckee',
      bounds: GeoBounds(
        west: -120.3006,
        south: 39.3163,
        east: -120.0767,
        north: 39.3858,
      ),
      portals: [
        GisPortal(
          root:
              'https://services5.arcgis.com/i75zh9vlhYUpqwjr/arcgis/rest/services',
          publisher: 'Town of Truckee',
          tier: PortalTier.city,
          serviceCount: 194,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/i75zh9vlhYUpqwjr/arcgis/rest/services',
          publisher: 'Town of Truckee',
          tier: PortalTier.city,
          serviceCount: 2,
        ),
      ],
    ),
  ],
  'ca_orange': [
    CityPortals(
      name: 'Anaheim',
      bounds: GeoBounds(
        west: -118.0173,
        south: 33.7888,
        east: -117.6745,
        north: 33.8792,
      ),
      portals: [
        GisPortal(
          root: 'https://gis.anaheim.net/server/rest/services',
          publisher: 'City of Anaheim',
          tier: PortalTier.city,
          serviceCount: 267,
        ),
        GisPortal(
          root:
              'https://services3.arcgis.com/hPs600I3X0RTaaaq/arcgis/rest/services',
          publisher: 'City of Anaheim',
          tier: PortalTier.city,
          serviceCount: 122,
        ),
        GisPortal(
          root: 'https://gis.anaheim.net/map/rest/services',
          publisher: 'City of Anaheim',
          tier: PortalTier.city,
          serviceCount: 54,
        ),
      ],
    ),
    CityPortals(
      name: 'Buena Park',
      bounds: GeoBounds(
        west: -118.0374,
        south: 33.8098,
        east: -117.9764,
        north: 33.8956,
      ),
      portals: [
        GisPortal(
          root:
              'https://services8.arcgis.com/eVbtY4q6KGlXIxQE/arcgis/rest/services',
          publisher: 'City of Buena Park',
          tier: PortalTier.city,
          serviceCount: 44,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/eVbtY4q6KGlXIxQE/arcgis/rest/services',
          publisher: 'City of Buena Park',
          tier: PortalTier.city,
          serviceCount: 2,
        ),
      ],
    ),
    CityPortals(
      name: 'Huntington Beach',
      bounds: GeoBounds(
        west: -118.0826,
        south: 33.6294,
        east: -117.9405,
        north: 33.7562,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/KaS5yngHhCOBHXdC/arcgis/rest/services',
          publisher: 'City of Huntington Beach',
          tier: PortalTier.city,
          serviceCount: 114,
        ),
        GisPortal(
          root: 'https://gis.huntingtonbeachca.gov/arcgis/rest/services',
          publisher: 'City of Huntington Beach',
          tier: PortalTier.city,
          serviceCount: 42,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/KaS5yngHhCOBHXdC/arcgis/rest/services',
          publisher: 'City of Huntington Beach',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
    CityPortals(
      name: 'Irvine',
      bounds: GeoBounds(
        west: -117.8688,
        south: 33.5996,
        east: -117.678,
        north: 33.7737,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/3mkVbLdbLBFHrfbK/arcgis/rest/services',
          publisher: 'City of Irvine',
          tier: PortalTier.city,
          serviceCount: 219,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/3mkVbLdbLBFHrfbK/arcgis/rest/services',
          publisher: 'City of Irvine',
          tier: PortalTier.city,
          serviceCount: 13,
        ),
      ],
    ),
    CityPortals(
      name: 'Laguna Woods',
      bounds: GeoBounds(
        west: -117.757,
        south: 33.5957,
        east: -117.7014,
        north: 33.6253,
      ),
      portals: [
        GisPortal(
          root:
              'https://services9.arcgis.com/uOpV6qB9BT1Uy4OZ/arcgis/rest/services',
          publisher: 'City of Laguna Woods',
          tier: PortalTier.city,
          serviceCount: 86,
        ),
      ],
    ),
    CityPortals(
      name: 'Placentia',
      bounds: GeoBounds(
        west: -117.885,
        south: 33.8536,
        east: -117.8163,
        north: 33.9102,
      ),
      portals: [
        GisPortal(
          root:
              'https://services1.arcgis.com/3CyDafKD7aN8Dr8M/arcgis/rest/services',
          publisher: 'City of Placentia',
          tier: PortalTier.city,
          serviceCount: 122,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/3CyDafKD7aN8Dr8M/arcgis/rest/services',
          publisher: 'City of Placentia',
          tier: PortalTier.city,
          serviceCount: 8,
        ),
      ],
    ),
    CityPortals(
      name: 'San Clemente',
      bounds: GeoBounds(
        west: -117.6653,
        south: 33.3871,
        east: -117.5712,
        north: 33.4908,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/x68DaqVkReQwi0Vd/arcgis/rest/services',
          publisher: 'City of San Clemente',
          tier: PortalTier.city,
          serviceCount: 145,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/x68DaqVkReQwi0Vd/arcgis/rest/services',
          publisher: 'City of San Clemente',
          tier: PortalTier.city,
          serviceCount: 24,
        ),
      ],
    ),
    CityPortals(
      name: 'Santa Ana',
      bounds: GeoBounds(
        west: -117.9417,
        south: 33.6916,
        east: -117.8314,
        north: 33.784,
      ),
      portals: [
        GisPortal(
          root:
              'https://services1.arcgis.com/u3G8zpmDyNtG4F4e/arcgis/rest/services',
          publisher: 'City of Santa Ana',
          tier: PortalTier.city,
          serviceCount: 168,
        ),
        GisPortal(
          root: 'https://gis.santa-ana.org/server/rest/services',
          publisher: 'City of Santa Ana',
          tier: PortalTier.city,
          serviceCount: 103,
        ),
      ],
    ),
    CityPortals(
      name: 'Tustin',
      bounds: GeoBounds(
        west: -117.8435,
        south: 33.6942,
        east: -117.7599,
        north: 33.778,
      ),
      portals: [
        GisPortal(
          root:
              'https://services8.arcgis.com/omhBSxytABi3T0US/arcgis/rest/services',
          publisher: 'City of Tustin',
          tier: PortalTier.city,
          serviceCount: 35,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/omhBSxytABi3T0US/arcgis/rest/services',
          publisher: 'City of Tustin',
          tier: PortalTier.city,
          serviceCount: 10,
        ),
      ],
    ),
    CityPortals(
      name: 'Yorba Linda',
      bounds: GeoBounds(
        west: -117.8458,
        south: 33.8635,
        east: -117.6836,
        north: 33.9183,
      ),
      portals: [
        GisPortal(
          root: 'https://maps.scag.ca.gov/scaggis/rest/services',
          publisher: 'City of Yorba Linda',
          tier: PortalTier.city,
          serviceCount: 170,
        ),
        GisPortal(
          root: 'https://webgis.yorbalindaca.gov/arcgis/rest/services',
          publisher: 'City of Yorba Linda',
          tier: PortalTier.city,
          serviceCount: 103,
        ),
        GisPortal(
          root:
              'https://services9.arcgis.com/2inIk9VHQaVn3Vkf/arcgis/rest/services',
          publisher: 'City of Yorba Linda',
          tier: PortalTier.city,
          serviceCount: 86,
        ),
      ],
    ),
  ],
  'ca_placer': [
    CityPortals(
      name: 'Auburn',
      bounds: GeoBounds(
        west: -121.1126,
        south: 38.8585,
        east: -121.0527,
        north: 38.9569,
      ),
      portals: [
        GisPortal(
          root:
              'https://services5.arcgis.com/30qw1TW4OnLBnbjf/arcgis/rest/services',
          publisher: 'City of Auburn',
          tier: PortalTier.city,
          serviceCount: 5,
        ),
      ],
    ),
  ],
  'ca_riverside': [
    CityPortals(
      name: 'Cathedral City',
      bounds: GeoBounds(
        west: -116.5044,
        south: 33.7561,
        east: -116.4053,
        north: 33.8913,
      ),
      portals: [
        GisPortal(
          root: 'https://gissrv.cathedralcity.gov/arcgis/rest/services',
          publisher: 'City of Cathedral City',
          tier: PortalTier.city,
          serviceCount: 83,
        ),
        GisPortal(
          root:
              'https://services8.arcgis.com/kG6WbW2TR4SvOdBc/arcgis/rest/services',
          publisher: 'City of Cathedral City',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
    CityPortals(
      name: 'Corona',
      bounds: GeoBounds(
        west: -117.673,
        south: 33.8001,
        east: -117.4846,
        north: 33.9162,
      ),
      portals: [
        GisPortal(
          root: 'https://gis.coronaca.gov/server/rest/services',
          publisher: 'City of Corona',
          tier: PortalTier.city,
          serviceCount: 156,
        ),
        GisPortal(
          root:
              'https://services3.arcgis.com/4pohxs3ZXJsQTQod/arcgis/rest/services',
          publisher: 'City of Corona',
          tier: PortalTier.city,
          serviceCount: 119,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/4pohxs3ZXJsQTQod/arcgis/rest/services',
          publisher: 'City of Corona',
          tier: PortalTier.city,
          serviceCount: 6,
        ),
      ],
    ),
    CityPortals(
      name: 'Hemet',
      bounds: GeoBounds(
        west: -117.0698,
        south: 33.6711,
        east: -116.9089,
        north: 33.7802,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/czrgcV6qkPuBJCRH/arcgis/rest/services',
          publisher: 'City of Hemet',
          tier: PortalTier.city,
          serviceCount: 134,
        ),
      ],
    ),
    CityPortals(
      name: 'Indian Wells',
      bounds: GeoBounds(
        west: -116.3737,
        south: 33.6707,
        east: -116.2949,
        north: 33.7436,
      ),
      portals: [
        GisPortal(
          root:
              'https://services5.arcgis.com/wofcwmgSgOCK8921/arcgis/rest/services',
          publisher: 'City of Indian Wells',
          tier: PortalTier.city,
          serviceCount: 20,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/wofcwmgSgOCK8921/arcgis/rest/services',
          publisher: 'City of Indian Wells',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
    CityPortals(
      name: 'Indio',
      bounds: GeoBounds(
        west: -116.3013,
        south: 33.671,
        east: -116.1641,
        north: 33.8165,
      ),
      portals: [
        GisPortal(
          root:
              'https://services8.arcgis.com/BfuQpcCSh96eO2ZV/arcgis/rest/services',
          publisher: 'City of Indio',
          tier: PortalTier.city,
          serviceCount: 9,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/BfuQpcCSh96eO2ZV/arcgis/rest/services',
          publisher: 'City of Indio',
          tier: PortalTier.city,
          serviceCount: 5,
        ),
      ],
    ),
    CityPortals(
      name: 'La Quinta',
      bounds: GeoBounds(
        west: -116.3215,
        south: 33.5837,
        east: -116.2247,
        north: 33.7383,
      ),
      portals: [
        GisPortal(
          root: 'https://gis.la-quinta.org/arcgis/rest/services',
          publisher: 'City of La Quinta',
          tier: PortalTier.city,
          serviceCount: 78,
        ),
        GisPortal(
          root:
              'https://services2.arcgis.com/5jNzAeKAtrcgr5Es/arcgis/rest/services',
          publisher: 'City of La Quinta',
          tier: PortalTier.city,
          serviceCount: 19,
        ),
      ],
    ),
    CityPortals(
      name: 'Menifee',
      bounds: GeoBounds(
        west: -117.2582,
        south: 33.6269,
        east: -117.1189,
        north: 33.7577,
      ),
      portals: [
        GisPortal(
          root:
              'https://services.arcgis.com/RjTKod25O4b8SbZx/arcgis/rest/services',
          publisher: 'City of Menifee',
          tier: PortalTier.city,
          serviceCount: 124,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/RjTKod25O4b8SbZx/arcgis/rest/services',
          publisher: 'City of Menifee',
          tier: PortalTier.city,
          serviceCount: 5,
        ),
      ],
    ),
    CityPortals(
      name: 'Moreno Valley',
      bounds: GeoBounds(
        west: -117.2965,
        south: 33.859,
        east: -117.0885,
        north: 33.9881,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/WgPlP3PNKC8Glejs/arcgis/rest/services',
          publisher: 'City of Moreno Valley',
          tier: PortalTier.city,
          serviceCount: 91,
        ),
        GisPortal(
          root: 'https://mvrdalrt.moval.gov/arcgis/rest/services',
          publisher: 'City of Moreno Valley',
          tier: PortalTier.city,
          serviceCount: 75,
        ),
      ],
    ),
    CityPortals(
      name: 'Palm Desert',
      bounds: GeoBounds(
        west: -116.4255,
        south: 33.6707,
        east: -116.3021,
        north: 33.8101,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/i4mrGZu1Isvl0rWt/arcgis/rest/services',
          publisher: 'City of Palm Desert',
          tier: PortalTier.city,
          serviceCount: 226,
        ),
      ],
    ),
    CityPortals(
      name: 'Palm Springs',
      bounds: GeoBounds(
        west: -116.6845,
        south: 33.6124,
        east: -116.4428,
        north: 33.932,
      ),
      portals: [
        GisPortal(
          root:
              'https://services.arcgis.com/f48yV21HSEYeCYMI/arcgis/rest/services',
          publisher: 'City of Palm Springs',
          tier: PortalTier.city,
          serviceCount: 46,
        ),
      ],
    ),
    CityPortals(
      name: 'Perris',
      bounds: GeoBounds(
        west: -117.2626,
        south: 33.7139,
        east: -117.1787,
        north: 33.8699,
      ),
      portals: [
        GisPortal(
          root:
              'https://services7.arcgis.com/LNp9QekVQ7pNnS4Q/arcgis/rest/services',
          publisher: 'City of Perris',
          tier: PortalTier.city,
          serviceCount: 53,
        ),
        GisPortal(
          root: 'https://gis.conserveriverside.com/arcgis/rest/services',
          publisher: 'City of Perris',
          tier: PortalTier.city,
          serviceCount: 36,
        ),
      ],
    ),
    CityPortals(
      name: 'Riverside',
      bounds: GeoBounds(
        west: -117.5237,
        south: 33.8726,
        east: -117.2788,
        north: 34.0194,
      ),
      portals: [
        GisPortal(
          root:
              'https://services.arcgis.com/Fu2oOWg1Aw7azh41/arcgis/rest/services',
          publisher: 'City of Riverside',
          tier: PortalTier.city,
          serviceCount: 745,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/Fu2oOWg1Aw7azh41/arcgis/rest/services',
          publisher: 'City of Riverside',
          tier: PortalTier.city,
          serviceCount: 22,
        ),
      ],
    ),
    CityPortals(
      name: 'San Jacinto',
      bounds: GeoBounds(
        west: -117.0599,
        south: 33.7513,
        east: -116.9185,
        north: 33.8369,
      ),
      portals: [
        GisPortal(
          root: 'https://gis01.city.sanjacintoca.gov/server/rest/services',
          publisher: 'City of San Jacinto',
          tier: PortalTier.city,
          serviceCount: 126,
        ),
        GisPortal(
          root:
              'https://services6.arcgis.com/GWV58jOyFyDtOPG2/arcgis/rest/services',
          publisher: 'City of San Jacinto',
          tier: PortalTier.city,
          serviceCount: 21,
        ),
      ],
    ),
    CityPortals(
      name: 'Temecula',
      bounds: GeoBounds(
        west: -117.2065,
        south: 33.4322,
        east: -117.0548,
        north: 33.5544,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/IgR6ay8jzuIj7VSF/arcgis/rest/services',
          publisher: 'City of Temecula',
          tier: PortalTier.city,
          serviceCount: 122,
        ),
        GisPortal(
          root: 'https://gis.temeculaca.gov/arcgis/rest/services',
          publisher: 'City of Temecula',
          tier: PortalTier.city,
          serviceCount: 99,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/IgR6ay8jzuIj7VSF/arcgis/rest/services',
          publisher: 'City of Temecula',
          tier: PortalTier.city,
          serviceCount: 24,
        ),
      ],
    ),
    CityPortals(
      name: 'Wildomar',
      bounds: GeoBounds(
        west: -117.3107,
        south: 33.5763,
        east: -117.2062,
        north: 33.656,
      ),
      portals: [
        GisPortal(
          root:
              'https://services6.arcgis.com/kIJQVjhDSsSdR0Xt/arcgis/rest/services',
          publisher: 'City of Wildomar',
          tier: PortalTier.city,
          serviceCount: 98,
        ),
      ],
    ),
  ],
  'ca_sacramento': [
    CityPortals(
      name: 'Citrus Heights',
      bounds: GeoBounds(
        west: -121.3319,
        south: 38.6636,
        east: -121.2429,
        north: 38.7228,
      ),
      portals: [
        GisPortal(
          root:
              'https://services8.arcgis.com/F2vUxnlx169smga0/arcgis/rest/services',
          publisher: 'City of Citrus Heights',
          tier: PortalTier.city,
          serviceCount: 45,
        ),
      ],
    ),
    CityPortals(
      name: 'Elk Grove',
      bounds: GeoBounds(
        west: -121.4877,
        south: 38.3614,
        east: -121.2694,
        north: 38.4526,
      ),
      portals: [
        GisPortal(
          root:
              'https://services1.arcgis.com/r6QlyAADl0kfhp1m/arcgis/rest/services',
          publisher: 'City of Elk Grove',
          tier: PortalTier.city,
          serviceCount: 163,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/r6QlyAADl0kfhp1m/arcgis/rest/services',
          publisher: 'City of Elk Grove',
          tier: PortalTier.city,
          serviceCount: 6,
        ),
        GisPortal(
          root: 'https://webmaps.elkgrovecity.org/arcgis/rest/services',
          publisher: 'City of Elk Grove',
          tier: PortalTier.city,
          serviceCount: 4,
        ),
      ],
    ),
    CityPortals(
      name: 'Folsom',
      bounds: GeoBounds(
        west: -121.211,
        south: 38.6103,
        east: -121.082,
        north: 38.7174,
      ),
      portals: [
        GisPortal(
          root: 'https://gis.folsom.ca.us/arcgisserver/rest/services',
          publisher: 'City of Folsom',
          tier: PortalTier.city,
          serviceCount: 94,
        ),
        GisPortal(
          root:
              'https://services3.arcgis.com/dbR1kNGfhZN9zaNI/arcgis/rest/services',
          publisher: 'City of Folsom',
          tier: PortalTier.city,
          serviceCount: 19,
        ),
      ],
    ),
    CityPortals(
      name: 'Rancho Cordova',
      bounds: GeoBounds(
        west: -121.3365,
        south: 38.5019,
        east: -121.1863,
        north: 38.6339,
      ),
      portals: [
        GisPortal(
          root:
              'https://services1.arcgis.com/kSSEfQQl69HmZZw6/arcgis/rest/services',
          publisher: 'City of Rancho Cordova',
          tier: PortalTier.city,
          serviceCount: 129,
        ),
        GisPortal(
          root:
              'https://maps.cityofranchocordova.org/externalarcgis/rest/services',
          publisher: 'City of Rancho Cordova',
          tier: PortalTier.city,
          serviceCount: 33,
        ),
      ],
    ),
    CityPortals(
      name: 'Sacramento',
      bounds: GeoBounds(
        west: -121.5605,
        south: 38.438,
        east: -121.3628,
        north: 38.6857,
      ),
      portals: [
        GisPortal(
          root:
              'https://services5.arcgis.com/54falWtcpty3V47Z/arcgis/rest/services',
          publisher: 'City of Sacramento',
          tier: PortalTier.city,
          serviceCount: 356,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/54falWtcpty3V47Z/arcgis/rest/services',
          publisher: 'City of Sacramento',
          tier: PortalTier.city,
          serviceCount: 5,
        ),
      ],
    ),
  ],
  'ca_san_bernardino': [
    CityPortals(
      name: 'Apple Valley',
      bounds: GeoBounds(
        west: -117.2869,
        south: 34.428,
        east: -117.1508,
        north: 34.6467,
      ),
      portals: [
        GisPortal(
          root: 'https://gis.applevalleyca.gov/arcgis/rest/services',
          publisher: 'Town of Apple Valley',
          tier: PortalTier.city,
          serviceCount: 4,
        ),
        GisPortal(
          root:
              'https://services1.arcgis.com/FGe4g7ObpdDb0DvO/arcgis/rest/services',
          publisher: 'Town of Apple Valley',
          tier: PortalTier.city,
          serviceCount: 3,
        ),
      ],
    ),
    CityPortals(
      name: 'Big Bear Lake',
      bounds: GeoBounds(
        west: -116.9623,
        south: 34.2248,
        east: -116.7702,
        north: 34.2708,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/safmkHh6IfIYbpgO/arcgis/rest/services',
          publisher: 'City of Big Bear Lake',
          tier: PortalTier.city,
          serviceCount: 25,
        ),
      ],
    ),
    CityPortals(
      name: 'Colton',
      bounds: GeoBounds(
        west: -117.3728,
        south: 34.0182,
        east: -117.2701,
        north: 34.1045,
      ),
      portals: [
        GisPortal(
          root:
              'https://services.arcgis.com/rfpJM1nx4s5ONZ3C/arcgis/rest/services',
          publisher: 'City of Colton',
          tier: PortalTier.city,
          serviceCount: 41,
        ),
      ],
    ),
    CityPortals(
      name: 'Fontana',
      bounds: GeoBounds(
        west: -117.5243,
        south: 34.0335,
        east: -117.4015,
        north: 34.1817,
      ),
      portals: [
        GisPortal(
          root:
              'https://services1.arcgis.com/XhE4Nx2bBPScQrhF/arcgis/rest/services',
          publisher: 'City of Fontana',
          tier: PortalTier.city,
          serviceCount: 184,
        ),
        GisPortal(
          root: 'https://dsogis.fontana.org/server/rest/services',
          publisher: 'City of Fontana',
          tier: PortalTier.city,
          serviceCount: 43,
        ),
        GisPortal(
          root: 'https://dmz-gis-2.fontana.org:6443/arcgis/rest/services',
          publisher: 'City of Fontana',
          tier: PortalTier.city,
          serviceCount: 24,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/XhE4Nx2bBPScQrhF/arcgis/rest/services',
          publisher: 'City of Fontana',
          tier: PortalTier.city,
          serviceCount: 5,
        ),
      ],
    ),
    CityPortals(
      name: 'Ontario',
      bounds: GeoBounds(
        west: -117.6818,
        south: 33.9753,
        east: -117.524,
        north: 34.0923,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/hw9dvDTLn0ngkGb1/arcgis/rest/services',
          publisher: 'City of Ontario',
          tier: PortalTier.city,
          serviceCount: 287,
        ),
        GisPortal(
          root: 'https://gisportal.ontarioca.gov/server/rest/services',
          publisher: 'City of Ontario',
          tier: PortalTier.city,
          serviceCount: 31,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/hw9dvDTLn0ngkGb1/arcgis/rest/services',
          publisher: 'City of Ontario',
          tier: PortalTier.city,
          serviceCount: 4,
        ),
      ],
    ),
    CityPortals(
      name: 'Rancho Cucamonga',
      bounds: GeoBounds(
        west: -117.6362,
        south: 34.0772,
        east: -117.4791,
        north: 34.1796,
      ),
      portals: [
        GisPortal(
          root:
              'https://services1.arcgis.com/bF44QtfoYZDGo7TK/arcgis/rest/services',
          publisher: 'City of Rancho Cucamonga',
          tier: PortalTier.city,
          serviceCount: 356,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/bF44QtfoYZDGo7TK/arcgis/rest/services',
          publisher: 'City of Rancho Cucamonga',
          tier: PortalTier.city,
          serviceCount: 48,
        ),
      ],
    ),
    CityPortals(
      name: 'Upland',
      bounds: GeoBounds(
        west: -117.7045,
        south: 34.0869,
        east: -117.6197,
        north: 34.1506,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/Jab7quDXqm7uObfw/arcgis/rest/services',
          publisher: 'City of Upland',
          tier: PortalTier.city,
          serviceCount: 29,
        ),
      ],
    ),
    CityPortals(
      name: 'Victorville',
      bounds: GeoBounds(
        west: -117.4688,
        south: 34.4355,
        east: -117.2536,
        north: 34.6455,
      ),
      portals: [
        GisPortal(
          root: 'https://gis1.victorvilleca.gov/arcgis/rest/services',
          publisher: 'City of Victorville',
          tier: PortalTier.city,
          serviceCount: 95,
        ),
        GisPortal(
          root:
              'https://services3.arcgis.com/8Fll56KQwYKXAi7m/arcgis/rest/services',
          publisher: 'City of Victorville',
          tier: PortalTier.city,
          serviceCount: 44,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/8Fll56KQwYKXAi7m/arcgis/rest/services',
          publisher: 'City of Victorville',
          tier: PortalTier.city,
          serviceCount: 2,
        ),
      ],
    ),
    CityPortals(
      name: 'Yucaipa',
      bounds: GeoBounds(
        west: -117.1264,
        south: 34.0044,
        east: -116.9628,
        north: 34.0772,
      ),
      portals: [
        GisPortal(
          root:
              'https://services5.arcgis.com/86gdKBxZf7GIt2Or/arcgis/rest/services',
          publisher: 'City of Yucaipa',
          tier: PortalTier.city,
          serviceCount: 209,
        ),
      ],
    ),
  ],
  'ca_san_diego': [
    CityPortals(
      name: 'Carlsbad',
      bounds: GeoBounds(
        west: -117.3589,
        south: 33.0613,
        east: -117.2167,
        north: 33.1823,
      ),
      portals: [
        GisPortal(
          root:
              'https://services.arcgis.com/ay9ePoQ2UfAX3U38/arcgis/rest/services',
          publisher: 'City of Carlsbad',
          tier: PortalTier.city,
          serviceCount: 67,
        ),
        GisPortal(
          root: 'https://ccmaps.carlsbadca.gov/dmzpags/rest/services',
          publisher: 'City of Carlsbad',
          tier: PortalTier.city,
          serviceCount: 15,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/ay9ePoQ2UfAX3U38/arcgis/rest/services',
          publisher: 'City of Carlsbad',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
    CityPortals(
      name: 'Chula Vista',
      bounds: GeoBounds(
        west: -117.1242,
        south: 32.578,
        east: -116.9278,
        north: 32.6855,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/2nV1ORz8qFa0iiF2/arcgis/rest/services',
          publisher: 'City of Chula Vista',
          tier: PortalTier.city,
          serviceCount: 76,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/2nV1ORz8qFa0iiF2/arcgis/rest/services',
          publisher: 'City of Chula Vista',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
    CityPortals(
      name: 'El Cajon',
      bounds: GeoBounds(
        west: -117.0112,
        south: 32.768,
        east: -116.8957,
        north: 32.831,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/sNwJsChyrhgtFVFc/arcgis/rest/services',
          publisher: 'City of El Cajon',
          tier: PortalTier.city,
          serviceCount: 50,
        ),
        GisPortal(
          root: 'https://docs.cityofelcajon.us/arcgis/rest/services',
          publisher: 'City of El Cajon',
          tier: PortalTier.city,
          serviceCount: 38,
        ),
        GisPortal(
          root: 'https://aom-us.nearmap.com/arcgis/rest/services',
          publisher: 'City of El Cajon',
          tier: PortalTier.city,
          serviceCount: 4,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/sNwJsChyrhgtFVFc/arcgis/rest/services',
          publisher: 'City of El Cajon',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
    CityPortals(
      name: 'Escondido',
      bounds: GeoBounds(
        west: -117.1462,
        south: 33.0573,
        east: -116.994,
        north: 33.2116,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/eJcVbjTyyZIzZ5Ye/arcgis/rest/services',
          publisher: 'City of Escondido',
          tier: PortalTier.city,
          serviceCount: 141,
        ),
      ],
    ),
    CityPortals(
      name: 'La Mesa',
      bounds: GeoBounds(
        west: -117.0533,
        south: 32.7436,
        east: -116.9818,
        north: 32.7957,
      ),
      portals: [
        GisPortal(
          root: 'https://geo.sandag.org/server/rest/services',
          publisher: 'City of La Mesa',
          tier: PortalTier.city,
          serviceCount: 391,
        ),
        GisPortal(
          root: 'https://platinum.ci.la-mesa.ca.us/arcgis/rest/services',
          publisher: 'City of La Mesa',
          tier: PortalTier.city,
          serviceCount: 187,
        ),
        GisPortal(
          root:
              'https://services3.arcgis.com/iYP51zxNr6TITn6r/arcgis/rest/services',
          publisher: 'City of La Mesa',
          tier: PortalTier.city,
          serviceCount: 38,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/iYP51zxNr6TITn6r/arcgis/rest/services',
          publisher: 'City of La Mesa',
          tier: PortalTier.city,
          serviceCount: 16,
        ),
      ],
    ),
    CityPortals(
      name: 'Oceanside',
      bounds: GeoBounds(
        west: -117.3984,
        south: 33.1531,
        east: -117.1688,
        north: 33.3001,
      ),
      portals: [
        GisPortal(
          root: 'https://gis.oceansideca.org/gis/rest/services',
          publisher: 'City of Oceanside',
          tier: PortalTier.city,
          serviceCount: 122,
        ),
        GisPortal(
          root:
              'https://services5.arcgis.com/6UYc3MjsfrxiazMH/arcgis/rest/services',
          publisher: 'City of Oceanside',
          tier: PortalTier.city,
          serviceCount: 54,
        ),
      ],
    ),
    CityPortals(
      name: 'Poway',
      bounds: GeoBounds(
        west: -117.0843,
        south: 32.9277,
        east: -116.9404,
        north: 33.0663,
      ),
      portals: [
        GisPortal(
          root: 'https://powaygis.poway.org/powaygis/rest/services',
          publisher: 'City of Poway',
          tier: PortalTier.city,
          serviceCount: 44,
        ),
        GisPortal(
          root:
              'https://services5.arcgis.com/CjWCkQzgTTO1K3C3/arcgis/rest/services',
          publisher: 'City of Poway',
          tier: PortalTier.city,
          serviceCount: 11,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/CjWCkQzgTTO1K3C3/arcgis/rest/services',
          publisher: 'City of Poway',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
    CityPortals(
      name: 'San Marcos',
      bounds: GeoBounds(
        west: -117.2299,
        south: 33.0804,
        east: -117.1103,
        north: 33.1882,
      ),
      portals: [
        GisPortal(
          root:
              'https://services1.arcgis.com/e7Mp0AHrN8K5Kx6X/arcgis/rest/services',
          publisher: 'City of San Marcos',
          tier: PortalTier.city,
          serviceCount: 53,
        ),
      ],
    ),
    CityPortals(
      name: 'Santee',
      bounds: GeoBounds(
        west: -117.0384,
        south: 32.8156,
        east: -116.938,
        north: 32.9034,
      ),
      portals: [
        GisPortal(
          root:
              'https://services8.arcgis.com/J9lw6cHYdxcsRYgI/arcgis/rest/services',
          publisher: 'City of Santee',
          tier: PortalTier.city,
          serviceCount: 20,
        ),
      ],
    ),
    CityPortals(
      name: 'Vista',
      bounds: GeoBounds(
        west: -117.2883,
        south: 33.1322,
        east: -117.1923,
        north: 33.2385,
      ),
      portals: [
        GisPortal(
          root: 'https://gis.vista.gov/arcgis/rest/services',
          publisher: 'City of Vista',
          tier: PortalTier.city,
          serviceCount: 72,
        ),
        GisPortal(
          root:
              'https://services3.arcgis.com/z9GvP47f4vbAXFVB/arcgis/rest/services',
          publisher: 'City of Vista',
          tier: PortalTier.city,
          serviceCount: 16,
        ),
      ],
    ),
  ],
  'ca_san_joaquin': [
    CityPortals(
      name: 'Tracy',
      bounds: GeoBounds(
        west: -121.5485,
        south: 37.6632,
        east: -121.38,
        north: 37.7797,
      ),
      portals: [
        GisPortal(
          root: 'https://maps.cityoftracy.org/server/rest/services',
          publisher: 'City of Tracy',
          tier: PortalTier.city,
          serviceCount: 34,
        ),
        GisPortal(
          root:
              'https://services1.arcgis.com/jhomrVPNnIcrbVuz/arcgis/rest/services',
          publisher: 'City of Tracy',
          tier: PortalTier.city,
          serviceCount: 9,
        ),
      ],
    ),
  ],
  'ca_san_luis_obispo': [
    CityPortals(
      name: 'Atascadero',
      bounds: GeoBounds(
        west: -120.7447,
        south: 35.4376,
        east: -120.6177,
        north: 35.5329,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/N2rywTnpbBhelXvy/arcgis/rest/services',
          publisher: 'City of Atascadero',
          tier: PortalTier.city,
          serviceCount: 34,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/N2rywTnpbBhelXvy/arcgis/rest/services',
          publisher: 'City of Atascadero',
          tier: PortalTier.city,
          serviceCount: 3,
        ),
      ],
    ),
    CityPortals(
      name: 'Grover Beach',
      bounds: GeoBounds(
        west: -120.6383,
        south: 35.1056,
        east: -120.6044,
        north: 35.13,
      ),
      portals: [
        GisPortal(
          root:
              'https://services9.arcgis.com/K9HdoWN46MwTFn7q/arcgis/rest/services',
          publisher: 'City of Grover Beach',
          tier: PortalTier.city,
          serviceCount: 11,
        ),
      ],
    ),
  ],
  'ca_san_mateo': [
    CityPortals(
      name: 'Belmont',
      bounds: GeoBounds(
        west: -122.3289,
        south: 37.4971,
        east: -122.261,
        north: 37.534,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/yj9NEYUuOce5iBjA/arcgis/rest/services',
          publisher: 'City of Belmont',
          tier: PortalTier.city,
          serviceCount: 67,
        ),
        GisPortal(
          root: 'https://maps.belmont.gov/arcgis/rest/services',
          publisher: 'City of Belmont',
          tier: PortalTier.city,
          serviceCount: 29,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/yj9NEYUuOce5iBjA/arcgis/rest/services',
          publisher: 'City of Belmont',
          tier: PortalTier.city,
          serviceCount: 2,
        ),
      ],
    ),
    CityPortals(
      name: 'Foster City',
      bounds: GeoBounds(
        west: -122.2877,
        south: 37.5333,
        east: -122.2467,
        north: 37.5759,
      ),
      portals: [
        GisPortal(
          root: 'https://bart.fostercity.org/arcgis/rest/services',
          publisher: 'City of Foster City',
          tier: PortalTier.city,
          serviceCount: 56,
        ),
        GisPortal(
          root:
              'https://services7.arcgis.com/CYn8XGt0yVlPlS5X/arcgis/rest/services',
          publisher: 'City of Foster City',
          tier: PortalTier.city,
          serviceCount: 37,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/CYn8XGt0yVlPlS5X/arcgis/rest/services',
          publisher: 'City of Foster City',
          tier: PortalTier.city,
          serviceCount: 2,
        ),
      ],
    ),
    CityPortals(
      name: 'Menlo Park',
      bounds: GeoBounds(
        west: -122.2284,
        south: 37.4187,
        east: -122.121,
        north: 37.5081,
      ),
      portals: [
        GisPortal(
          root:
              'https://services7.arcgis.com/uRrQ0O3z2aaiIWYU/arcgis/rest/services',
          publisher: 'City of Menlo Park',
          tier: PortalTier.city,
          serviceCount: 163,
        ),
        GisPortal(
          root: 'https://gisweb.menlopark.gov/server/rest/services',
          publisher: 'City of Menlo Park',
          tier: PortalTier.city,
          serviceCount: 69,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/uRrQ0O3z2aaiIWYU/arcgis/rest/services',
          publisher: 'City of Menlo Park',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
    CityPortals(
      name: 'Millbrae',
      bounds: GeoBounds(
        west: -122.425,
        south: 37.5814,
        east: -122.3739,
        north: 37.6127,
      ),
      portals: [
        GisPortal(
          root: 'https://aims4.aimsteam.net/arcgis/rest/services',
          publisher: 'City of Millbrae',
          tier: PortalTier.city,
          serviceCount: 149,
        ),
        GisPortal(
          root: 'https://aims1.aimsteam.net/arcgis/rest/services',
          publisher: 'City of Millbrae',
          tier: PortalTier.city,
          serviceCount: 113,
        ),
        GisPortal(
          root:
              'https://services6.arcgis.com/paH4j1JG3JAZKLhE/arcgis/rest/services',
          publisher: 'City of Millbrae',
          tier: PortalTier.city,
          serviceCount: 3,
        ),
      ],
    ),
  ],
  'ca_santa_barbara': [
    CityPortals(
      name: 'Carpinteria',
      bounds: GeoBounds(
        west: -119.5427,
        south: 34.3843,
        east: -119.4799,
        north: 34.4114,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/ehLaGZNdQUxXpQo3/arcgis/rest/services',
          publisher: 'City of Carpinteria',
          tier: PortalTier.city,
          serviceCount: 8,
        ),
      ],
    ),
  ],
  'ca_santa_clara': [
    CityPortals(
      name: 'Campbell',
      bounds: GeoBounds(
        west: -121.992,
        south: 37.2544,
        east: -121.9181,
        north: 37.3069,
      ),
      portals: [
        GisPortal(
          root:
              'https://services7.arcgis.com/RDyUffIeciKdYmX2/arcgis/rest/services',
          publisher: 'City of Campbell',
          tier: PortalTier.city,
          serviceCount: 11,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/RDyUffIeciKdYmX2/arcgis/rest/services',
          publisher: 'City of Campbell',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
    CityPortals(
      name: 'Cupertino',
      bounds: GeoBounds(
        west: -122.0911,
        south: 37.2785,
        east: -121.9959,
        north: 37.3396,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/WsCmJmL1F5wsSOiu/arcgis/rest/services',
          publisher: 'City of Cupertino',
          tier: PortalTier.city,
          serviceCount: 215,
        ),
        GisPortal(
          root: 'https://gis.cupertino.org/cupgis/rest/services',
          publisher: 'City of Cupertino',
          tier: PortalTier.city,
          serviceCount: 84,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/WsCmJmL1F5wsSOiu/arcgis/rest/services',
          publisher: 'City of Cupertino',
          tier: PortalTier.city,
          serviceCount: 15,
        ),
      ],
    ),
    CityPortals(
      name: 'Los Gatos',
      bounds: GeoBounds(
        west: -121.997,
        south: 37.1993,
        east: -121.9055,
        north: 37.2641,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/JAU7IM34hqT9y9ew/arcgis/rest/services',
          publisher: 'Town of Los Gatos',
          tier: PortalTier.city,
          serviceCount: 133,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/JAU7IM34hqT9y9ew/arcgis/rest/services',
          publisher: 'Town of Los Gatos',
          tier: PortalTier.city,
          serviceCount: 20,
        ),
      ],
    ),
    CityPortals(
      name: 'Morgan Hill',
      bounds: GeoBounds(
        west: -121.6979,
        south: 37.0898,
        east: -121.5833,
        north: 37.1697,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/7nQNsNGiGXOeUAiQ/arcgis/rest/services',
          publisher: 'City of Morgan Hill',
          tier: PortalTier.city,
          serviceCount: 7,
        ),
      ],
    ),
    CityPortals(
      name: 'Mountain View',
      bounds: GeoBounds(
        west: -122.1176,
        south: 37.3542,
        east: -122.045,
        north: 37.4521,
      ),
      portals: [
        GisPortal(
          root: 'https://maps.mountainview.gov/arcgis/rest/services',
          publisher: 'City of Mountain View',
          tier: PortalTier.city,
          serviceCount: 90,
        ),
        GisPortal(
          root:
              'https://services1.arcgis.com/Ps0xUhK5N3PQT26Q/arcgis/rest/services',
          publisher: 'City of Mountain View',
          tier: PortalTier.city,
          serviceCount: 85,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/Ps0xUhK5N3PQT26Q/arcgis/rest/services',
          publisher: 'City of Mountain View',
          tier: PortalTier.city,
          serviceCount: 14,
        ),
      ],
    ),
    CityPortals(
      name: 'Palo Alto',
      bounds: GeoBounds(
        west: -122.2027,
        south: 37.2877,
        east: -122.0847,
        north: 37.4659,
      ),
      portals: [
        GisPortal(
          root:
              'https://services6.arcgis.com/evmyRZRrsopdeog7/arcgis/rest/services',
          publisher: 'City of Palo Alto',
          tier: PortalTier.city,
          serviceCount: 55,
        ),
      ],
    ),
    CityPortals(
      name: 'San Jose',
      bounds: GeoBounds(
        west: -122.046,
        south: 37.1232,
        east: -121.5859,
        north: 37.4652,
      ),
      portals: [
        GisPortal(
          root: 'https://geo.sanjoseca.gov/server/rest/services',
          publisher: 'City of San Jose',
          tier: PortalTier.city,
          serviceCount: 92,
        ),
        GisPortal(
          root:
              'https://services.arcgis.com/6kSayNlqm3HvsYZ8/arcgis/rest/services',
          publisher: 'City of San Jose',
          tier: PortalTier.city,
          serviceCount: 83,
        ),
      ],
    ),
  ],
  'ca_shasta': [
    CityPortals(
      name: 'Anderson',
      bounds: GeoBounds(
        west: -122.3263,
        south: 40.4187,
        east: -122.2566,
        north: 40.4729,
      ),
      portals: [
        GisPortal(
          root:
              'https://services8.arcgis.com/AkTaRfsS1hakaLIl/arcgis/rest/services',
          publisher: 'City of Anderson',
          tier: PortalTier.city,
          serviceCount: 59,
        ),
      ],
    ),
    CityPortals(
      name: 'Redding',
      bounds: GeoBounds(
        west: -122.4503,
        south: 40.4704,
        east: -122.2742,
        north: 40.6805,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/3cLBYFivUvlzVu0H/arcgis/rest/services',
          publisher: 'City of Redding',
          tier: PortalTier.city,
          serviceCount: 216,
        ),
      ],
    ),
    CityPortals(
      name: 'Shasta Lake',
      bounds: GeoBounds(
        west: -122.4114,
        south: 40.651,
        east: -122.3375,
        north: 40.7097,
      ),
      portals: [
        GisPortal(
          root:
              'https://services9.arcgis.com/jlS3bBZGj44UAM9Z/arcgis/rest/services',
          publisher: 'City of Shasta Lake',
          tier: PortalTier.city,
          serviceCount: 188,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/jlS3bBZGj44UAM9Z/arcgis/rest/services',
          publisher: 'City of Shasta Lake',
          tier: PortalTier.city,
          serviceCount: 39,
        ),
      ],
    ),
  ],
  'ca_siskiyou': [
    CityPortals(
      name: 'Yreka',
      bounds: GeoBounds(
        west: -122.6706,
        south: 41.6843,
        east: -122.5875,
        north: 41.7683,
      ),
      portals: [
        GisPortal(
          root:
              'https://services5.arcgis.com/oe3k134aAvdSB7Iw/arcgis/rest/services',
          publisher: 'City of Yreka',
          tier: PortalTier.city,
          serviceCount: 67,
        ),
      ],
    ),
  ],
  'ca_solano': [
    CityPortals(
      name: 'Fairfield',
      bounds: GeoBounds(
        west: -122.1701,
        south: 38.1608,
        east: -121.8922,
        north: 38.3134,
      ),
      portals: [
        GisPortal(
          root:
              'https://services1.arcgis.com/A14KNJpxNyBTu19J/arcgis/rest/services',
          publisher: 'City of Fairfield',
          tier: PortalTier.city,
          serviceCount: 155,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/A14KNJpxNyBTu19J/arcgis/rest/services',
          publisher: 'City of Fairfield',
          tier: PortalTier.city,
          serviceCount: 15,
        ),
      ],
    ),
  ],
  'ca_sonoma': [
    CityPortals(
      name: 'Healdsburg',
      bounds: GeoBounds(
        west: -122.9026,
        south: 38.5815,
        east: -122.8436,
        north: 38.6569,
      ),
      portals: [
        GisPortal(
          root:
              'https://services1.arcgis.com/lqkn2SfJx7ADliPD/arcgis/rest/services',
          publisher: 'City of Healdsburg',
          tier: PortalTier.city,
          serviceCount: 8,
        ),
      ],
    ),
    CityPortals(
      name: 'Santa Rosa',
      bounds: GeoBounds(
        west: -122.8344,
        south: 38.3643,
        east: -122.57,
        north: 38.5081,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/BhTdzxiJkq4oXsPh/arcgis/rest/services',
          publisher: 'City of Santa Rosa',
          tier: PortalTier.city,
          serviceCount: 231,
        ),
        GisPortal(
          root: 'https://ags2maps.srcity.org/arcgis/rest/services',
          publisher: 'City of Santa Rosa',
          tier: PortalTier.city,
          serviceCount: 119,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/BhTdzxiJkq4oXsPh/arcgis/rest/services',
          publisher: 'City of Santa Rosa',
          tier: PortalTier.city,
          serviceCount: 2,
        ),
      ],
    ),
  ],
  'ca_stanislaus': [
    CityPortals(
      name: 'Newman',
      bounds: GeoBounds(
        west: -121.0379,
        south: 37.3037,
        east: -120.9794,
        north: 37.3377,
      ),
      portals: [
        GisPortal(
          root:
              'https://services9.arcgis.com/fpX5sizuLQXdvxX9/arcgis/rest/services',
          publisher: 'City of Newman',
          tier: PortalTier.city,
          serviceCount: 10,
        ),
      ],
    ),
  ],
  'ca_tulare': [
    CityPortals(
      name: 'Dinuba',
      bounds: GeoBounds(
        west: -119.4396,
        south: 36.5311,
        east: -119.3676,
        north: 36.5714,
      ),
      portals: [
        GisPortal(
          root:
              'https://services6.arcgis.com/AEktkJZn4D4r3skv/arcgis/rest/services',
          publisher: 'City of Dinuba',
          tier: PortalTier.city,
          serviceCount: 66,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/AEktkJZn4D4r3skv/arcgis/rest/services',
          publisher: 'City of Dinuba',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
    CityPortals(
      name: 'Exeter',
      bounds: GeoBounds(
        west: -119.1676,
        south: 36.2686,
        east: -119.1279,
        north: 36.307,
      ),
      portals: [
        GisPortal(
          root:
              'https://services6.arcgis.com/ap97xZhtUwvI1l2K/arcgis/rest/services',
          publisher: 'City of Exeter',
          tier: PortalTier.city,
          serviceCount: 11,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/ap97xZhtUwvI1l2K/arcgis/rest/services',
          publisher: 'City of Exeter',
          tier: PortalTier.city,
          serviceCount: 1,
        ),
      ],
    ),
    CityPortals(
      name: 'Farmersville',
      bounds: GeoBounds(
        west: -119.2207,
        south: 36.2771,
        east: -119.1944,
        north: 36.3265,
      ),
      portals: [
        GisPortal(
          root:
              'https://services.arcgis.com/dRrcwQZbqpECq4LI/arcgis/rest/services',
          publisher: 'City of Farmersville',
          tier: PortalTier.city,
          serviceCount: 6,
        ),
      ],
    ),
    CityPortals(
      name: 'Porterville',
      bounds: GeoBounds(
        west: -119.0982,
        south: 36.0077,
        east: -118.9639,
        north: 36.1164,
      ),
      portals: [
        GisPortal(
          root:
              'https://services6.arcgis.com/KUb9MOaWQkVh1cNC/arcgis/rest/services',
          publisher: 'City of Porterville',
          tier: PortalTier.city,
          serviceCount: 38,
        ),
      ],
    ),
    CityPortals(
      name: 'Visalia',
      bounds: GeoBounds(
        west: -119.4747,
        south: 36.2695,
        east: -119.2338,
        north: 36.3711,
      ),
      portals: [
        GisPortal(
          root:
              'https://services7.arcgis.com/q3SI94vj8qWDxwBr/arcgis/rest/services',
          publisher: 'City of Visalia',
          tier: PortalTier.city,
          serviceCount: 92,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/q3SI94vj8qWDxwBr/arcgis/rest/services',
          publisher: 'City of Visalia',
          tier: PortalTier.city,
          serviceCount: 8,
        ),
      ],
    ),
  ],
  'ca_ventura': [
    CityPortals(
      name: 'Camarillo',
      bounds: GeoBounds(
        west: -119.1095,
        south: 34.1913,
        east: -118.9578,
        north: 34.2525,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/EKquOdzev2aNwKyB/arcgis/rest/services',
          publisher: 'City of Camarillo',
          tier: PortalTier.city,
          serviceCount: 124,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/EKquOdzev2aNwKyB/arcgis/rest/services',
          publisher: 'City of Camarillo',
          tier: PortalTier.city,
          serviceCount: 3,
        ),
      ],
    ),
    CityPortals(
      name: 'Oxnard',
      bounds: GeoBounds(
        west: -119.2664,
        south: 34.1195,
        east: -119.1197,
        north: 34.261,
      ),
      portals: [
        GisPortal(
          root:
              'https://services3.arcgis.com/PWexKTkN39Lf339y/arcgis/rest/services',
          publisher: 'City of Oxnard',
          tier: PortalTier.city,
          serviceCount: 103,
        ),
        GisPortal(
          root: 'https://maps.oxnard.org/arcgis/rest/services',
          publisher: 'City of Oxnard',
          tier: PortalTier.city,
          serviceCount: 65,
        ),
      ],
    ),
    CityPortals(
      name: 'Simi Valley',
      bounds: GeoBounds(
        west: -118.8311,
        south: 34.2084,
        east: -118.6326,
        north: 34.3226,
      ),
      portals: [
        GisPortal(
          root:
              'https://services2.arcgis.com/veo8Y0Humcq1N811/arcgis/rest/services',
          publisher: 'City of Simi Valley',
          tier: PortalTier.city,
          serviceCount: 31,
        ),
        GisPortal(
          root:
              'https://tiles.arcgis.com/tiles/veo8Y0Humcq1N811/arcgis/rest/services',
          publisher: 'City of Simi Valley',
          tier: PortalTier.city,
          serviceCount: 5,
        ),
      ],
    ),
  ],
  'ca_yolo': [
    CityPortals(
      name: 'Davis',
      bounds: GeoBounds(
        west: -121.794,
        south: 38.5313,
        east: -121.6758,
        north: 38.5755,
      ),
      portals: [
        GisPortal(
          root: 'https://gis.cityofdavis.org/arcgis/rest/services',
          publisher: 'City of Davis',
          tier: PortalTier.city,
          serviceCount: 242,
        ),
        GisPortal(
          root:
              'https://services2.arcgis.com/4I44Np15ithmkJtb/arcgis/rest/services',
          publisher: 'City of Davis',
          tier: PortalTier.city,
          serviceCount: 17,
        ),
      ],
    ),
    CityPortals(
      name: 'West Sacramento',
      bounds: GeoBounds(
        west: -121.5891,
        south: 38.5016,
        east: -121.5062,
        north: 38.6023,
      ),
      portals: [
        GisPortal(
          root:
              'https://services5.arcgis.com/rAPK9OWCvAUbTKLM/arcgis/rest/services',
          publisher: 'City of West Sacramento',
          tier: PortalTier.city,
          serviceCount: 24,
        ),
      ],
    ),
    CityPortals(
      name: 'Woodland',
      bounds: GeoBounds(
        west: -121.8027,
        south: 38.6375,
        east: -121.6853,
        north: 38.7095,
      ),
      portals: [
        GisPortal(
          root: 'https://gis.cityofwoodland.org/cowgis/rest/services',
          publisher: 'City of Woodland',
          tier: PortalTier.city,
          serviceCount: 138,
        ),
        GisPortal(
          root:
              'https://services5.arcgis.com/QfFJJU2FARaLlY26/arcgis/rest/services',
          publisher: 'City of Woodland',
          tier: PortalTier.city,
          serviceCount: 54,
        ),
      ],
    ),
  ],
};

/// Catalogues covering the whole country, offered in every county.
///
/// Federal servers whose data does not stop at a state line: the Census
/// Bureau layer every county reads its own boundary from, the USGS National
/// Map, the National Weather Service, FEMA's flood hazard layers, the Forest
/// Service, the Park Service and the EPA.
///
/// This is what stops any county's layer panel opening empty, wherever it is.
const nationalPortals = <GisPortal>[
  GisPortal(
    root: 'https://mapservices.weather.noaa.gov/static/rest/services',
    publisher: 'National Weather Service',
    tier: PortalTier.national,
    serviceCount: 224,
  ),
  GisPortal(
    root: 'https://tigerweb.geo.census.gov/arcgis/rest/services',
    publisher: 'US Census Bureau',
    tier: PortalTier.national,
    serviceCount: 173,
  ),
  GisPortal(
    root: 'https://apps.fs.usda.gov/arcx/rest/services',
    publisher: 'US Forest Service',
    tier: PortalTier.national,
    serviceCount: 151,
  ),
  GisPortal(
    root: 'https://geopub.epa.gov/arcgis/rest/services',
    publisher: 'US Environmental Protection Agency',
    tier: PortalTier.national,
    serviceCount: 151,
  ),
  GisPortal(
    root: 'https://gis.fema.gov/arcgis/rest/services',
    publisher: 'FEMA',
    tier: PortalTier.national,
    serviceCount: 76,
  ),
  GisPortal(
    root: 'https://mapservices.nps.gov/arcgis/rest/services',
    publisher: 'National Park Service',
    tier: PortalTier.national,
    serviceCount: 27,
  ),
  GisPortal(
    root: 'https://hazards.fema.gov/arcgis/rest/services',
    publisher: 'FEMA',
    tier: PortalTier.national,
    serviceCount: 20,
  ),
  GisPortal(
    root: 'https://carto.nationalmap.gov/arcgis/rest/services',
    publisher: 'USGS National Map',
    tier: PortalTier.national,
    serviceCount: 10,
  ),
  GisPortal(
    root: 'https://hydro.nationalmap.gov/arcgis/rest/services',
    publisher: 'USGS National Map',
    tier: PortalTier.national,
    serviceCount: 8,
  ),
  GisPortal(
    root: 'https://mapservices.weather.noaa.gov/eventdriven/rest/services',
    publisher: 'National Weather Service',
    tier: PortalTier.national,
    serviceCount: 7,
  ),
  GisPortal(
    root: 'https://elevation.nationalmap.gov/arcgis/rest/services',
    publisher: 'USGS National Map',
    tier: PortalTier.national,
    serviceCount: 4,
  ),
];

/// State agency catalogues, keyed by two-digit state FIPS code.
///
/// A state agency's data stops at the state line, so offering it anywhere
/// else would attribute coverage the publisher never claimed — the same
/// provenance error [PortalTier] exists to prevent. CAL FIRE's hazard
/// severity zones are a fact about California and are offered in California.
///
/// A state absent here has no agency catalogue in this build. Its counties
/// still get [nationalPortals] and whatever they publish themselves.
const statePortals = <String, List<GisPortal>>{
  '06': [
    GisPortal(
      root:
          'https://services2.arcgis.com/Uq9r85Potqm3MfRV/arcgis/rest/services',
      publisher: 'California Department of Fish and Wildlife',
      tier: PortalTier.statewide,
      serviceCount: 2494,
    ),
    GisPortal(
      root:
          'https://services1.arcgis.com/jUJYIo9tSA7EHvfZ/arcgis/rest/services',
      publisher: 'CAL FIRE',
      tier: PortalTier.statewide,
      serviceCount: 1307,
    ),
    GisPortal(
      root: 'https://services.arcgis.com/BLN4oKB0N1YSgvY8/arcgis/rest/services',
      publisher: 'California Governor\'s Office of Emergency Services',
      tier: PortalTier.statewide,
      serviceCount: 1005,
    ),
    GisPortal(
      root: 'https://gispublic.waterboards.ca.gov/portalserver/rest/services',
      publisher: 'California Water Boards',
      tier: PortalTier.statewide,
      serviceCount: 733,
    ),
    GisPortal(
      root: 'https://caltrans-gis.dot.ca.gov/arcgis/rest/services',
      publisher: 'Caltrans',
      tier: PortalTier.statewide,
      serviceCount: 233,
    ),
    GisPortal(
      root: 'https://gis.conservation.ca.gov/server/rest/services',
      publisher: 'California Department of Conservation',
      tier: PortalTier.statewide,
      serviceCount: 180,
    ),
    GisPortal(
      root: 'https://gis.water.ca.gov/arcgis/rest/services',
      publisher: 'California Department of Water Resources',
      tier: PortalTier.statewide,
      serviceCount: 145,
    ),
    GisPortal(
      root:
          'https://services3.arcgis.com/bWPjFyq029ChCGur/arcgis/rest/services',
      publisher: 'California Energy Commission',
      tier: PortalTier.statewide,
      serviceCount: 144,
    ),
    GisPortal(
      root:
          'https://services7.arcgis.com/iwxhJVOFEKDxO7gk/arcgis/rest/services',
      publisher: 'California State Board of Equalization',
      tier: PortalTier.statewide,
      serviceCount: 117,
    ),
    GisPortal(
      root: 'https://gis.blm.gov/caarcgis/rest/services',
      publisher: 'Bureau of Land Management California',
      tier: PortalTier.statewide,
      serviceCount: 40,
    ),
    GisPortal(
      root: 'https://gis.wildlife.ca.gov/images/rest/services',
      publisher: 'California Department of Fish and Wildlife',
      tier: PortalTier.statewide,
      serviceCount: 37,
    ),
    GisPortal(
      root: 'https://services.gis.ca.gov/arcgis/rest/services',
      publisher: 'California State Geoportal',
      tier: PortalTier.statewide,
      serviceCount: 20,
    ),
  ],
};

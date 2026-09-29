/// A field as advertised by an ArcGIS layer.
final class LayerField {
  const LayerField({required this.name, this.alias = '', this.type = ''});
  factory LayerField.fromJson(Map<String, Object?> json) => LayerField(
    name: json['name'] as String? ?? '',
    alias: json['alias'] as String? ?? '',
    type: json['type'] as String? ?? '',
  );
  final String name;
  final String alias;
  final String type;
}

/// Immutable, serializable mapping from semantic roles to published columns.
final class ParcelFieldMap {
  ParcelFieldMap(
    Map<String, String> fields, {
    List<String> addressCandidates = const [],
  }) : fields = Map.unmodifiable(fields),
       addressCandidates = List.unmodifiable(addressCandidates);
  factory ParcelFieldMap.fromJson(Map<String, Object?> json) => ParcelFieldMap(
    (json['fields'] as Map).cast<String, String>(),
    addressCandidates: (json['addressCandidates'] as List).cast<String>(),
  );
  final Map<String, String> fields;
  final List<String> addressCandidates;
  String get objectIdField => fields['oid']!;
  String get apnField => fields['apn']!;
  String? get fullAddressField => fields['address'];
  String? get ownerField => fields['owner'];
  String? get countyScopeField => fields['county'];
  String get outFields => {...fields.values, ...addressCandidates}.join(',');
  Map<String, Object?> toJson() => {
    'fields': fields,
    'addressCandidates': addressCandidates,
  };
  ParcelFieldMap withAddress(String field) => ParcelFieldMap({
    ...fields,
    'address': field,
  }, addressCandidates: addressCandidates);
  String value(Map<String, Object?> row, String role) =>
      row[fields[role]]?.toString().trim() ?? '';
  String address(Map<String, Object?> row) => fullAddressField != null
      ? value(row, 'address')
      : [
          'number',
          'prefix',
          'street',
          'type',
          'suffix',
          'unit',
        ].map((role) => value(row, role)).where((v) => v.isNotEmpty).join(' ');
}

String _key(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// Detects situs fields by name and alias, never by mailing-address columns.
ParcelFieldMap? detectParcelFields(
  List<LayerField> fields, {
  String? objectIdField,
}) {
  final usable = fields
      .where(
        (f) =>
            f.type != 'esriFieldTypeGeometry' &&
            RegExp(r'^[A-Za-z_][A-Za-z0-9_.]*$').hasMatch(f.name),
      )
      .toList();
  String? pick(
    List<String> names, {
    bool Function(String)? fallback,
    bool situs = false,
  }) {
    for (final name in names) {
      for (final f in usable) {
        if (situs &&
            RegExp(
              'mail|owner|tax|billing',
            ).hasMatch(_key(f.name) + _key(f.alias))) {
          continue;
        }
        if (_key(f.name) == name || _key(f.alias) == name) return f.name;
      }
    }
    for (final f in usable) {
      if (situs &&
          RegExp(
            'mail|owner|tax|billing',
          ).hasMatch(_key(f.name) + _key(f.alias))) {
        continue;
      }
      if (fallback != null &&
          (fallback(_key(f.name)) || fallback(_key(f.alias)))) {
        return f.name;
      }
    }
    return null;
  }

  final oid =
      objectIdField ??
      fields.where((f) => f.type == 'esriFieldTypeOID').firstOrNull?.name;
  final apn = pick(
    [
      'apn',
      'parcelapn',
      'parcelnumber',
      'parcelno',
      'parcelid',
      'countypin',
      'pin',
      'pinnum',
      'pinnumber',
      'ain',
      'prclnum',
      'hcadnum',
      'lowparcelid',
      'taxparcelid',
      'assessorparcelnumber',
    ],
    fallback: (s) =>
        s.contains('apn') || RegExp(r'parcel(id|num|no)').hasMatch(s),
  );
  if (oid == null || apn == null || oid == apn) return null;
  final addresses = <String>[];
  final remaining = List<LayerField>.of(usable);
  const addressNames = [
    'siteaddr',
    'siteaddress',
    'situsstreet',
    'situsaddress',
    'propertyfullstreetaddress',
    'physicaladdress',
    'propertyaddress',
    'locationaddress',
    'propaddr',
    'compaddr',
    'fulladdr',
    'addrfull',
    'fullstreetaddress',
    'fulladdress',
    'address',
  ];
  for (final name in addressNames) {
    for (final field in remaining.toList()) {
      final key = _key(field.name) + _key(field.alias);
      if (!RegExp('mail|owner|tax|billing').hasMatch(key) &&
          (_key(field.name) == name || _key(field.alias) == name)) {
        addresses.add(field.name);
        remaining.remove(field);
      }
    }
  }
  for (final field in remaining) {
    final key = _key(field.name);
    if (!RegExp('mail|owner|tax|billing').hasMatch(key + _key(field.alias)) &&
        RegExp(
          r'^(situs|site|property|physical|location|prop|comp).*(addr|address)$',
        ).hasMatch(key)) {
      addresses.add(field.name);
    }
  }
  final roles = <String, String>{'oid': oid, 'apn': apn};
  void add(String role, List<String> names, {bool situs = true}) {
    final field = pick(names, situs: situs);
    if (field != null &&
        !(role == 'owner' &&
            RegExp('addr|mail|billing').hasMatch(_key(field)))) {
      roles[role] = field;
    }
  }

  add('number', [
    'sitehousenumber',
    'sitestrnum',
    'propertystreetnumber',
    'sitenum',
    'anumber',
    'addrnum',
    'housenumber',
    'addressnumber',
  ]);
  add('street', [
    'sitestreetname',
    'sitestrname',
    'propertystreetname',
    'stname',
    'streetname',
    'rdname',
    'fullname',
  ]);
  add('prefix', [
    'sitedirection',
    'sitepredir',
    'sitestrpfx',
    'propertystreetprefixdirection',
    'predir',
    'prefixdirection',
    'stpredir',
  ]);
  add('type', [
    'sitemode',
    'sitestrtype',
    'sitestrsfx',
    'stpostyp',
    'streettype',
    'sttype',
    'stsuf',
  ]);
  add('suffix', [
    'sitepostdir',
    'sitestrsfxdir',
    'stposdir',
    'postdir',
    'suffixdirection',
  ]);
  add('unit', ['siteunit', 'unit', 'unitnum']);
  add('city', [
    'sitecity',
    'situscity',
    'propertycity',
    'physicalcity',
    'ctyname',
    'postcomm',
    'city',
    'municipality',
    'jurisdiction',
  ]);
  add('zip', [
    'sitezip',
    'sitezipcode',
    'propertyzipcode',
    'physicalzip',
    'zip5',
    'zipcode',
    'zip',
    'rovzipc',
  ]);
  add('owner', [
    'ownername',
    'ownername1',
    'owner1',
    'owner',
    'taxownername',
  ], situs: false);
  add('county', [
    'countyfips',
    'fipscode',
    'countyname',
    'coname',
    'county',
    'cocode',
  ], situs: false);
  add('landUse', ['landuse', 'landusecode', 'classcode', 'assessdescription']);
  add('acreage', ['acreage', 'acres', 'gisacres']);
  if (addresses.isNotEmpty) roles['address'] = addresses.first;
  if (addresses.isEmpty &&
      !(roles.containsKey('number') && roles.containsKey('street'))) {
    return null;
  }
  return ParcelFieldMap(roles, addressCandidates: addresses);
}

/// A populated street line, excluding punctuation placeholders and zero lots.
bool plausibleParcelAddress(String value) =>
    RegExp(r'^[1-9][0-9A-Za-z/-]*\s+.*[A-Za-z]').hasMatch(value.trim());

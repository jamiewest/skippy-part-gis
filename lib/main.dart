import 'package:flutter/material.dart';
import 'package:riverside_atlas/app/app.dart';
import 'package:riverside_atlas/app/dependencies.dart';
import 'package:riverside_atlas/data/services/county_source.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = AppDependencies.create(county: CountySources.riverside);
  runApp(RiversideAtlasApp(dependencies: dependencies));
}

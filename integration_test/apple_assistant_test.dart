// Run on an Apple Intelligence device with the system model ready:
// flutter drive --driver=test_driver/integration_test.dart \
//   --target=integration_test/apple_assistant_test.dart -d macos
// The model is real; Census values are fixtures. No microphone is opened.
import 'package:extensions/ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_models/foundation_models.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:riverside_atlas/app/atlas_assistant.dart';
import 'package:riverside_atlas/data/services/assistant/apple_assistant_backend.dart';
import 'package:riverside_atlas/data/services/census_service.dart';
import 'package:riverside_atlas/data/services/map_assistant_tools.dart';
import 'package:riverside_atlas/ui/features/map/map_workspace.dart';
import 'package:riverside_atlas/ui/features/map/view_models/map_assistant.dart';
import 'package:riverside_atlas/ui/features/map/widgets/assistant_panel.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Apple model calls map tools and shows sourced Census figures', (
    tester,
  ) async {
    final client = http.Client();
    addTearDown(client.close);
    final calls = <String>[];
    final tools = buildMapTools(
      workspace: MapWorkspace(),
      census: CensusService(client),
    );
    final fixtureTools = tools
        .whereType<AIFunction>()
        .map(
          (tool) => AIFunctionFactory.create(
            name: tool.name,
            description: tool.description,
            parametersSchema: tool.parametersSchema,
            callback: (arguments, {cancellationToken}) async {
              calls.add(tool.name);
              return switch (tool.name) {
                'describe_map' => {
                  'county': 'Riverside County, CA',
                  'drawnArea': {'shape': 'circle', 'status': 'ready'},
                },
                'get_area_demographics' => {
                  'source': 'US Census Bureau, ACS 2023 5-year estimates',
                  'dataset': '2023/acs/acs5',
                  'tractsRead': 1,
                  'coversWholeTracts': true,
                  'figuresAvailable': true,
                  'tracts': ['Census Tract 101'],
                  'measures': {
                    'Population': {'totalAcrossTracts': 4321},
                  },
                },
                _ => {'note': 'Only the already drawn area is relevant.'},
              };
            },
          ),
        )
        .toList();
    final backend = AppleAssistantBackend(
      instructions: assistantInstructions,
      tools: fixtureTools,
    );
    expect(
      await backend.checkAvailability(),
      isNull,
      reason: 'This test requires Apple Intelligence and a ready system model.',
    );
    for (final tool in backend.tools) {
      await FoundationModels.validateSchema(tool.parameters);
    }
    final assistant = MapAssistant.withBackend(backend);
    addTearDown(assistant.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantPanel(assistant: assistant, onClose: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('assistant-input')),
      'Use describe_map and get_area_demographics to tell me the published '
      'population for the census tracts touching my drawn area. '
      'Include the number, source and year.',
    );
    await tester.tap(find.byKey(const Key('assistant-send-button')));
    final deadline = DateTime.now().add(const Duration(seconds: 120));
    while (assistant.isThinking && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(assistant.isThinking, isFalse);
    expect(calls, contains('describe_map'));
    expect(calls, contains('get_area_demographics'));
    final answer = assistant.messages.last;
    expect(answer.role, AssistantRole.assistant, reason: answer.text);
    expect(answer.text.replaceAll(',', ''), contains('4321'));
    expect(answer.text, contains('2023'));
    expect(find.text(answer.text), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }, timeout: const Timeout(Duration(minutes: 3)));
}

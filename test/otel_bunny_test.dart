// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_bunny/otel_bunny.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_bunny-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('storage.upload records product + bytes + region', () async {
    await tracedBunny<String>(
      operation: 'storage.upload',
      product: 'storage',
      invoke: () async => const BunnyCallResult(
        value: 'ok',
        result: BunnyResult(
          product: 'storage',
          zoneId: 100,
          region: 'de',
          bytes: 2048576,
          statusCode: 201,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('bunny storage.upload')!);
    expect(a['bunny.product'], 'storage');
    expect(a['bunny.region'], 'de');
    expect(a['bunny.bytes'], 2048576);
  });

  test('pullzone.purge records soft flag', () async {
    await tracedBunny<String>(
      operation: 'pullzone.purge',
      invoke: () async => const BunnyCallResult(
        value: 'ok',
        result: BunnyResult(product: 'cdn_pull', purgeIsSoft: true),
      ),
    );
    final a = attrsOf(spans.findSpanByName('bunny pullzone.purge')!);
    expect(a['bunny.purge.soft'], true);
  });

  test('stream.video.get records resolution + duration', () async {
    await tracedBunny<String>(
      operation: 'stream.video.get',
      invoke: () async => const BunnyCallResult(
        value: 'ok',
        result: BunnyResult(
          product: 'stream',
          streamVideoId: 'vid-1',
          streamResolution: '1080p',
          streamDurationSec: 600.0,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('bunny stream.video.get')!);
    expect(a['bunny.stream.video.id'], 'vid-1');
    expect(a['bunny.stream.resolution'], '1080p');
    expect(a['bunny.stream.duration_sec'], 600.0);
  });

  test('suppression skips spans', () async {
    await runWithoutBunnyInstrumentationAsync(() async {
      await tracedBunny<String>(
        operation: 'pullzone.list',
        invoke: () async => const BunnyCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('bunny '), isEmpty);
  });
}

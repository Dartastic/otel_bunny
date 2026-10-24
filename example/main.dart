// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_bunny/otel_bunny.dart';

/// Traces Bunny.net calls with OpenTelemetry.
///
/// `otel_bunny` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Bunny.net call in
/// [tracedBunny]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'bunny-example');

  // Wraps a Bunny.net API call in a CLIENT span.
  final bunnyId = await tracedBunny<String>(
    operation: 'pullzone.create',
    product: 'example',
    invoke: () async {
      // Make the Bunny.net call here, then report what it returned.
      const id = 'bunny_8f3a2c';
      return const BunnyCallResult(
          value: id,
          result: BunnyResult(
              product: 'cdn_pull',
              zoneId: 1,
              region: 'de',
              bytes: 512,
              cacheHit: true,
              purgeIsSoft: true,
              streamVideoId: 'streamvideo_8f3a2c',
              streamResolution: '1080p',
              streamDurationSec: 0.5,
              requestId: 'cdn-cachetagid',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedBunny pullzone.create returned $bunnyId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutBunnyInstrumentationAsync.
  await runWithoutBunnyInstrumentationAsync(
    () => tracedBunny<String>(
      operation: 'pullzone.create',
      product: 'example',
      invoke: () async {
        const id = 'bunny_8f3a2c';
        return const BunnyCallResult(
            value: id,
            result: BunnyResult(
                product: 'cdn_pull',
                zoneId: 1,
                region: 'de',
                bytes: 512,
                cacheHit: true,
                purgeIsSoft: true,
                streamVideoId: 'streamvideo_8f3a2c',
                streamResolution: '1080p',
                streamDurationSec: 0.5,
                requestId: 'cdn-cachetagid',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}

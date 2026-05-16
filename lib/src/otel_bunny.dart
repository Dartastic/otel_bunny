// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_bunny_suppression.dart';

const _tracerName = 'dartastic_otel_libs_bunny';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class BunnyResult {
  const BunnyResult({
    this.product,
    this.zoneId,
    this.region,
    this.bytes,
    this.cacheHit,
    this.purgeIsSoft,
    this.streamVideoId,
    this.streamResolution,
    this.streamDurationSec,
    this.requestId,
    this.statusCode,
  });

  /// `cdn_pull` / `storage` / `edge_storage` / `stream` /
  /// `magic_containers` / `optimizer` / `dns` — Bunny prices per-product.
  final String? product;

  /// Pull/Storage/Stream library zone id.
  final int? zoneId;

  /// `de` / `ny` / `la` / `sg` / `syd` — primary region.
  final String? region;

  /// Object size in bytes (uploads/downloads).
  final int? bytes;

  /// `X-Cache: HIT|MISS` (Bunny CDN edge).
  final bool? cacheHit;

  /// Whether a purge was soft (revalidate at edge) vs hard.
  final bool? purgeIsSoft;

  /// Stream video GUID.
  final String? streamVideoId;

  /// `1080p` / `720p` / `480p` etc. requested resolution.
  final String? streamResolution;

  /// Video duration.
  final double? streamDurationSec;

  /// `cdn-cachetagid` / `x-request-id`.
  final String? requestId;

  final int? statusCode;
}

class BunnyCallResult<T> {
  const BunnyCallResult({required this.value, this.result});
  final T value;
  final BunnyResult? result;
}

/// Wraps a Bunny.net API call in a CLIENT span. [operation] is one of
/// `pullzone.list`, `pullzone.create`, `pullzone.purge`,
/// `storage.upload`, `storage.download`, `storage.delete`,
/// `storage.list`, `stream.video.upload`, `stream.video.get`,
/// `stream.video.delete`, `stream.collection.list`,
/// `stream.collection.create`, `dns.records.list`,
/// `magic_containers.deploy`, `optimizer.purge`, `statistics.zone`.
Future<T> tracedBunny<T>({
  required String operation,
  required Future<BunnyCallResult<T>> Function() invoke,
  String? product,
}) async {
  if (bunnyInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'bunny',
    'rpc.method': operation,
    'bunny.operation': operation,
  };
  if (product != null) m['bunny.product'] = product;

  final span = _tracer().startSpan(
    'bunny $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.product != null) {
        extras.add(OTel.attributeString(
          'bunny.product',
          r.result!.product!,
        ));
      }
      if (r.result!.zoneId != null) {
        extras.add(OTel.attributeInt(
          'bunny.zone.id',
          r.result!.zoneId!,
        ));
      }
      if (r.result!.region != null) {
        extras.add(OTel.attributeString(
          'bunny.region',
          r.result!.region!,
        ));
      }
      if (r.result!.bytes != null) {
        extras.add(OTel.attributeInt(
          'bunny.bytes',
          r.result!.bytes!,
        ));
      }
      if (r.result!.cacheHit != null) {
        extras.add(OTel.attributeBool(
          'bunny.cache.hit',
          r.result!.cacheHit!,
        ));
      }
      if (r.result!.purgeIsSoft != null) {
        extras.add(OTel.attributeBool(
          'bunny.purge.soft',
          r.result!.purgeIsSoft!,
        ));
      }
      if (r.result!.streamVideoId != null) {
        extras.add(OTel.attributeString(
          'bunny.stream.video.id',
          r.result!.streamVideoId!,
        ));
      }
      if (r.result!.streamResolution != null) {
        extras.add(OTel.attributeString(
          'bunny.stream.resolution',
          r.result!.streamResolution!,
        ));
      }
      if (r.result!.streamDurationSec != null) {
        extras.add(OTel.attributeDouble(
          'bunny.stream.duration_sec',
          r.result!.streamDurationSec!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'bunny.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Bunny HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

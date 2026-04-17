// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/parking_spot.dart';

@JS('kakao')
external JSObject? get kakao;

@JS('eval')
external JSObject jsEval(JSString code);

class WebKakaoMap extends StatefulWidget {
  final List<ParkingSpot> spots;
  final ValueChanged<ParkingSpot>? onSpotTap;

  const WebKakaoMap({
    super.key,
    required this.spots,
    this.onSpotTap,
  });

  @override
  State<WebKakaoMap> createState() => _WebKakaoMapState();
}

class _WebKakaoMapState extends State<WebKakaoMap> {
  static Completer<void>? _sdkLoadCompleter;
  static bool _sdkScriptRequested = false;

  final web.HTMLDivElement _mapElement = web.document.createElement('div') as web.HTMLDivElement
    ..style.width = '100%'
    ..style.height = '100%';

  late final String _viewType;

  JSObject? _maps;
  JSObject? _map;
  JSObject? _clusterer;
  final List<JSObject> _markerRefs = [];

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _viewType = 'kakao-map-view-${DateTime.now().microsecondsSinceEpoch}';
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) => _mapElement);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeKakaoMap();
    });
  }

  @override
  void didUpdateWidget(covariant WebKakaoMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_map != null && oldWidget.spots != widget.spots) {
      _renderMarkers();
    }
  }

  Future<void> _initializeKakaoMap() async {
    final kakaoJsKey = dotenv.env['KAKAO_JS_KEY'] ?? const String.fromEnvironment('KAKAO_JS_KEY', defaultValue: '3cd29c9d5d9313c116fa1f9048fba176');
    if (kakaoJsKey.isEmpty) {
      setState(() {
        _errorMessage = 'KAKAO_JS_KEY가 설정되지 않았습니다. .env를 확인하세요.';
      });
      return;
    }

    try {
      await _loadSdk(kakaoJsKey);
      _maps = kakao?.getProperty<JSObject>('maps'.toJS);

      _maps?.callMethod(
        'load'.toJS,
        (() => _createMap()).toJS,
      );
    } catch (e) {
      setState(() {
        _errorMessage = '카카오 지도 SDK 로드에 실패했습니다: $e';
      });
    }
  }

  Future<void> _loadSdk(String kakaoJsKey) async {
    _sdkLoadCompleter ??= Completer<void>();
    if (_sdkLoadCompleter!.isCompleted) return _sdkLoadCompleter!.future;

    if (!_sdkScriptRequested) {
      _sdkScriptRequested = true;
      final web.HTMLScriptElement script = web.document.createElement('script') as web.HTMLScriptElement
        ..async = true
        // CRITICAL: Added libraries=clusterer for performance optimization
        ..src = 'https://dapi.kakao.com/v2/maps/sdk.js?appkey=$kakaoJsKey&autoload=false&libraries=services,clusterer';

      script.onload = ((web.Event _) {
        if (!_sdkLoadCompleter!.isCompleted) _sdkLoadCompleter!.complete();
      }).toJS;

      script.onerror = ((web.Event _) {
        if (!_sdkLoadCompleter!.isCompleted) _sdkLoadCompleter!.completeError('SDK script load error');
      }).toJS;

      web.document.head?.appendChild(script);
    }
    return _sdkLoadCompleter!.future;
  }

  void _createMap() {
    final double centerLat = widget.spots.isNotEmpty ? widget.spots.first.lat : 37.5665;
    final double centerLng = widget.spots.isNotEmpty ? widget.spots.first.lng : 126.9780;

    final JSObject? center = jsEval('new kakao.maps.LatLng($centerLat, $centerLng)'.toJS);
    final JSObject options = JSObject();
    if (center != null) options.setProperty('center'.toJS, center);
    options.setProperty('level'.toJS, 4.toJS);

    globalContext.setProperty('__tempMapContainer'.toJS, _mapElement as JSObject);
    globalContext.setProperty('__tempMapOptions'.toJS, options);
    _map = jsEval('new kakao.maps.Map(window.__tempMapContainer, window.__tempMapOptions)'.toJS);

    // Initialize Clusterer
    final JSObject clusterOptions = JSObject();
    clusterOptions.setProperty('map'.toJS, _map!);
    clusterOptions.setProperty('averageCenter'.toJS, true.toJS);
    clusterOptions.setProperty('minLevel'.toJS, 7.toJS); // Cluster from level 7

    globalContext.setProperty('__tempClusterOptions'.toJS, clusterOptions);
    _clusterer = jsEval('new kakao.maps.MarkerClusterer(window.__tempClusterOptions)'.toJS);

    _renderMarkers();
  }

  void _renderMarkers() {
    if (_clusterer == null) return;
    
    final JSObject? eventNamespace = _maps?.getProperty<JSObject>('event'.toJS);
    
    // Clear existing
    _clusterer?.callMethod('clear'.toJS);
    _markerRefs.clear();

    final List<JSObject> markersToCluster = [];

    // Optimization: Batch processing even for thousands of markers
    for (final ParkingSpot spot in widget.spots) {
      final JSObject? position = jsEval('new kakao.maps.LatLng(${spot.lat}, ${spot.lng})'.toJS);
      
      final JSObject markerOptions = JSObject();
      if (position != null) markerOptions.setProperty('position'.toJS, position);

      globalContext.setProperty('__tempMarkerOptions'.toJS, markerOptions);
      final JSObject? marker = jsEval('new kakao.maps.Marker(window.__tempMarkerOptions)'.toJS);
      
      if (marker != null) {
        eventNamespace?.callMethod(
          'addListener'.toJS,
          marker,
          'click'.toJS,
          (() => widget.onSpotTap?.call(spot)).toJS,
        );
        markersToCluster.add(marker);
        _markerRefs.add(marker);
      }
    }

    // Add multiple markers at once for better performance
    globalContext.setProperty('__tempMarkersToCluster'.toJS, markersToCluster.toJS);
    jsEval('window.__clustererRef.addMarkers(window.__tempMarkersToCluster)'.toJS);
    
    // Wire up clusterer reference securely
    if (_clusterer != null) {
      globalContext.setProperty('__clustererRef'.toJS, _clusterer!);
      jsEval('window.__clustererRef.addMarkers(window.__tempMarkersToCluster)'.toJS);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }
    return HtmlElementView(viewType: _viewType);
  }
}

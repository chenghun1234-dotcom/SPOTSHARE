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

// Helper to handle simple constructor calls via JS Function evaluation
// as a safe workaround for dynamic constructors in dart:js_interop
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
        _errorMessage = 'KAKAO_JS_KEY가 설정되지 않았습니다. spotshare_app/.env를 확인하세요.';
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

    if (_sdkLoadCompleter!.isCompleted) {
      return _sdkLoadCompleter!.future;
    }

    if (!_sdkScriptRequested) {
      _sdkScriptRequested = true;

      final web.HTMLScriptElement script = web.document.createElement('script') as web.HTMLScriptElement
        ..async = true
        ..src = 'https://dapi.kakao.com/v2/maps/sdk.js?appkey=$kakaoJsKey&autoload=false';

      script.onload = ((web.Event _) {
        if (!_sdkLoadCompleter!.isCompleted) {
          _sdkLoadCompleter!.complete();
        }
      }).toJS;

      script.onerror = ((web.Event _) {
        if (!_sdkLoadCompleter!.isCompleted) {
          _sdkLoadCompleter!.completeError('SDK script load error');
        }
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

    // Call constructor dynamically using js_interop safe invocation
    // A trick when constructors are hard to declare: assign object to window, then instatiate JS.
    globalContext.setProperty('__tempMapContainer'.toJS, _mapElement as JSObject);
    globalContext.setProperty('__tempMapOptions'.toJS, options);
    _map = jsEval('new kakao.maps.Map(window.__tempMapContainer, window.__tempMapOptions)'.toJS);

    _renderMarkers();
  }

  void _renderMarkers() {
    final JSObject? eventNamespace = _maps?.getProperty<JSObject>('event'.toJS);

    for (final marker in _markerRefs) {
      marker.callMethod('setMap'.toJS, null);
    }
    _markerRefs.clear();

    for (final ParkingSpot spot in widget.spots) {
      final JSObject? position = jsEval('new kakao.maps.LatLng(${spot.lat}, ${spot.lng})'.toJS);
      
      final JSObject markerOptions = JSObject();
      if (position != null) markerOptions.setProperty('position'.toJS, position);

      globalContext.setProperty('__tempMarkerOptions'.toJS, markerOptions);
      final JSObject? marker = jsEval('new kakao.maps.Marker(window.__tempMarkerOptions)'.toJS);
      
      if (marker != null) {
        marker.callMethod('setMap'.toJS, _map);

        eventNamespace?.callMethod(
          'addListener'.toJS,
          // Convert arguments properly if needed, but JSObject can be passed directly.
          marker,
          'click'.toJS,
          (() => widget.onSpotTap?.call(spot)).toJS,
        );

        _markerRefs.add(marker);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return HtmlElementView(viewType: _viewType);
  }
}

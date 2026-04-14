// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/parking_spot.dart';

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

  final html.DivElement _mapElement = html.DivElement()
    ..style.width = '100%'
    ..style.height = '100%';

  late final String _viewType;

  dynamic _maps;
  dynamic _map;
  final List<dynamic> _markerRefs = <dynamic>[];

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
    final kakaoJsKey = dotenv.env['KAKAO_JS_KEY'] ?? const String.fromEnvironment('KAKAO_JS_KEY', defaultValue: '');
    if (kakaoJsKey.isEmpty) {
      setState(() {
        _errorMessage = 'KAKAO_JS_KEY가 설정되지 않았습니다. spotshare_app/.env에 값을 넣거나 --dart-define=KAKAO_JS_KEY=YOUR_KEY 를 추가하세요.';
      });
      return;
    }

    try {
      await _loadSdk(kakaoJsKey);
      final kakao = js_util.getProperty(html.window, 'kakao');
      _maps = js_util.getProperty(kakao, 'maps');

      js_util.callMethod(
        _maps,
        'load',
        <dynamic>[
          js_util.allowInterop(() {
            _createMap();
          }),
        ],
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

      final html.ScriptElement script = html.ScriptElement()
        ..async = true
        ..src = 'https://dapi.kakao.com/v2/maps/sdk.js?appkey=$kakaoJsKey&autoload=false';

      script.onLoad.listen((_) {
        if (!_sdkLoadCompleter!.isCompleted) {
          _sdkLoadCompleter!.complete();
        }
      });

      script.onError.listen((_) {
        if (!_sdkLoadCompleter!.isCompleted) {
          _sdkLoadCompleter!.completeError('SDK script load error');
        }
      });

      html.document.head?.append(script);
    }

    return _sdkLoadCompleter!.future;
  }

  void _createMap() {
    final double centerLat = widget.spots.isNotEmpty ? widget.spots.first.lat : 37.5665;
    final double centerLng = widget.spots.isNotEmpty ? widget.spots.first.lng : 126.9780;

    final dynamic latLngConstructor = js_util.getProperty(_maps, 'LatLng');
    final dynamic mapConstructor = js_util.getProperty(_maps, 'Map');

    final dynamic center = js_util.callConstructor(latLngConstructor, <dynamic>[centerLat, centerLng]);

    final dynamic options = js_util.jsify(<String, dynamic>{
      'center': center,
      'level': 4,
    });

    _map = js_util.callConstructor(mapConstructor, <dynamic>[_mapElement, options]);
    _renderMarkers();
  }

  void _renderMarkers() {
    final dynamic markerConstructor = js_util.getProperty(_maps, 'Marker');
    final dynamic latLngConstructor = js_util.getProperty(_maps, 'LatLng');
    final dynamic eventNamespace = js_util.getProperty(_maps, 'event');

    for (final dynamic marker in _markerRefs) {
      js_util.callMethod(marker, 'setMap', <dynamic>[null]);
    }
    _markerRefs.clear();

    for (final ParkingSpot spot in widget.spots) {
      final dynamic position = js_util.callConstructor(latLngConstructor, <dynamic>[spot.lat, spot.lng]);
      final dynamic markerOptions = js_util.jsify(<String, dynamic>{
        'position': position,
      });

      final dynamic marker = js_util.callConstructor(markerConstructor, <dynamic>[markerOptions]);
      js_util.callMethod(marker, 'setMap', <dynamic>[_map]);

      js_util.callMethod(
        eventNamespace,
        'addListener',
        <dynamic>[
          marker,
          'click',
          js_util.allowInterop(() {
            widget.onSpotTap?.call(spot);
          }),
        ],
      );

      _markerRefs.add(marker);
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

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'feature/home/presentation/ui/camera_screen.dart';

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Posture Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: CameraScreen(cameras: cameras),
    );
  }
}

// class CameraScreen extends StatefulWidget {
//   final List<CameraDescription> cameras;

//   const CameraScreen({Key? key, required this.cameras}) : super(key: key);

//   @override
//   _CameraScreenState createState() => _CameraScreenState();
// }

// class _CameraScreenState extends State<CameraScreen> {
//   late CameraController _controller;
//   WebSocketChannel? _channel;
//   bool _isStreaming = false;
//   int _frameCount = 0;
//   double _fps = 0;
//   final Stopwatch _stopwatch = Stopwatch();
//   final String _serverUrl = 'ws://192.168.41.2:5001';
//   Uint8List? _processedFrame;
//   bool _showProcessedFrame = false;
//   bool _isConnected = false;
//   DateTime? _lastFrameTime;
//   final _frameBuffer = <Uint8List>[];
//   bool _isProcessingFrame = false;
//   late FlutterTts _flutterTts;
//   String _lastFeedback = '';
//   DateTime? _lastFeedbackTime;
//   final List<String> _feedbackHistory = [];
//   bool _showFeedbackHistory = false;

//   @override
//   void initState() {
//     super.initState();
//     _initTts();
//     _initCamera();
//   }

//   Future<void> _initTts() async {
//     _flutterTts = FlutterTts();
//     await _flutterTts.setLanguage('en-US');
//     await _flutterTts.setSpeechRate(0.5);
//     await _flutterTts.setVolume(1.0);
//     await _flutterTts.setPitch(1.0);
//   }

//   Future<void> _initCamera() async {
//     try {
//       final frontCamera = widget.cameras.firstWhere(
//         (c) => c.lensDirection == CameraLensDirection.front,
//       );

//       _controller = CameraController(
//         frontCamera,
//         ResolutionPreset.medium,
//         enableAudio: false,
//         imageFormatGroup: ImageFormatGroup.yuv420,
//       );

//       await _controller.initialize();
//       await _controller.lockCaptureOrientation();
//       await _controller.setFocusMode(FocusMode.auto);

//       if (mounted) setState(() {});
//     } catch (e) {
//       debugPrint('Camera initialization error: $e');
//     }
//   }

//   void _handleWebSocketMessage(dynamic message) {
//     if (message is Uint8List) {
//       _frameBuffer.add(message);
//       _processNextFrame();
//     } else if (message is String) {
//       try {
//         final data = json.decode(message);
//         if (data['type'] == 'feedback') {
//           final now = DateTime.now();
//           if (_lastFeedback != data['message'] ||
//               _lastFeedbackTime == null ||
//               now.difference(_lastFeedbackTime!).inSeconds > 5) {
//             _lastFeedback = data['message'];
//             _lastFeedbackTime = now;
//             _feedbackHistory.add(
//                 '${now.hour}:${now.minute}:${now.second} - ${data['message']}');
//             if (_feedbackHistory.length > 5) _feedbackHistory.removeAt(0);

//             _flutterTts.speak(data['message']);

//             if (mounted) {
//               setState(() {});
//               Future.delayed(const Duration(seconds: 5), _clearFeedback);
//             }
//           }
//         }
//       } catch (e) {
//         debugPrint('Error parsing message: $e');
//       }
//     }
//   }

//   Future<void> _toggleStreaming() async {
//     if (_isStreaming) {
//       await _stopStreaming();
//       return;
//     }

//     try {
//       _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
//       _channel!.stream.listen(
//         _handleWebSocketMessage,
//         onError: (error) {
//           debugPrint('WebSocket error: $error');
//           _stopStreaming();
//         },
//         onDone: () {
//           debugPrint('WebSocket connection closed');
//           _stopStreaming();
//         },
//       );

//       _isConnected = true;
//       _stopwatch.start();
//       _frameCount = 0;
//       _lastFrameTime = DateTime.now();

//       setState(() => _isStreaming = true);
//       _startStreamingLoop();
//     } catch (e) {
//       debugPrint('Connection error: $e');
//       setState(() => _isStreaming = false);
//     }
//   }

//   void _processNextFrame() {
//     if (_isProcessingFrame || _frameBuffer.isEmpty) return;

//     _isProcessingFrame = true;
//     final frame = _frameBuffer.removeAt(0);

//     if (mounted) {
//       setState(() {
//         _processedFrame = frame;
//         _isProcessingFrame = false;
//       });
//     }

//     if (_frameBuffer.isNotEmpty) {
//       WidgetsBinding.instance.addPostFrameCallback((_) => _processNextFrame());
//     }
//   }

//   Future<void> _startStreamingLoop() async {
//     while (_isStreaming && mounted && _isConnected) {
//       final startTime = DateTime.now();

//       try {
//         final image = await _controller.takePicture();
//         final bytes = await image.readAsBytes();

//         if (_isStreaming && _channel != null) {
//           _channel!.sink.add(bytes);
//           _frameCount++;

//           // Calculate FPS every 10 frames
//           if (_frameCount % 10 == 0) {
//             final now = DateTime.now();
//             final elapsed =
//                 now.difference(_lastFrameTime!).inMilliseconds / 1000;
//             _fps = 10 / elapsed;
//             _lastFrameTime = now;
//             if (mounted) setState(() {});
//           }
//         }

//         // Adaptive frame rate control
//         final processTime = DateTime.now().difference(startTime).inMilliseconds;
//         final targetDelay = max(33 - processTime, 5);
//         await Future.delayed(Duration(milliseconds: targetDelay));
//       } catch (e) {
//         debugPrint('Frame capture error: $e');
//         await Future.delayed(const Duration(milliseconds: 50));
//       }
//     }
//   }

//   Future<void> _stopStreaming() async {
//     if (_channel != null) {
//       await _channel!.sink.close();
//       _channel = null;
//     }

//     _stopwatch.stop();
//     _frameBuffer.clear();

//     if (mounted) {
//       setState(() {
//         _isStreaming = false;
//         _isConnected = false;
//         _processedFrame = null;
//       });
//     }
//   }

//   void _clearFeedback() {
//     if (_lastFeedback.isNotEmpty) {
//       setState(() {
//         _lastFeedback = '';
//       });
//     }
//   }

//   void _toggleView() {
//     if (_processedFrame != null) {
//       setState(() => _showProcessedFrame = !_showProcessedFrame);
//     }
//   }

//   void _toggleFeedbackHistory() {
//     setState(() => _showFeedbackHistory = !_showFeedbackHistory);
//   }

//   @override
//   void dispose() {
//     _stopStreaming();
//     _controller.dispose();
//     _flutterTts.stop();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Posture Monitor'),
//         actions: [
//           IconButton(
//             icon: Icon(_isStreaming ? Icons.videocam : Icons.videocam_off),
//             onPressed: _toggleStreaming,
//           ),
//           IconButton(
//             icon: const Icon(Icons.history),
//             onPressed: _toggleFeedbackHistory,
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: Stack(
//               children: [
//                 if (!_showProcessedFrame || _processedFrame == null)
//                   CameraPreview(_controller),
//                 if (_processedFrame != null && _showProcessedFrame)
//                   Image.memory(
//                     _processedFrame!,
//                     fit: BoxFit.cover,
//                     gaplessPlayback: true,
//                   ),
//                 if (_lastFeedback.isNotEmpty)
//                   Positioned(
//                     top: 20,
//                     left: 0,
//                     right: 0,
//                     child: AnimatedOpacity(
//                       opacity: _lastFeedback.isNotEmpty ? 1.0 : 0.0,
//                       duration: const Duration(milliseconds: 300),
//                       child: Container(
//                         padding: const EdgeInsets.all(12),
//                         margin: const EdgeInsets.symmetric(horizontal: 20),
//                         decoration: BoxDecoration(
//                           color: Colors.red.withOpacity(0.7),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Text(
//                           _lastFeedback,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                           textAlign: TextAlign.center,
//                         ),
//                       ),
//                     ),
//                   ),

//                 Positioned(
//                   bottom: 10,
//                   left: 10,
//                   child: Container(
//                     padding: const EdgeInsets.all(8),
//                     color: Colors.black54,
//                     child: Text(
//                       'FPS: ${_fps.toStringAsFixed(1)}',
//                       style: const TextStyle(color: Colors.white),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton.icon(
//                   icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
//                   label: Text(_isStreaming ? 'STOP' : 'START'),
//                   onPressed: _toggleStreaming,
//                 ),
//                 if (_processedFrame != null)
//                   ElevatedButton.icon(
//                     icon: Icon(
//                         _showProcessedFrame ? Icons.camera_alt : Icons.image),
//                     label: Text(
//                         _showProcessedFrame ? 'SHOW CAMERA' : 'SHOW PROCESSED'),
//                     onPressed: _toggleView,
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

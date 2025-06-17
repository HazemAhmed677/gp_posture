import 'dart:async';

import 'package:camera_stream/app.dart';
import 'package:camera_stream/core/logic/switch_views_cubit/switch_views_cubit.dart'
    show SwitchViewsCubit;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(BlocProvider(
    create: (context) => SwitchViewsCubit(),
    child: const MyApp(),
  ));
}

//=====================================================

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:flutter_image_compress/flutter_image_compress.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   final cameras = await availableCameras();
//   runApp(MyApp(cameras: cameras));
// }

// class MyApp extends StatelessWidget {
//   final List<CameraDescription> cameras;

//   const MyApp({Key? key, required this.cameras}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Camera Stream',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: CameraScreen(cameras: cameras),
//     );
//   }
// }

// class CameraScreen extends StatefulWidget {
//   final List<CameraDescription> cameras;

//   const CameraScreen({Key? key, required this.cameras}) : super(key: key);

//   @override
//   _CameraScreenState createState() => _CameraScreenState();
// }

// class _CameraScreenState extends State<CameraScreen> {
//   late CameraController _controller;
//   late WebSocketChannel _channel;
//   bool _isStreaming = false;
//   int _frameCount = 0;
//   int _droppedFrames = 0;
//   double _fps = 0;
//   final Stopwatch _stopwatch = Stopwatch();
//   final String _serverUrl =
//       'ws://192.168.1.4:5001/ws'; // Replace with your PC's IP

//   @override
//   void initState() {
//     super.initState();
//     _initCamera();
//   }

//   Future<void> _initCamera() async {
//     _controller = CameraController(
//       widget.cameras
//           .firstWhere((c) => c.lensDirection == CameraLensDirection.back),
//       ResolutionPreset.medium,
//       imageFormatGroup: ImageFormatGroup.yuv420,
//     );

//     try {
//       await _controller.initialize();
//       if (!mounted) return;
//       setState(() {});
//     } catch (e) {
//       debugPrint('Camera error: $e');
//     }
//   }

//   Future<void> _toggleStreaming() async {
//     if (_isStreaming) {
//       _stopStreaming();
//       return;
//     }

//     setState(() {
//       _isStreaming = true;
//       _frameCount = 0;
//       _droppedFrames = 0;
//       _fps = 0;
//       _stopwatch.start();
//     });

//     _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));

//     // Start streaming loop
//     while (_isStreaming && mounted) {
//       try {
//         final startTime = DateTime.now();

//         // Capture frame
//         _controller.setFlashMode(FlashMode.off);
//         final image = await _controller.takePicture();
//         final bytes = await image.readAsBytes();

//         // Compress image
//         final compressedBytes = await FlutterImageCompress.compressWithList(
//           bytes,
//           quality: 50,
//           minHeight: 480,
//           minWidth: 640,
//         );

//         // Send frame if connection is open
//         if (_channel.sink != null) {
//           _channel.sink.add(compressedBytes);
//           _frameCount++;

//           // Calculate FPS every 15 frames
//           if (_frameCount % 15 == 0) {
//             _fps = _frameCount / (_stopwatch.elapsedMilliseconds / 1000);
//           }
//         } else {
//           _droppedFrames++;
//         }

//         // Maintain ~15 FPS (adjust as needed)
//         final processTime = DateTime.now().difference(startTime).inMilliseconds;
//         if (processTime < 33) {
//           // ~15fps
//           await Future.delayed(Duration(milliseconds: 33 - processTime));
//         }
//       } catch (e) {
//         debugPrint('Stream error: $e');
//         _droppedFrames++;
//         await Future.delayed(const Duration(milliseconds: 100));
//       }
//     }
//   }

//   void _stopStreaming() {
//     setState(() {
//       _isStreaming = false;
//       _stopwatch.stop();
//     });
//     _channel.sink.close();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     if (_isStreaming) {
//       _channel.sink.close();
//     }
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Camera Stream')),
//       body: Column(
//         children: [
//           Expanded(
//             child: _controller.value.isInitialized
//                 ? CameraPreview(_controller)
//                 : const Center(child: CircularProgressIndicator()),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               children: [
//                 Text(
//                   'FPS: ${_fps.toStringAsFixed(1)} | '
//                   'Frames: $_frameCount | '
//                   'Dropped: $_droppedFrames',
//                   style: const TextStyle(fontSize: 16),
//                 ),
//                 const SizedBox(height: 20),
//                 ElevatedButton(
//                   onPressed: _toggleStreaming,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: _isStreaming ? Colors.red : Colors.green,
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 40, vertical: 20),
//                   ),
//                   child: Text(
//                     _isStreaming ? 'STOP STREAM' : 'START STREAM',
//                     style: const TextStyle(fontSize: 20),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

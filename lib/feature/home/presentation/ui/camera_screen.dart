import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  late CameraController _controller;
  WebSocketChannel? _channel;
  bool _isStreaming = false;
  int _frameCount = 0;
  double _fps = 0;
  final String _serverUrl = 'ws://192.168.41.2:5001';
  Uint8List? _processedFrame;
  bool _showProcessedFrame = false;
  bool _isConnected = false;
  DateTime? _lastFrameTime;
  final _frameBuffer = <Uint8List>[];
  bool _isProcessingFrame = false;
  late FlutterTts _flutterTts;
  String _lastFeedback = '';
  DateTime? _lastFeedbackTime;
  final List<String> _feedbackHistory = [];
  bool _showFeedbackHistory = false;

  // High-performance frame streaming
  bool _isImageStreamActive = false;
  final Queue<Completer<void>> _frameQueue = Queue<Completer<void>>();
  int _droppedFrames = 0;
  int _sentFrames = 0;
  Timer? _fpsTimer;

  // Performance settings
  int _targetFps = 60;
  final int _maxQueueSize = 3; // Limit queue to prevent memory issues
  bool _useImageStream = true; // Use image stream instead of takePicture
  int _compressionQuality = 70; // JPEG compression quality
  late List<CameraDescription> cameras;

  // Animation controllers
  late AnimationController _pulseAnimationController;
  late AnimationController _feedbackAnimationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _feedbackAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initTts();
    _initCamera();
    _startFpsMonitoring();
  }

  void _initAnimations() {
    _pulseAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _feedbackAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
          parent: _pulseAnimationController, curve: Curves.easeInOut),
    );

    _feedbackAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _feedbackAnimationController, curve: Curves.elasticOut),
    );

    _pulseAnimationController.repeat(reverse: true);
  }

  void _startFpsMonitoring() {
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isStreaming && mounted) {
        setState(() {
          _fps = _sentFrames.toDouble();
          _sentFrames = 0; // Reset counter
        });
      }
    });
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _initCamera() async {
    try {
      cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller.initialize();
      await _controller.lockCaptureOrientation();
      await _controller.setFocusMode(FocusMode.locked);
      await _controller.setExposureMode(ExposureMode.locked);

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    if (message is Uint8List) {
      if (_frameBuffer.length < _maxQueueSize) {
        _frameBuffer.add(message);
        _processNextFrame();
      }
    } else if (message is String) {
      try {
        final data = json.decode(message);
        if (data['type'] == 'feedback') {
          final now = DateTime.now();
          if (_lastFeedback != data['message'] ||
              _lastFeedbackTime == null ||
              now.difference(_lastFeedbackTime!).inSeconds > 5) {
            _lastFeedback = data['message'];
            _lastFeedbackTime = now;
            _feedbackHistory.add(
                '${now.hour}:${now.minute}:${now.second} - ${data['message']}');
            if (_feedbackHistory.length > 5) _feedbackHistory.removeAt(0);

            _flutterTts.speak(data['message']);
            _feedbackAnimationController.forward();

            if (mounted) {
              setState(() {});
              Future.delayed(const Duration(seconds: 5), _clearFeedback);
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing message: $e');
      }
    }
  }

  Future<void> _toggleStreaming() async {
    if (_isStreaming) {
      await _stopStreaming();
      return;
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      _channel!.stream.listen(
        _handleWebSocketMessage,
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _stopStreaming();
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _stopStreaming();
        },
      );

      _isConnected = true;
      _frameCount = 0;
      _sentFrames = 0;
      _droppedFrames = 0;
      _lastFrameTime = DateTime.now();

      setState(() => _isStreaming = true);

      if (_useImageStream) {
        await _startImageStream();
      } else {
        _startLegacyStreamingLoop();
      }
    } catch (e) {
      debugPrint('Connection error: $e');
      setState(() => _isStreaming = false);
    }
  }

  // High-performance image stream approach
  Future<void> _startImageStream() async {
    if (_isImageStreamActive) return;

    _isImageStreamActive = true;

    try {
      await _controller.startImageStream((CameraImage image) {
        if (!_isStreaming || !_isConnected || _channel == null) return;

        // Skip frame if queue is full (prevents memory buildup)
        if (_frameQueue.length >= _maxQueueSize) {
          _droppedFrames++;
          return;
        }

        final completer = Completer<void>();
        _frameQueue.add(completer);

        // Process frame asynchronously
        _processImageFrame(image).then((_) {
          _frameQueue.remove(completer);
          completer.complete();
        }).catchError((error) {
          _frameQueue.remove(completer);
          completer.complete();
          debugPrint('Frame processing error: $error');
        });
      });
    } catch (e) {
      debugPrint('Image stream error: $e');
      _isImageStreamActive = false;
    }
  }

  Future<void> _processImageFrame(CameraImage image) async {
    try {
      // Use a more efficient approach for high FPS
      Uint8List? bytes;

      if (image.format.group == ImageFormatGroup.jpeg) {
        // Direct JPEG bytes - fastest method
        bytes = Uint8List.fromList(image.planes[0].bytes);
      } else if (image.format.group == ImageFormatGroup.nv21 ||
          image.format.group == ImageFormatGroup.yuv420) {
        // For YUV formats, use a simplified conversion or fallback to takePicture
        bytes = await _convertYuvToJpegSimple(image);
      }

      if (_isStreaming && _channel != null && bytes != null) {
        _channel!.sink.add(bytes);
        _sentFrames++;
        _frameCount++;
      }
    } catch (e) {
      debugPrint('Image conversion error: $e');
    }
  }

  Future<Uint8List?> _convertYuvToJpegSimple(CameraImage image) async {
    try {
      // Fallback: Use takePicture for YUV formats (slower but reliable)
      if (_isStreaming && mounted) {
        final XFile pictureFile = await _controller.takePicture();
        return await pictureFile.readAsBytes();
      }
    } catch (e) {
      debugPrint('YUV conversion fallback error: $e');
    }
    return null;
  }

  void _processNextFrame() {
    if (_isProcessingFrame || _frameBuffer.isEmpty) return;

    _isProcessingFrame = true;
    final frame = _frameBuffer.removeAt(0);

    if (mounted) {
      setState(() {
        _processedFrame = frame;
        _isProcessingFrame = false;
      });
    }

    if (_frameBuffer.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _processNextFrame());
    }
  }

  // Legacy streaming approach (fallback)
  Future<void> _startLegacyStreamingLoop() async {
    final targetDelay = (1000 / _targetFps).round();

    while (_isStreaming && mounted && _isConnected) {
      final startTime = DateTime.now();

      try {
        final image = await _controller.takePicture();
        final bytes = await image.readAsBytes();

        if (_isStreaming && _channel != null) {
          _channel!.sink.add(bytes);
          _sentFrames++;
          _frameCount++;
        }

        final processTime = DateTime.now().difference(startTime).inMilliseconds;
        final remainingTime = targetDelay - processTime;

        if (remainingTime > 0) {
          await Future.delayed(Duration(milliseconds: remainingTime));
        }
      } catch (e) {
        debugPrint('Frame capture error: $e');
        await Future.delayed(const Duration(milliseconds: 5));
      }
    }
  }

  Future<void> _stopStreaming() async {
    if (_isImageStreamActive) {
      try {
        await _controller.stopImageStream();
        _isImageStreamActive = false;
      } catch (e) {
        debugPrint('Error stopping image stream: $e');
      }
    }

    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }

    _frameBuffer.clear();
    _frameQueue.clear();

    if (mounted) {
      setState(() {
        _isStreaming = false;
        _isConnected = false;
        _processedFrame = null;
      });
    }
  }

  void _clearFeedback() {
    if (_lastFeedback.isNotEmpty) {
      setState(() {
        _lastFeedback = '';
      });
      _feedbackAnimationController.reverse();
    }
  }

  void _toggleView() {
    if (_processedFrame != null) {
      setState(() => _showProcessedFrame = !_showProcessedFrame);
    }
  }

  void _toggleFeedbackHistory() {
    setState(() => _showFeedbackHistory = !_showFeedbackHistory);
  }

  void _adjustTargetFps(int newFps) {
    setState(() {
      _targetFps = newFps.clamp(10, 120);
    });
  }

  void _toggleStreamingMethod() {
    setState(() {
      _useImageStream = !_useImageStream;
    });
  }

  void _adjustCompressionQuality(int quality) {
    setState(() {
      _compressionQuality = quality.clamp(10, 100);
    });
  }

  Widget _buildStatusIndicator() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isStreaming ? _pulseAnimation.value : 1.0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isConnected
                  ? Colors.green
                  : _isStreaming
                      ? Colors.orange
                      : Colors.red,
              boxShadow: [
                BoxShadow(
                  color: (_isConnected
                          ? Colors.green
                          : _isStreaming
                              ? Colors.orange
                              : Colors.red)
                      .withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildStatusIndicator(),
              const SizedBox(width: 8),
              Text(
                _isConnected ? 'Connected' : 'Disconnected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatRow('FPS', _fps.toStringAsFixed(1), Icons.speed),
          _buildStatRow('Target', '$_targetFps FPS', Icons.image_rounded),
          _buildStatRow('Method', _useImageStream ? "Stream" : "Capture",
              Icons.camera_alt),
          _buildStatRow('Queue', '${_frameQueue.length}', Icons.queue),
          if (_droppedFrames > 0)
            _buildStatRow(
                'Dropped', '$_droppedFrames', Icons.warning, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon,
      [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: color ?? Colors.white70,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: color ?? Colors.white70,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackOverlay() {
    if (_lastFeedback.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 80,
      left: 20,
      right: 20,
      child: ScaleTransition(
        scale: _feedbackAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.withOpacity(0.9),
                Colors.deepOrange.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _lastFeedback,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isPrimary = false,
    Color? color,
  }) {
    return Expanded(
      child: Container(
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                color ?? (isPrimary ? Colors.blue : Colors.grey[800]),
            foregroundColor: Colors.white,
            elevation: isPrimary ? 8 : 4,
            shadowColor: (color ?? Colors.blue).withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseAnimationController.dispose();
    _feedbackAnimationController.dispose();
    _fpsTimer?.cancel();
    _stopStreaming();
    _controller.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Posture Monitor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isStreaming ? Icons.videocam : Icons.videocam_off,
              color: _isStreaming ? Colors.green : Colors.grey,
            ),
            onPressed: _toggleStreaming,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _toggleFeedbackHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    if (!_showProcessedFrame || _processedFrame == null)
                      CameraPreview(_controller),
                    if (_processedFrame != null && _showProcessedFrame)
                      Image.memory(
                        _processedFrame!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        gaplessPlayback: true,
                      ),
                    _buildFeedbackOverlay(),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: _buildStatsCard(),
                    ),
                    if (_showFeedbackHistory)
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Container(
                          width: 250,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Feedback History',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._feedbackHistory.map((feedback) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      feedback,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                _buildControlButton(
                  label: _isStreaming ? 'STOP' : 'START',
                  icon: _isStreaming ? Icons.stop : Icons.play_arrow,
                  onPressed: _toggleStreaming,
                  isPrimary: true,
                  color: _isStreaming ? Colors.red : Colors.green,
                ),
                if (_processedFrame != null)
                  _buildControlButton(
                    label: _showProcessedFrame ? 'CAMERA' : 'AI VIEW',
                    icon: _showProcessedFrame
                        ? Icons.camera_alt
                        : Icons.smart_toy,
                    onPressed: _toggleView,
                    color: Colors.purple,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

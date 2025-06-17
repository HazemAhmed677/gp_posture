import 'package:camera/camera.dart';
import 'package:camera_stream/core/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _floatingController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _floatingAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  Future<void> _navigateToPostureCorrection() async {
    // Navigate to posture correction view
    // Navigator.pushNamed(context, '/posture-correction');
    List<CameraDescription> cameras = await availableCameras();
    context.push(Routes.camera, extra: cameras);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF312e81), // indigo-900
            Color(0xFF581c87), // purple-900
            Color(0xFF9d174d), // pink-800
          ],
        ),
      ),
      child: Stack(
        children: [
          // Animated background elements
          _buildAnimatedBackground(),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App title
                  _buildAppTitle(),

                  const SizedBox(height: 48),

                  // Main CTA button
                  _buildMainButton(),

                  const SizedBox(height: 64),

                  // Feature highlights
                  _buildFeatureCards(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Floating circle 1
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Positioned(
              top: -100,
              right: -100,
              child: Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
            );
          },
        ),

        // Floating circle 2
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Positioned(
              bottom: -120,
              left: -120,
              child: Transform.scale(
                scale: _pulseAnimation.value * 0.8,
                child: Container(
                  width: 384,
                  height: 384,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF8b5cf6).withOpacity(0.2),
                  ),
                ),
              ),
            );
          },
        ),

        // Floating circle 3
        AnimatedBuilder(
          animation: _floatingAnimation,
          builder: (context, child) {
            return Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              left: MediaQuery.of(context).size.width * 0.2,
              child: Transform.translate(
                offset: Offset(0, _floatingAnimation.value),
                child: Container(
                  width: 256,
                  height: 256,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFec4899).withOpacity(0.1),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAppTitle() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.1,
            ),
            children: [
              const TextSpan(text: 'Posture\n'),
              TextSpan(
                text: 'Perfect',
                style: TextStyle(
                  background: Paint()
                    ..shader = const LinearGradient(
                      colors: [
                        Color(0xFFf472b6), // pink-400
                        Color(0xFFc084fc), // purple-400
                      ],
                    ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Transform your posture, transform your life.\nAI-powered correction for a healthier you.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFFd1d5db), // gray-300
            fontWeight: FontWeight.w300,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMainButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8b5cf6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToPostureCorrection,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF9333ea), // purple-600
                  Color(0xFFdb2777), // pink-600
                ],
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flash_on,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Start Posture Correction',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCards() {
    return Row(
      children: [
        Expanded(
          child: _buildFeatureCard(
            icon: Icons.visibility,
            title: 'AI Detection',
            description:
                'Real-time posture analysis using advanced computer vision',
            gradient: const [
              Color(0xFF60a5fa),
              Color(0xFF8b5cf6)
            ], // blue-400 to purple-500
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFeatureCard(
            icon: Icons.bar_chart,
            title: 'Progress Tracking',
            description: 'Monitor your improvement with detailed analytics',
            gradient: const [
              Color(0xFF4ade80),
              Color(0xFF3b82f6)
            ], // green-400 to blue-500
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFeatureCard(
            icon: Icons.phone_android,
            title: 'Smart Alerts',
            description: 'Gentle reminders to maintain proper posture',
            gradient: const [
              Color(0xFFf472b6),
              Color(0xFFef4444)
            ], // pink-400 to red-500
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(colors: gradient),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFd1d5db).withOpacity(0.8),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

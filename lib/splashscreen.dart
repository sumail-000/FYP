import 'package:flutter/material.dart';
import 'dart:math';
import 'auth/auth_service.dart';
import 'services/activity_points_service.dart';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

class WaveScreen extends StatefulWidget {
  @override
  _WaveScreenState createState() => _WaveScreenState();
}

class _WaveScreenState extends State<WaveScreen> with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _bgColorController;
  late Animation<Color?> _bgColorAnimation;

  // Initialize with empty lists to prevent null errors
  List<AnimationController> _riseControllers = [];
  List<Animation<double>> _riseAnimations = [];

  final int waveCount = 4;
  final double triggerThreshold = 0.15;
  double screenHeight = 0;
  bool isInitialized = false;

  final AuthService _authService = AuthService();
  final ActivityPointsService _activityPointsService = ActivityPointsService();

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _bgColorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _bgColorAnimation = ColorTween(
      begin: Colors.white,
      end: Colors.orange,
    ).animate(_bgColorController);

    // Delay the initialization to ensure the context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
      screenHeight = MediaQuery.of(context).size.height;
      _initWaves();
        _checkAuthAndNavigate();
      }
    });
  }

  void _initWaves() {
    // Create controllers for each wave
    _riseControllers = List.generate(waveCount, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 2500 + (i * 300)),
      );
    });

    // Create animations for each wave
    _riseAnimations = List.generate(waveCount, (i) {
      return Tween<double>(begin: 0, end: screenHeight).animate(
        CurvedAnimation(parent: _riseControllers[i], curve: Curves.easeOut),
      );
    });

    // Start the first wave animation
    _riseControllers[0].forward();

    // Set up listeners to trigger subsequent waves
    for (int i = 0; i < waveCount - 1; i++) {
      _riseAnimations[i].addListener(() {
        if (_riseAnimations[i].value >= screenHeight * 0.1 &&
            !_riseControllers[i + 1].isAnimating &&
            _riseAnimations[i + 1].value == 0) {
          _riseControllers[i + 1].forward();
        }
      });
    }

    // Listen for the last wave to complete
    _riseAnimations.last.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _bgColorController.forward();
      }
    });

    // Mark as initialized
    setState(() {
      isInitialized = true;
    });
  }

  // Check authentication state and navigate accordingly
  Future<void> _checkAuthAndNavigate() async {
    if (_authService.currentUser != null) {
      // Award daily login streak points
      await _checkDailyLoginStreak();

      // Check if profile is complete before navigating
      await _authService.isProfileComplete();

      // User is already logged in, navigate to home after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      });
    } else {
      // Navigate to IntroductionScreen after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/intro');
        }
      });
    }
  }

  // Check and award daily login streak points
  Future<void> _checkDailyLoginStreak() async {
    try {
      final result =
          await _activityPointsService.checkAndAwardDailyLoginStreak();

      if (result['success']) {
        // Store streak information in a static variable that can be accessed by the dashboard
        if (result['streakIncreased'] && result['currentStreak'] > 1) {
          // Store streak data for dashboard to use
          await _storeStreakData(
            result['currentStreak'],
            result['pointsAwarded'],
          );
        }

        developer.log(
          'Daily login streak processed: Streak=${result['currentStreak']}, '
          'Points awarded=${result['pointsAwarded']}',
          name: 'WaveScreen',
        );
      } else {
        developer.log(
          'Failed to process daily login: ${result['message']}',
          name: 'WaveScreen',
        );
      }
    } catch (e) {
      developer.log(
        'Error checking daily login streak: $e',
        name: 'WaveScreen',
      );
    }
  }

  // Store streak data in shared preferences or other storage
  Future<void> _storeStreakData(int currentStreak, int pointsAwarded) async {
    try {
      // Store in Firestore for the current user to ensure persistence
      final user = _authService.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'lastStreakCheck': {
                'timestamp': FieldValue.serverTimestamp(),
                'currentStreak': currentStreak,
                'pointsAwarded': pointsAwarded,
                'shown': false,
              },
            });

        developer.log(
          'Stored streak data for dashboard to display',
          name: 'WaveScreen',
        );
      }
    } catch (e) {
      developer.log('Error storing streak data: $e', name: 'WaveScreen');
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _bgColorController.dispose();

    // Dispose all rise controllers
    for (var controller in _riseControllers) {
      controller.dispose();
    }

    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: AnimatedBuilder(
        animation: _waveController,
      builder: (context, _) {
          // Provide a safe fallback when animations aren't ready
          if (!isInitialized || _riseAnimations.isEmpty) {
        return Container(
              color: Colors.white,
              child: null, // No logo in initial state
            );
          }

          bool allWavesCompleted = _riseAnimations.every(
            (anim) => anim.value >= screenHeight,
          );

          // Calculate logo opacity based on last wave position
          double logoOpacity = 0.0;

          if (_riseAnimations.isNotEmpty) {
            // Get last wave position (the orange wave)
            double lastWavePosition = _riseAnimations[waveCount - 1].value;

            // Show logo when last wave reaches 40% of screen height
            if (lastWavePosition > screenHeight * 0.4) {
              // Start fading in faster
              logoOpacity =
                  ((lastWavePosition / screenHeight) - 0.4) *
                  3; // Will be between 0 and 1 faster

              // Make sure we don't exceed 1.0
              logoOpacity = logoOpacity.clamp(0.0, 1.0);

              // If we're at full height, set opacity to 1
              if (allWavesCompleted) {
                logoOpacity = 1.0;
              }
            }
          }

          return Stack(
            children: [
              // Background
              Container(color: _bgColorAnimation.value),

              // Waves layer
              Stack(
            children: [
              if (!allWavesCompleted)
                for (int i = 0; i < waveCount; i++)
                  CustomPaint(
                    painter: WavePainter(
                      animationValue: _waveController.value,
                      verticalOffset: _riseAnimations[i].value,
                      waveColor: _getWaveColor(i),
                      frequency: 1.8 - (i * 0.2),
                      amplitude: 30 + (i * 5),
                          speedFactor: 4.0 + i,
                    ),
                    child: Container(),
                  ),
            ],
          ),

              // Logo on top with proper z-index and faster fade-in
              Center(
                child: AnimatedOpacity(
                  opacity: logoOpacity,
                  duration: Duration(milliseconds: 300),
                  child: _buildLogoContainer(),
                ),
              ),
            ],
        );
      },
    ),
  );
}

  // Helper method to build the circular logo container
  Widget _buildLogoContainer() {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 15, spreadRadius: 2),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Image.asset('assets/Logo.png', fit: BoxFit.contain),
      ),
    );
  }

  Color _getWaveColor(int index) {
    switch (index) {
      case 0:
        return Colors.deepPurple;
      case 1:
        return Colors.grey;
      case 2:
        return Colors.blueGrey;
      case 3:
        return Colors.orange;
      default:
        return Colors.black;
    }
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;
  final double verticalOffset;
  final Color waveColor;
  final double frequency;
  final double amplitude;
  final double speedFactor;

  WavePainter({
    required this.animationValue,
    required this.verticalOffset,
    required this.waveColor,
    required this.frequency,
    required this.amplitude,
    required this.speedFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = waveColor;
    final Path path = Path();

    final double waveLength = size.width;
    final double baseHeight = size.height - verticalOffset;
    final double time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final double speed = -animationValue * speedFactor * pi;

    path.moveTo(0, size.height);

    for (double x = 0; x <= waveLength; x++) {
      double dynamicAmplitude =
          amplitude + sin((x / waveLength * pi) + time) * 10;
      double y =
          sin((x / waveLength * frequency * pi) + speed + time) *
              dynamicAmplitude +
          (baseHeight - 20);

      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) =>
      animationValue != oldDelegate.animationValue ||
          verticalOffset != oldDelegate.verticalOffset ||
          waveColor != oldDelegate.waveColor ||
          frequency != oldDelegate.frequency ||
          amplitude != oldDelegate.amplitude;
}

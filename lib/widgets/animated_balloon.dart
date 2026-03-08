import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';

class AnimatedBalloonWidget extends StatefulWidget {
  const AnimatedBalloonWidget({super.key});

  @override
  State<AnimatedBalloonWidget> createState() => _AnimatedBalloonWidgetState();
}

class _AnimatedBalloonWidgetState extends State<AnimatedBalloonWidget>
    with TickerProviderStateMixin {

  // ORIGINAL - Controllers for shared background animations
  late AnimationController _controllerRotation;
  late Animation<double> _animationRotation;
  late AnimationController _controllerPulse;
  late Animation<double> _animationPulse;
  late AnimationController _controllerClouds;
  late Animation<double> _animationClouds;

  // ENHANCEMENT 8: Sound Effects - Note: Changed to one-shot players for reliable web playback
  bool _audioUnlocked = false; 

  // ENHANCEMENT 10: Multiple Balloons - List to manage individual balloon instances
  final List<BalloonInstance> _balloons = [];
  
  // NEW: Dynamic Clouds
  final List<CloudData> _clouds = [];
  
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // ENHANCEMENT 3: Rotation
    _controllerRotation = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _animationRotation = Tween(begin: -0.05, end: 0.05).animate(CurvedAnimation(
      parent: _controllerRotation,
      curve: Curves.easeInOut,
    ));

    // ENHANCEMENT 4: Pulse
    _controllerPulse = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _animationPulse = Tween(begin: 0.97, end: 1.03).animate(CurvedAnimation(
      parent: _controllerPulse,
      curve: Curves.easeInOut,
    ));

    // ENHANCEMENT 5: Background clouds
    _controllerClouds = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat();
    _animationClouds = Tween(begin: 0.0, end: 1.0).animate(_controllerClouds);

    _initializeBalloons();
    _initializeClouds();
  }

  void _initializeBalloons() {
    for (int i = 0; i < 6; i++) {
      final instance = BalloonInstance(
        controller: AnimationController(vsync: this),
        color: Colors.white,
        baseOffset: Offset.zero,
        driftDirection: 0,
      );
      _balloons.add(instance);
      
      Future.delayed(Duration(milliseconds: i * 2000), () {
        if (mounted) _spawnBalloon(instance);
      });
    }
  }

  void _spawnBalloon(BalloonInstance instance) {
    if (!mounted) return;

    setState(() {
      instance.isBurst = false;
      instance.isFloatingAway = false;
      instance.controller.reset();
    });

    instance.controller.duration = Duration(seconds: 6 + _random.nextInt(4));

    double screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      instance.color = Colors.primaries[_random.nextInt(Colors.primaries.length)];
      instance.baseOffset = Offset(_random.nextDouble() * screenWidth - screenWidth / 2, 0);
      instance.driftDirection = _random.nextDouble() * 2.0 - 1.0;
      instance.dragOffset = Offset.zero;
      instance.userScale = 1.0;
    });

    instance.controller.forward().then((_) {
      if (mounted && !instance.isBurst) {
        setState(() => instance.isFloatingAway = true);
        instance.controller.duration = const Duration(seconds: 5);
        instance.controller.reverse(from: 1.0).then((_) {
           if (mounted) _spawnBalloon(instance);
        });
      }
    });
  }

  void _initializeClouds() {
    for (int i = 0; i < 8; i++) {
      _clouds.add(CloudData(
        top: _random.nextDouble() * 300,
        relativeSpeed: 0.5 + _random.nextDouble(),
        size: 40 + _random.nextDouble() * 60,
        horizontalOffset: _random.nextDouble() * 1000,
      ));
    }
  }

  void _playPopSound() async {
    // ENHANCEMENT 8: Sound Effects - Note: Creating a fresh player for each pop
    // to guarantee playback on web and allow overlapping sounds.
    try {
      final player = AudioPlayer();
      // Explicitly resume context for Web
      await AudioPlayer.global.setAudioContext(const AudioContext());
      await player.play(AssetSource('sounds/pop.mp3'));
      
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
    } catch (e) {
      debugPrint("Sound error (pop): $e");
    }
  }

  @override
  void dispose() {
    _controllerRotation.dispose(); 
    _controllerPulse.dispose();    
    _controllerClouds.dispose();   
    for (var b in _balloons) {
      b.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    double balloonHeight = screenSize.height / 2;
    double balloonWidth  = screenSize.height / 3;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (!_audioUnlocked) {
          _audioUnlocked = true;
          debugPrint("Unlocking Web Audio context...");
          _playPopSound(); // Play once to unlock context
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _animationRotation,
          _animationPulse,
          _animationClouds,
          ..._balloons.map((b) => b.controller),
        ]),
        builder: (context, child) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFB3E5FC), Color(0xFFE1F5FE)],
              ),
            ),
            child: SizedBox(
              height: screenSize.height,
              width: screenSize.width,
              child: Stack(
                children: [
                  ..._clouds.map((cloud) {
                    double left = ((_animationClouds.value * screenSize.width * 2 * cloud.relativeSpeed) + cloud.horizontalOffset) % (screenSize.width + 200) - 100;
                    return Positioned(
                      top: cloud.top,
                      left: left,
                      child: Opacity(
                        opacity: 0.6,
                        child: Icon(Icons.cloud, size: cloud.size, color: Colors.white),
                      ),
                    );
                  }).toList(),

                  ..._balloons.expand((instance) => [
                    _buildBalloonShadow(context, instance, balloonHeight, balloonWidth, screenSize),
                    _buildBalloon(context, instance, balloonHeight, balloonWidth, screenSize),
                  ]).toList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalloonShadow(BuildContext context, BalloonInstance instance, double height, double width, Size screenSize) {
    if (instance.isBurst || (instance.controller.value == 0 && !instance.controller.isAnimating)) return const SizedBox.shrink();

    double t = instance.controller.value;
    double balloonBottomLocation = screenSize.height - height;
    
    double top;
    double left = (screenSize.width / 2 - width / 2) + instance.baseOffset.dx + instance.dragOffset.dx + 18;

    if (!instance.isFloatingAway) {
      top = (balloonBottomLocation + (0 - balloonBottomLocation) * Curves.bounceOut.transform(t)) + instance.dragOffset.dy + 18;
    } else {
      top = (0 + (-screenSize.height - 0) * (1 - t)) + instance.dragOffset.dy + 18;
      left += (1 - t) * instance.driftDirection * 200;
    }

    double shadowOpacity = (1.0 - (top / (balloonBottomLocation == 0 ? 1 : balloonBottomLocation))).clamp(0.1, 0.5);

    return Positioned(
      top: top,
      left: left,
      child: Transform.scale(
        scale: _animationPulse.value * instance.userScale,
        child: Transform.rotate(
          angle: _animationRotation.value,
          child: Opacity(
            opacity: shadowOpacity * (instance.isFloatingAway ? (1 - t) : 1.0),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcATop),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Image.asset(
                  'assets/images/BeginningGoogleFlutter-Balloon.png',
                  height: height,
                  width: width,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalloon(BuildContext context, BalloonInstance instance, double height, double width, Size screenSize) {
    if (instance.isBurst || (instance.controller.value == 0 && !instance.controller.isAnimating)) return const SizedBox.shrink();

    double t = instance.controller.value;
    double balloonBottomLocation = screenSize.height - height;
    
    double top;
    double left = (screenSize.width / 2 - width / 2) + instance.baseOffset.dx + instance.dragOffset.dx;

    if (!instance.isFloatingAway) {
      top = (balloonBottomLocation + (0 - balloonBottomLocation) * Curves.bounceOut.transform(t)) + instance.dragOffset.dy;
    } else {
      top = (0 + (-screenSize.height - 0) * (1 - t)) + instance.dragOffset.dy;
      left += (1 - t) * instance.driftDirection * 200;
    }

    return Positioned(
      top: top,
      left: left,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            instance.dragOffset += details.delta;
          });
        },
        onTap: () {
          // ENHANCEMENT 8: Sound Effects - Trigger pop sound
          _playPopSound();
          setState(() => instance.isBurst = true);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && instance.isBurst) _spawnBalloon(instance);
          });
        },
        child: Transform.scale(
          scale: _animationPulse.value * instance.userScale,
          child: Transform.rotate(
            angle: _animationRotation.value,
            child: Opacity(
              opacity: instance.isFloatingAway ? (1 - t) : 1.0,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return RadialGradient(
                    center: const Alignment(-0.4, -0.6),
                    radius: 1.2,
                    colors: [
                      Colors.white,
                      instance.color.withOpacity(0.5),
                      instance.color,
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcATop,
                child: Image.asset(
                  'assets/images/BeginningGoogleFlutter-Balloon.png',
                  height: height,
                  width: width,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => _fallbackBalloon(height, width, instance.color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackBalloon(double height, double width, Color color) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.6),
          radius: 1.2,
          colors: [Colors.white, color.withOpacity(0.5), color],
          stops: const [0.0, 0.35, 1.0],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.error, color: Colors.white),
    );
  }
}

class BalloonInstance {
  final AnimationController controller;
  Color color;
  Offset baseOffset;
  double driftDirection;
  Offset dragOffset = Offset.zero;
  double userScale = 1.0;
  bool isBurst = false;
  bool isFloatingAway = false;

  BalloonInstance({
    required this.controller,
    required this.color,
    required this.baseOffset,
    required this.driftDirection,
  });
}

class CloudData {
  final double top;
  final double relativeSpeed;
  final double size;
  final double horizontalOffset;

  CloudData({
    required this.top,
    required this.relativeSpeed,
    required this.size,
    required this.horizontalOffset,
  });
}

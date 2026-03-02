import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'dart:math';

void main() {
  runApp(const DiceDreamApp());
}

class DiceDreamApp extends StatelessWidget {
  const DiceDreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dice Dream',
      theme: ThemeData(
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const DiceScreen(),
    );
  }
}

class DiceScreen extends StatefulWidget {
  const DiceScreen({super.key});

  @override
  State<DiceScreen> createState() => _DiceScreenState();
}

class _DiceScreenState extends State<DiceScreen>
    with SingleTickerProviderStateMixin {
  late int _currentDice;
  late int _nextDice;
  late AnimationController _animationController;
  late Animation<double> _liquidAnimation;
  late AudioPlayer _audioPlayer;
  bool _isRolling = false;

  // Settings
  String _animationSpeed = 'Normal'; // Turtle, Normal, Cheetah
  int _diceMaxNumber = 6; // 4, 6, 8, 10, 12
  bool _vibrationEnabled = true;
  bool _soundEnabled = true;
  bool _showCount = true;

  final List<Color> diceColors = [
    Colors.red.shade600,
    Colors.blue.shade600,
    Colors.green.shade600,
    Colors.orange.shade600,
    Colors.purple.shade600,
    Colors.teal.shade600,
    Colors.pink.shade600,
    Colors.indigo.shade600,
    Colors.amber.shade600,
    Colors.cyan.shade600,
    Colors.lime.shade600,
    Colors.deepOrange.shade600,
  ];

  final List<String> diceLabels = [
    'One', 'Two', 'Three', 'Four', 'Five', 'Six',
    'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve'
  ];

  // Get animation duration based on speed setting
  Duration _getAnimationDuration() {
    switch (_animationSpeed) {
      case 'None':
        return Duration.zero;
      case 'Slow':
        return const Duration(milliseconds: 700);
      case 'Normal':
        return const Duration(milliseconds: 500);
      case 'Fast':
        return const Duration(milliseconds: 300);
      default:
        return const Duration(milliseconds: 500);
    }
  }

  @override
  void initState() {
    super.initState();
    _currentDice = 1;
    _nextDice = 2;
    _audioPlayer = AudioPlayer();
    // Ensure audio plays only once
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _animationController = AnimationController(
      duration: _getAnimationDuration(),
      vsync: this,
    );
    
    // easeOutBack makes the animation overshoot and bounce back
    _liquidAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack, 
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _rollDice() {
    if (_isRolling) return;

    _isRolling = true;
    
    // Play dice roll sound once if enabled
    if (_soundEnabled) {
      String audioFile = _animationSpeed == 'None' 
          ? 'audio/dice_sound.mp3' 
          : 'audio/dice_roll.mp3';
      _audioPlayer.play(
        AssetSource(audioFile),
      ).catchError((e) {
        print('Error playing audio: $e');
      });
    }

    // Vibrate if enabled
    if (_vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }

    // If animation is disabled, show result immediately
    if (_animationSpeed == 'None') {
      int finalNumber;
      do {
        finalNumber = Random().nextInt(_diceMaxNumber) + 1;
      } while (finalNumber == _currentDice);

      setState(() {
        _currentDice = finalNumber;
        _isRolling = false;
      });
      _animationController.value = 0.0;
      return;
    }

    // Generate random iterations (3, 4, or 5 intermediate rolls)
    int randomIterations = Random().nextInt(3) + 3; // Random between 3, 4, 5
    List<int> sequence = [_currentDice];
    for (int i = 0; i < randomIterations; i++) {
      int nextNumber;
      do {
        nextNumber = Random().nextInt(_diceMaxNumber) + 1;
      } while (nextNumber == sequence.last);
      sequence.add(nextNumber);
    }
    
    // Add final random number
    int finalNumber;
    do {
      finalNumber = Random().nextInt(_diceMaxNumber) + 1;
    } while (finalNumber == sequence.last);

    // Cycle through intermediate numbers
    _animateSequence(sequence, 1, finalNumber);
  }

  void _animateSequence(List<int> sequence, int index, int finalNumber) {
    if (!mounted) return;
    
    setState(() {
      _nextDice = index < sequence.length ? sequence[index] : finalNumber;
    });
    
    _animationController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      
      setState(() {
        _currentDice = _nextDice;
      });
      
      if (index < sequence.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _animateSequence(sequence, index + 1, finalNumber);
          }
        });
      } else {
        _isRolling = false;
      }
    });
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animation Speed
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Animation Speed',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButton<String>(
                            isExpanded: true,
                            value: _animationSpeed,
                            items: ['None', 'Slow (Turtle)', 'Normal (Human)', 'Fast (Cheetah)']
                                .map((value) => DropdownMenuItem(
                                      value: value.split(' ')[0],
                                      child: Text(value),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                _animationSpeed = value!;
                                // Update animation duration
                                _animationController.duration = _getAnimationDuration();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Dice Max Number
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dice Max Number',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButton<int>(
                            isExpanded: true,
                            value: _diceMaxNumber,
                            items: [4, 6, 8, 10, 12]
                                .map((value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value.toString()),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                _diceMaxNumber = value!;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Vibration
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Vibration',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Switch(
                            value: _vibrationEnabled,
                            onChanged: (value) {
                              setDialogState(() {
                                _vibrationEnabled = value;
                              });
                            },
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Sound
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sound',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Switch(
                            value: _soundEnabled,
                            onChanged: (value) {
                              setDialogState(() {
                                _soundEnabled = value;
                              });
                            },
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // Show Count
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Show count',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Switch(
                            value: _showCount,
                            onChanged: (value) {
                              setDialogState(() {
                                _showCount = value;
                              });
                              setState(() {});
                            },
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onTap: _isRolling ? null : _rollDice,
            child: AnimatedBuilder(
              animation: _liquidAnimation,
              builder: (context, child) {
                return Container(
                  width: screenWidth,
                  height: screenHeight,
                  color: Colors.black,
                  child: Stack(
                    children: [
                      // 1. Current dice - Fades back and slides left gently
                      Container(
                        width: screenWidth,
                        height: screenHeight,
                        color: diceColors[_currentDice - 1],
                        child: Center(
                          child: Transform.translate(
                            // Sinks to the left as the liquid covers it
                            offset: Offset(-80 * _liquidAnimation.value, 0),
                            child: Transform.scale(
                              // Shrinks slightly
                          scale: 1.0 - (0.1 * _liquidAnimation.value),
                          child: DiceDots(
                            number: _currentDice,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // 2. Next dice - Washes over using the LiquidClipper
                  ClipPath(
                    clipper: LiquidClipper(progress: _liquidAnimation.value),
                    child: Container(
                      width: screenWidth,
                      height: screenHeight,
                      color: diceColors[_nextDice - 1],
                      child: Center(
                        child: Transform.translate(
                          // Floats in from the right side riding the liquid wave
                          offset: Offset(150 * (1 - _liquidAnimation.value), 0),
                          child: Transform.scale(
                            // Grows slightly into place
                            scale: 0.8 + (0.2 * _liquidAnimation.value),
                            child: DiceDots(
                              number: _nextDice,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
          // Settings Icon - Positioned in top-right
          Positioned(
            top: 60,
            right: 30,
            child: GestureDetector(
              onTap: _showSettingsDialog,
              child: const Icon(
                Icons.settings,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _showCount ? Container(
        color: Colors.grey.shade900,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_currentDice',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              diceLabels[_currentDice - 1],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ) : null,
    );
  }
}

// --- The Core Liquid Math ---
class LiquidClipper extends CustomClipper<Path> {
  final double progress;

  LiquidClipper({required this.progress});

  @override
  Path getClip(Size size) {
    final path = Path();
    
    if (progress <= 0.0) {
      return path; 
    }

    // Allow progress to exceed 1.0 safely so the easeOutBack bounce works without glitching.
    double baseX = size.width * (1 - progress);
    
    // Clamp the sin input to 0-1 so the bulge doesn't invert during the bounce overshoot
    double normalizedProgress = progress.clamp(0.0, 1.0);
    double maxBulge = 140.0; // Slightly deeper bulge
    double bulge = sin(normalizedProgress * pi) * maxBulge;
    
    double controlX = baseX - bulge;
    double controlY = size.height / 2;

    path.moveTo(size.width, 0); 
    path.lineTo(baseX, 0); 
    
    path.quadraticBezierTo(
      controlX, controlY, 
      baseX, size.height  
    );
    
    path.lineTo(size.width, size.height); 
    path.close();

    return path;
  }

  @override
  bool shouldReclip(LiquidClipper oldClipper) => oldClipper.progress != progress;
}

// --- Dice UI Component ---
class DiceDots extends StatelessWidget {
  final int number;
  final Color color;

  const DiceDots({
    super.key,
    required this.number,
    required this.color,
  });

  List<List<bool>> getDicePattern() {
    switch (number) {
      case 1:
        return [
          [false, false, false],
          [false, true, false],
          [false, false, false],
        ];
      case 2:
        return [
          [true, false, false],
          [false, false, false],
          [false, false, true],
        ];
      case 3:
        return [
          [true, false, false],
          [false, true, false],
          [false, false, true],
        ];
      case 4:
        return [
          [true, false, true],
          [false, false, false],
          [true, false, true],
        ];
      case 5:
        return [
          [true, false, true],
          [false, true, false],
          [true, false, true],
        ];
      case 6:
        return [
          [true, false, true],
          [true, false, true],
          [true, false, true],
        ];
      case 7:
        return [
          [true, false, true],
          [true, false, true],
          [true, false, true],

          [false, false, false],

          [false, false, false],
          [false, true, false],
          [false, false, false],
        ];
      case 8:
        return [
          [true, false, true],
          [true, false, true],
          [true, false, true],

          [false, false, false],

          [true, false, false],
          [false, false, false],
          [false, false, true],
          
        ];
      case 9:
        return [
          [true, false, true],
          [true, false, true],
          [true, false, true],

          [false, false, false],

          [true, false, false],
          [false, true, false],
          [false, false, true],
          
        ];
      case 10:
        return [
          [true, false, true],
          [true, false, true],
          [true, false, true],

          [false, false, false],

          [true, false, true],
          [false, false, false],
          [true, false, true],
        ];
      case 11:
        return [
          [true, false, true],
          [true, false, true],
          [true, false, true],

          [false, false, false],
          
          [true, false, true],
          [false, true, false],
          [true, false, true],
        ];
      case 12:
        return [
          [true, false, true],
          [true, false, true],
          [true, false, true],

          [false, false, false],
          
          [true, false, true],
          [true, false, true],
          [true, false, true],
        ];
      default:
        return [
          [false, false, false],
          [false, false, false],
          [false, false, false],
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final pattern = getDicePattern();

    return SizedBox(
      width: 250,
      child: Center(
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          children: pattern.expand((row) {
            return row.map((hasDot) {
              return Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasDot ? color : Colors.transparent,
                  ),
                ),
              );
            }).toList();
          }).toList(),
        ),
      ),
    );
  }
}
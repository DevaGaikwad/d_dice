import 'package:flutter/material.dart';
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
  bool _isRolling = false;

  final List<Color> diceColors = [
    Colors.red.shade600,
    Colors.blue.shade600,
    Colors.green.shade600,
    Colors.orange.shade600,
    Colors.purple.shade600,
    Colors.teal.shade600,
  ];

  final List<String> diceLabels = ['One', 'Two', 'Three', 'Four', 'Five', 'Six'];

  @override
  void initState() {
    super.initState();
    _currentDice = 1;
    _nextDice = 2;
    _animationController = AnimationController(
      // Increased duration slightly to let the spring effect breathe
      duration: const Duration(milliseconds: 600), 
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
    super.dispose();
  }

  void _rollDice() {
    if (_isRolling) return;

    _isRolling = true;

    // Generate 5 intermediate random numbers - ensuring no consecutive duplicates
    List<int> sequence = [_currentDice];
    for (int i = 0; i < 5; i++) {
      int nextNumber;
      do {
        nextNumber = Random().nextInt(6) + 1;
      } while (nextNumber == sequence.last);
      sequence.add(nextNumber);
    }
    
    // Add final random number
    int finalNumber;
    do {
      finalNumber = Random().nextInt(6) + 1;
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: GestureDetector(
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
      bottomNavigationBar: Container(
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
      ),
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
      height: 350,
      child: GridView.count(
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
    );
  }
}
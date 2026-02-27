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
      duration: const Duration(milliseconds: 450), // Slightly faster for liquid feel
      vsync: this,
    );
    
    // easeOutSine gives a nice "rushing" liquid feel that settles smoothly
    _liquidAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutSine,
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
      
      // Update current dice immediately after the sweep finishes
      setState(() {
        _currentDice = _nextDice;
      });
      
      // Schedule next animation
      if (index < sequence.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _animateSequence(sequence, index + 1, finalNumber);
          }
        });
      } else {
        // Done rolling
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
                  // 1. Current dice - Stays static in the background
                  Container(
                    width: screenWidth,
                    height: screenHeight,
                    color: diceColors[_currentDice - 1],
                    child: Center(
                      child: DiceDots(
                        number: _currentDice,
                        color: Colors.white,
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
                        child: DiceDots(
                          number: _nextDice,
                          color: Colors.white,
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
      return path; // Nothing to show yet
    }
    if (progress >= 1.0) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      return path; // Fully revealed
    }

    // The base X coordinate moves from right (width) to left (0)
    double baseX = size.width * (1 - progress);
    
    // The "bulge" or "drop" pulls out further left than the base line.
    // We use sin() so it starts at 0, peaks in the middle of the animation, and goes back to 0.
    double maxBulge = 120.0; // Increase this for a deeper liquid curve
    double bulge = sin(progress * pi) * maxBulge;
    
    // The control point for the curve (pulls the liquid left)
    double controlX = baseX - bulge;
    double controlY = size.height / 2;

    // Draw the shape
    path.moveTo(size.width, 0); // Start top right
    path.lineTo(baseX, 0); // Move to top left of the curve
    
    // Create the smooth liquid curve
    path.quadraticBezierTo(
      controlX, controlY, // The peak of the liquid bubble
      baseX, size.height  // Connects to the bottom left
    );
    
    path.lineTo(size.width, size.height); // Bottom right
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
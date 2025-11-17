import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Constructor const جاهز

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تجربة Flutter',
      home: Scaffold(
        appBar: AppBar(title: const Text('مرحبا jood')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('اضغطي الزر لتغيير اللون:', style: TextStyle(fontSize: 20)),
              SizedBox(height: 20),
              ColorChanger(),
            ],
          ),
        ),
      ),
    );
  }
}

class ColorChanger extends StatefulWidget {
  const ColorChanger({super.key});

  @override
  _ColorChangerState createState() => _ColorChangerState();
}

class _ColorChangerState extends State<ColorChanger> {
  Color _color = Colors.blue;

  void _changeColor() {
    setState(() {
      _color = _color == Colors.blue
          ? Colors.green
          : Colors.blue; // toggle color
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(width: 150, height: 150, color: _color),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _changeColor,
          child: const Text('تغيير اللون'),
        ),
      ],
    );
  }
}

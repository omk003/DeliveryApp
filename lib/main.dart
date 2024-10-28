import 'package:flutter/material.dart';
import 'pages/delivery_agent.dart'; // Importing the delivery agent page
import 'pages/hotel.dart'; // Importing the hotel page

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<Widget> _children = [
    const DeliveryAgentScreen(),
    const HotelScreen(),
  ];

  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery & Hotel App'),
        backgroundColor: Theme.of(context)
            .primaryColor, // Set app bar color to primary color
      ),
      body: _children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        onTap: onTabTapped,
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.delivery_dining),
            label: 'Delivery Agent',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Hotel',
          ),
        ],
      ),
    );
  }
}

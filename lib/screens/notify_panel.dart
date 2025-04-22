import 'package:flutter/material.dart';

class NotificationPanel extends StatelessWidget {
  final List<String> notifications = [
    "🔋 Battery low: 10% remaining",
    "⚡ New charging station added nearby",
    "🚗 Your vehicle needs servicing soon"
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: EdgeInsets.all(16),
      color: Colors.black87, // ✅ Set background color to black
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Notifications",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Icon(Icons.notifications, color: Colors.white70),
                  title: Text(notifications[index], style: TextStyle(color: Colors.white)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

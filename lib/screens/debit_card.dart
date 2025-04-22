import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';  // Import just_audio
import 'wallet_provider.dart';  // Assuming you have this file with the wallet provider logic

class DebitCardPage extends StatefulWidget {
  const DebitCardPage({super.key});

  @override
  State<DebitCardPage> createState() => _DebitCardPageState();
}

class _DebitCardPageState extends State<DebitCardPage> with TickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();  // Using just_audio here
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  void _rechargeWallet() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    // Add money to the wallet balance
    walletProvider.addMoney(amount);

    // Add transaction with description and paymentMethod (Debit)
    walletProvider.addTransaction(
      WalletTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        date: DateTime.now(),
        description: 'Recharge via Debit Card',
        paymentMethod: 'Debit',
        // to: "Toll Seva's wallet",
      ),
    );

    // Show success animation with sound
    _showSuccessAnimation(amount);

    // Clear the input field
    _amountController.clear();
  }

  Future<void> _showSuccessAnimation(double amount) async {
    // Show image dialog with white background and reduced height
    _fadeController.forward();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FadeTransition(
        opacity: _fadeController,
        child: Dialog(
          backgroundColor: Colors.white, // Set the background to white
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Rounded corners
          ),
          child: Container(
            height: 200, // Reduced height for the dialog to make it more compact
            width: 300, // Width of the dialog
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Display the blue tick PNG image
                  Image.asset(
                    'assets/images/blue_tick.png', // Path to your PNG image
                    height: 120, // Set appropriate size for the image
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '₹$amount recharged successfully!',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Play sound simultaneously with the image
    await _audioPlayer.setAsset('assets/audio/confirmation_tone.wav'); // Load the asset sound
    await _audioPlayer.play();  // Play the sound

    // Wait for 3 seconds and then close the dialog
    await Future.delayed(const Duration(seconds: 2));

    // Close the dialog after 3 seconds
    if (mounted) {
      _fadeController.reverse(); // Fade out before closing
      await Future.delayed(const Duration(milliseconds: 300)); // Wait for fade out
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _audioPlayer.dispose();  // Dispose the audio player
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Debit Card Recharge',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.blue),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the amount to recharge:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter amount (e.g., 500)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _rechargeWallet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Recharge Wallet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
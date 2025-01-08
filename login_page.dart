import 'package:flutter/material.dart';
import 'home_page.dart';
import 'signup_page.dart';
import 'registration_page.dart';

class LoginPage extends StatefulWidget {
  final String email;
  final String password;

  const LoginPage({super.key, required this.email, required this.password});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all the fields!')),
      );
    } else if (_emailController.text == widget.email &&
        _passwordController.text == widget.password) {
      // Navigate with opacity transition
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const RegistrationPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var opacityTween = Tween(begin: 0.0, end: 1.0);
            var opacityAnimation = animation.drive(opacityTween);

            return FadeTransition(opacity: opacityAnimation, child: child);
          },
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid credentials!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Login to your account',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Email',
                  prefixIcon: Icon(Icons.email, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Password',
                  prefixIcon: Icon(Icons.lock, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 100.0, vertical: 15.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: const [
                  Expanded(
                    child: Divider(
                      color: Colors.black26,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Colors.black26,
                      thickness: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  // Handle Google Sign-In logic here
                },
                icon: const Icon(Icons.login, color: Colors.white),
                label: const Text(
                  'Sign in with Google',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 50.0, vertical: 15.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Don\'t have an account? ',
                      style: TextStyle(color: Colors.black54)),
                  GestureDetector(
                    onTap: () {
                      // Navigate to Sign Up with opacity transition
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => const SignUpPage(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            var opacityTween = Tween(begin: 0.0, end: 1.0);
                            var opacityAnimation = animation.drive(opacityTween);

                            return FadeTransition(opacity: opacityAnimation, child: child);
                          },
                        ),
                      );
                    },
                    child: const Text(
                      'Sign Up!',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

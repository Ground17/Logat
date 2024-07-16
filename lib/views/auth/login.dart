import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../main.dart';
import '../../utils/utils_login.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

enum SignInMode {
  signIn, signUp, forgotPassword
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  var signInMode = SignInMode.signIn;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Log in'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', icon: Icon(Icons.mail)),
                validator: (value) {
                  if (value == '') {
                    return 'Please enter your email.';
                  }
                  return null;
                },
              ),
              Visibility(
                visible: signInMode != SignInMode.forgotPassword, // 조건에 따라 Widget 가시성 설정
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', icon: Icon(Icons.lock)),
                  validator: (value) {
                    if (value == '') {
                      return 'Please enter your password.';
                    }

                    if ((value?.length ?? 0) < 8) {
                      return 'A password of at least 8 characters is recommended.';
                    }
                    return null;
                  },
                )
              ),
              Visibility(
                visible: signInMode == SignInMode.signUp, // 조건에 따라 Widget 가시성 설정
                child: TextFormField(
                  controller: _passwordConfirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm Password', icon: Icon(Icons.lock)),
                  validator: (value) {
                    if (signInMode == SignInMode.signUp) {
                      if (value == '') {
                        return 'Please enter confirm password.';
                      }

                      if ((value?.length ?? 0) < 8) {
                        return 'A password of at least 8 characters is recommended.';
                      }

                      if (value != _passwordController.text) {
                        return 'Please check password and confirm password.';
                      }
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
                          return;
                        }

                        switch (signInMode) {
                          case SignInMode.signIn:
                            if (await LoginMethod.signInWithEmail(_emailController.text, _passwordController.text)) {
                              if (!context.mounted) return;

                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Logat',)));
                              return;
                            } else {
                              showMessage("Please check if the Internet is connected and email/password is correct.");
                            }
                            break;
                          case SignInMode.signUp:
                            if (await LoginMethod.signUpWithEmail(_emailController.text, _passwordController.text)) {

                              if (FirebaseAuth.instance.currentUser != null) { // Sign up 성공하면 거의 무조건 실행됨
                                if (!context.mounted) return;

                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Logat',)));
                                return;
                              }

                              showMessage("Please check if the Internet is connected and try again.");
                            } else {
                              showMessage("Please check if the Internet is connected and try again.");
                            }
                            break;
                          case SignInMode.forgotPassword:
                            if (await LoginMethod.resetPasswordWithEmail(_emailController.text)) {
                              if (!context.mounted) return;

                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Logat',)));
                            } else {
                              showMessage("Please check if the Internet is connected and try again.");
                            }
                            break;
                        }
                      },
                      child: Text((signInMode == SignInMode.signIn ? 'Log in' : (signInMode == SignInMode.signUp ? 'Create account' : 'Send email to reset password'))),
                    ),
                  ),
                ],
              ),
              Divider(),
              signInMode == SignInMode.signIn ?
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        signInMode = SignInMode.signUp;
                      });
                    },
                    child: const Text('Create account'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        signInMode = SignInMode.forgotPassword;
                      });
                    },
                    child: const Text('Forgot password?'),
                  ),
                ],
              ) : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        signInMode = SignInMode.signIn;
                      });
                    },
                    child: const Text('Go back to log in'),
                  ),
                ],
              ),
              Divider(),
              Visibility(
                visible: signInMode == SignInMode.signIn, // 조건에 따라 Widget 가시성 설정
                child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (await LoginMethod.signInWithGoogle()) { // Google login
                              if (!context.mounted) return;

                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Logat',)));
                            } else {
                              showMessage("Please check if the Internet is connected and try again.");
                            }
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Image(
                                image: AssetImage("assets/google_logo.png"),
                                height: 24.0,
                              ),
                              Padding(
                                padding: EdgeInsets.only(left: 10),
                                child: Text(
                                  'Sign in with Google',
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  )),
              Visibility(
                visible: signInMode == SignInMode.signIn, // 조건에 따라 Widget 가시성 설정
                child: SizedBox(height: 10.0)),
              Visibility(
                visible: signInMode == SignInMode.signIn, // 조건에 따라 Widget 가시성 설정
                child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (await LoginMethod.signInWithApple()) { // Apple login
                              if (!context.mounted) return;

                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Logat',)));
                            } else {
                              showMessage("Please check if the Internet is connected and try again.");
                            }
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Image(
                                image: AssetImage("assets/apple_logo.png"),
                                height: 24.0,
                              ),
                              Padding(
                                padding: EdgeInsets.only(left: 10),
                                child: Text(
                                  'Sign in with Apple',
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  )),
              Visibility(
                visible: signInMode == SignInMode.signIn, // 조건에 따라 Widget 가시성 설정
                child: Divider(),
              ),
              Visibility(
                visible: signInMode == SignInMode.signIn, // 조건에 따라 Widget 가시성 설정
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          showMessageWithCancel("Anonymous log in provides the necessary features to use Logat as a test, and more features will be available after you log in to your real account later. Do you want to continue?", () async {
                              try {
                                final userCredential =
                                await FirebaseAuth.instance.signInAnonymously();
                                print("Signed in with temporary account.");

                                if (!context.mounted) return;
                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Logat',)));
                              } catch (e) {
                                showMessage("Please check if the Internet is connected and try again.");
                                print(e);
                              }
                            }
                          );
                        },
                        child: const Text('Anonymous Log in'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showMessage(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(message),
        actions: <TextButton>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void temp() {
    showAboutDialog(context: context);
  }

  void showMessageWithCancel(String message, Function f) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(message),
        actions: <TextButton>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              f();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
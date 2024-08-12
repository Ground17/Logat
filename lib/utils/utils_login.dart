// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:google_sign_in/google_sign_in.dart';
//
// import '../views/auth/login.dart';
//
// class LoginMethod {
//   static Future<bool> signInWithEmail(String email, String password) async {
//     try {
//       if (FirebaseAuth.instance.currentUser != null) {
//         final credential = EmailAuthProvider.credential(email: email, password: password);
//         await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
//         return true;
//       }
//
//       final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       return true;
//     } catch (e) {
//       print(e);
//       return false;
//     }
//   }
//
//   // static Future<bool> sendEmailVerification() async {
//   //   try {
//   //     if (FirebaseAuth.instance.currentUser != null) {
//   //       await FirebaseAuth.instance.currentUser!.sendEmailVerification();
//   //       return true;
//   //     }
//   //     return false;
//   //   } catch (e) {
//   //     print(e);
//   //     return false;
//   //   }
//   // }
//
//   static Future<bool> signUpWithEmail(String email, String password) async {
//     try {
//       final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
//       return true;
//     } catch (e) {
//       print(e);
//       return false;
//     }
//   }
//
//   static Future<bool> resetPasswordWithEmail(String email) async {
//     try {
//       await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
//       return true;
//     } catch (e) {
//       print(e);
//       return false;
//     }
//   }
//
//   static Future<bool> signInWithGoogle() async {
//     try {
//       final googleUser = await GoogleSignIn().signIn();
//       final googleAuth = await googleUser?.authentication;
//       final credential = GoogleAuthProvider.credential(
//         idToken: googleAuth?.idToken,
//         accessToken: googleAuth?.accessToken,
//       );
//
//       if (FirebaseAuth.instance.currentUser != null) {
//         await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
//         return true;
//       }
//
//       await FirebaseAuth.instance.signInWithCredential(
//         credential,
//       );
//       return true;
//     } catch (e) {
//       print(e);
//       return false;
//     }
//   }
//
//   static Future<bool> signInWithApple() async {
//     try {
//       final appleProvider = AppleAuthProvider();
//       if (FirebaseAuth.instance.currentUser != null) {
//         await FirebaseAuth.instance.currentUser!.linkWithProvider(appleProvider);
//         return true;
//       }
//
//       await FirebaseAuth.instance.signInWithProvider(appleProvider);
//       return true;
//     } catch (e) {
//       print(e);
//       return false;
//     }
//   }
//
//   static Future<bool> unlinkAccount(String providerId) async {
//     try {
//       await FirebaseAuth.instance.currentUser?.unlink(providerId);
//       return true;
//     } catch (e) {
//       print(e);
//       return false;
//     }
//   }
//
//   static Future<bool> signOut() async {
//     try {
//       await FirebaseAuth.instance.signOut();
//       return true;
//     } catch (e) {
//       print(e);
//       return false;
//     }
//   }
// }
//
// class LoginDialog extends StatefulWidget {
//   const LoginDialog({Key? key}) : super(key: key);
//
//   @override
//   State<LoginDialog> createState() => _LoginDialogState();
// }
//
// class _LoginDialogState extends State<LoginDialog> {
//   final _formKey = GlobalKey<FormState>();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _passwordConfirmController = TextEditingController();
//
//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     _passwordConfirmController.dispose();
//     super.dispose();
//   }
//
//   var signInMode = SignInMode.signIn;
//
//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text('Email Log in'),
//       content: Form(
//         key: _formKey,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             TextFormField(
//               controller: _emailController,
//               decoration: const InputDecoration(labelText: 'Email', icon: Icon(Icons.mail)),
//               validator: (value) {
//                 if (value == '') {
//                   return 'Please enter your email.';
//                 }
//                 return null;
//               },
//             ),
//             TextFormField(
//               controller: _passwordController,
//               obscureText: true,
//               decoration: const InputDecoration(labelText: 'Password', icon: Icon(Icons.lock)),
//               validator: (value) {
//                 if (value == '') {
//                   return 'Please enter your password.';
//                 }
//
//                 if ((value?.length ?? 0) < 8) {
//                   return 'A password of at least 8 characters is recommended.';
//                 }
//                 return null;
//               },
//             ),
//             Visibility(
//               visible: signInMode == SignInMode.signUp, // 조건에 따라 Widget 가시성 설정
//               child: TextFormField(
//                 controller: _passwordConfirmController,
//                 obscureText: true,
//                 decoration: const InputDecoration(labelText: 'Confirm Password', icon: Icon(Icons.lock)),
//                 validator: (value) {
//                   if (signInMode == SignInMode.signUp) {
//                     if (value == '') {
//                       return 'Please enter confirm password.';
//                     }
//
//                     if ((value?.length ?? 0) < 8) {
//                       return 'A password of at least 8 characters is recommended.';
//                     }
//
//                     if (value != _passwordController.text) {
//                       return 'Please check password and confirm password.';
//                     }
//                   }
//                   return null;
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//       actions: <Widget>[
//         TextButton(
//           child: const Text('취소'),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         TextButton(
//           child: const Text('확인'),
//           onPressed: () async {
//             switch (signInMode) {
//               case SignInMode.signIn:
//                 if (await LoginMethod.signInWithEmail(_emailController.text, _passwordController.text)) {
//                   if (!context.mounted) return;
//
//                   Navigator.of(context).pop(true);
//                   return;
//                 } else {
//                   if (!context.mounted) return;
//
//                   Navigator.of(context).pop(false);
//                 }
//                 break;
//               case SignInMode.signUp:
//                 if (await LoginMethod.signUpWithEmail(_emailController.text, _passwordController.text)) {
//
//                   if (FirebaseAuth.instance.currentUser != null) { // Sign up 성공하면 거의 무조건 실행됨
//                     if (!context.mounted) return;
//
//                     Navigator.of(context).pop(true);
//                     return;
//                   }
//                   if (!context.mounted) return;
//
//                   Navigator.of(context).pop(false);
//                 } else {
//                   if (!context.mounted) return;
//
//                   Navigator.of(context).pop(false);
//                 }
//                 break;
//             }
//           },
//         ),
//       ],
//     );
//   }
// }
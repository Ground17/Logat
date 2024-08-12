// import 'package:flutter/material.dart';
// import 'package:logat/utils/utils_login.dart';
// import 'package:logat/views/auth/login.dart';
//
//
// class ProfileScreen extends StatefulWidget {
//   const ProfileScreen({Key? key, required this.userId}) : super(key: key);
//
//   final String userId;
//   @override
//   _ProfileScreenState createState() => _ProfileScreenState();
// }
//
// class _ProfileScreenState extends State<ProfileScreen> {
//   @override
//   void initState() {
//     super.initState();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       child: TextButton(
//         onPressed: () async {
//           if (await LoginMethod.signOut()) {
//             if (!context.mounted) return;
//
//             Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
//           }
//         },
//         child: const Text('Log out'),
//       ),
//     );
//   }
// }
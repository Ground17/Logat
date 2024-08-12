// import 'package:flutter/material.dart';
// import 'package:logat/utils/utils_login.dart';
// import 'package:logat/views/auth/login.dart';
//
//
// class EditProfileScreen extends StatefulWidget {
//   const EditProfileScreen({Key? key}) : super(key: key);
//
//   @override
//   _EditProfileScreenState createState() => _EditProfileScreenState();
// }
//
// class _EditProfileScreenState extends State<EditProfileScreen> {
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
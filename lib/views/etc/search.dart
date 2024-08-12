// import 'package:flutter/material.dart';
// import 'package:logat/utils/utils_login.dart';
// import 'package:logat/views/auth/login.dart';
//
//
// class SearchScreen extends StatefulWidget {
//   const SearchScreen({Key? key}) : super(key: key);
//
//   @override
//   _SearchScreenState createState() => _SearchScreenState();
// }
//
// class _SearchScreenState extends State<SearchScreen> {
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
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logat/utils/utils_login.dart';
import 'package:logat/views/auth/login.dart';

import '../../main.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({Key? key}) : super(key: key);

  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  String displayName = "";
  String handle = "";
  bool isEmailLogin = false;
  bool isAndroidLogin = false;
  bool isIOSLogin = false;

  void getUserDetail() async {
    var users = await FirebaseFirestore.instance.doc("user/${FirebaseAuth.instance.currentUser?.uid}").get();

    for (var userinfo in FirebaseAuth.instance.currentUser?.providerData ?? []) {
      switch (userinfo.providerId) {
        case "password":
          isEmailLogin = true;
          break;
        case "google.com":
          isAndroidLogin = true;
          break;
        case "apple.com":
          isIOSLogin = true;
          break;
      }
    }

    setState(() {
      displayName = users.get('displayName');
      handle = users.get('handle');
    });
  }

  @override
  void initState() {
    super.initState();
    getUserDetail();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        leading: IconButton(
          icon: Icon(
              Platform.isAndroid ? Icons.arrow_back : CupertinoIcons.back,
              color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("Settings", style: TextStyle(color: Colors.white),),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
        shrinkWrap: true,
        children: [
          ListTile(
            leading: ClipOval(
              child: Image.network('https://storage.googleapis.com/logat-release.appspot.com/profile/${FirebaseAuth.instance.currentUser?.uid}/thumb/${FirebaseAuth.instance.currentUser?.uid}_144x144.jpeg',
                loadingBuilder: (context, child, event) {
                  if(event == null){
                    return child;
                  }
                  return CircularProgressIndicator (
                    value: event.expectedTotalBytes != null ? event.cumulativeBytesLoaded / event.expectedTotalBytes! : null,
                  );
                },
                errorBuilder: (context, object, error) => const Icon(Icons.person),
              ),
            ),
            title: SelectableText(displayName),
            subtitle: SelectableText("@$handle"),
            trailing: IconButton(
              icon: const Icon(Icons.edit), onPressed: () {

              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipOval(
                child: Container(
                  color: !isEmailLogin ? Colors.grey : null,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(!isEmailLogin ? Colors.grey : Colors.transparent, BlendMode.saturation),
                    child: IconButton(
                      icon: const Icon(Icons.mail),
                      onPressed: () {
                        bool isLogin = false;
                        for (var userinfo in FirebaseAuth.instance.currentUser?.providerData ?? []) {
                          if (userinfo.providerId == "password") {
                            isLogin = true;
                            break;
                          }
                        }

                        showMessageWithCancel("Do you want to ${isLogin ? "unlink" : "link"} Google account?", () async {
                          if (isLogin) {
                            if (await LoginMethod.unlinkAccount("password")) {
                              if ((FirebaseAuth.instance.currentUser?.providerData.length ?? 0) < 2) {
                                showMessage("You cannot unlink this account.");
                                return;
                              }

                              showMessage("Unlinked successfully.");
                              setState(() {
                                isEmailLogin = false;
                              });
                            } else {
                              showMessage("You cannot unlink this account.");
                            }
                            return;
                          }

                          showDialog(
                            context: context,
                            builder: (context) => const LoginDialog(),
                          ).then((value) {
                            print('입력한 값: $value');

                            for (var userinfo in FirebaseAuth.instance.currentUser?.providerData ?? []) {
                              if (userinfo.providerId == "password") {
                                isLogin = true;
                                break;
                              }
                            }

                            if (isLogin) {
                              showMessage("You just link your account with email address successfully.");
                              setState(() {
                                isEmailLogin = true;
                              });
                            } else {
                              showMessage("Please check if the Internet is connected and email/password is correct.");
                            }
                          });
                        });
                      },
                    ),
                  ),
                ),
              ),
              ClipOval(
                child: Container(
                  color: !isAndroidLogin ? Colors.grey : null,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(!isAndroidLogin ? Colors.grey : Colors.transparent, BlendMode.saturation),
                    child: IconButton(
                      icon: const Image(
                        image: AssetImage("assets/google_logo.png"),
                        height: 24.0,
                      ),
                      onPressed: () {
                        bool isLogin = false;
                        for (var userinfo in FirebaseAuth.instance.currentUser?.providerData ?? []) {
                          if (userinfo.providerId == "google.com") {
                            isLogin = true;
                            break;
                          }
                        }

                        showMessageWithCancel("Do you want to ${isLogin ? "unlink" : "link"} Google account?", () async {
                          if (isLogin) {
                            if (await LoginMethod.unlinkAccount("google.com")) {
                              if ((FirebaseAuth.instance.currentUser?.providerData.length ?? 0) < 2) {
                                showMessage("You cannot unlink this account.");
                                return;
                              }

                              showMessage("Unlinked successfully.");
                              setState(() {
                                isAndroidLogin = false;
                              });
                            } else {
                              showMessage("You cannot unlink this account.");
                            }
                            return;
                          }

                          if (await LoginMethod.signInWithGoogle()) {
                            showMessage("You just link your account with Google successfully.");
                            setState(() {
                              isAndroidLogin = true;
                            });
                          } else {
                            showMessage("You can't link your account with Google now.");
                          }
                        });
                      },
                    ),
                  ),
                ),
              ),
              ClipOval(
                child: Container(
                  color: !isIOSLogin ? Colors.grey : null,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(!isIOSLogin ? Colors.grey : Colors.transparent, BlendMode.saturation),
                    child: IconButton(
                      icon: const Image(
                        image: AssetImage("assets/apple_logo.png"),
                        height: 24.0,
                      ),
                      onPressed: () {
                        bool isLogin = false;
                        for (var userinfo in FirebaseAuth.instance.currentUser?.providerData ?? []) {
                          if (userinfo.providerId == "apple.com") {
                            isLogin = true;
                            break;
                          }
                        }

                        showMessageWithCancel("Do you want to ${isLogin ? "unlink" : "link"} Apple account?", () async {
                          if (isLogin) {
                            if (await LoginMethod.unlinkAccount("apple.com")) {
                              if ((FirebaseAuth.instance.currentUser?.providerData.length ?? 0) < 2) {
                                showMessage("You cannot unlink this account.");
                                return;
                              }

                              showMessage("Unlinked successfully.");
                              setState(() {
                                isIOSLogin = false;
                              });
                            } else {
                              showMessage("You cannot unlink this account.");
                            }
                            return;
                          }

                          if (await LoginMethod.signInWithApple()) {
                            showMessage("You just link your account with Apple successfully.");
                            setState(() {
                              isIOSLogin = true;
                            });
                          } else {
                            showMessage("You can't link your account with Apple now.");
                          }
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
            child: const Text('Close'),
          )
        ],
      ),
    );
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

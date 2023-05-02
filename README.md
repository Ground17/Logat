# Logation
It's a React Native Application. And it contains firebase firestore, storage, hosting, functions, etc...

## You can download!
- [Android Play Store](https://play.google.com/store/apps/details?id=com.hyla981020.logory)
- [Apple App Store](https://apps.apple.com/us/app/logation-with-map-and-photo/id1508263544)

## To-do list
- [ ] perfect notification functions
- [ ] make log by using episodes of Infinity Challenge

## App.js (contains function/class component)
- Main (function component) -> function component that binds initial screen in tabbar form after login. function related to universal link, deep link also added.
- App (class component) -> functions that bind all screens, including the main component described above.

## assets/screens (contains almost class component)
- AddList
    - to add log based on photo in your device

- EditProfile
    - to edit users' profileURL, nickname...

- Following
    - to list up users' following people (not follower people)

- Home
    - to view other users' logs

- Language
    - to change language

- Login
    - to log in

- Me
    - to view profile of users

- Notification
    - to notify

- Purchase
    - for in-app purchases

- ResetPassword
    - for password to reset

- Search
    - to search other users

- ShowDetail
    - to view details(title, subtitle, date, modifyDate, url, ...) of log

- ShowItem
    - to view details(location, description, ...) of photo

- ShowScreen
    - to view photos and logation of them

- SignUp
    - to sign up

- UserSetting
    - to allow users to log out, delete account, and so on

- Utils
    - to provide functions like translate, style, purchase, and so on

## assets/translations
Logation currently supports Korean, English, Japanese, Chinese, Spanish, Portuguese, French, and German. Non-Korean and English languages rely on Google Translation and Papago(ⓒ NAVER Corp.). It is a great help to us if you participate in the translation through issue or full request!

## public
directory related to firebase hosting. Our website is made by it.
[Logation Official Website](https://travelog-4e274.web.app/)

## functions
directory related to firebase functions. It'll be used for tasks that require stability, such as in-app purchases.

# 🎓 BUIC App

A cross-platform Flutter application built for **Bahria University Islamabad Campus (BUIC)** students, teachers, and parents. It provides a unified portal to manage academic activities, attendance, fees, timetables, and more — all integrated with Firebase.

---

## ✨ Features

### 👨‍🎓 Student Portal
- **Dashboard** — Quick overview of academic status
- **BU AI Assistant** — RAG-based AI chatbot trained on the official handbook with multi-turn session memory
- **My Courses** — View enrolled courses, grades, and details
- **Transcript** — Access academic transcripts
- **Fee Management** — Check fee status and payment details
- **Leave Status** — Apply for and track leave requests
- **Downloads** — Download academic resources and documents
- **Timetable** — View weekly class schedule
- **To-Do List** — Personal task management with local storage

### 👨‍🏫 Teacher Portal
- **Teacher Login** — Separate authentication flow for faculty
- **Teacher Management** — Manage courses and student interactions

### 👨‍👩‍👦 Parent Portal
- **Parent Login** — Dedicated login for parents
- **Parent Dashboard** — Monitor ward's academic progress

### 🔐 Authentication
- Firebase Authentication (Email/Password)
- Role-based routing (Student / Teacher / Parent / Admin)
- Persistent sessions with `SharedPreferences`

### 🛠️ Admin Panel
- Administrative tools and management features

---

## 🏗️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| Backend | Firebase (Auth, Firestore, Storage, Functions, Messaging) |
| State Management | Riverpod + Provider |
| Local DB | Hive + SQLite (sqflite) |
| Charts | fl_chart |
| Notifications | Firebase Messaging + flutter_local_notifications |
| HTTP Client | Dio |
| UI Extras | flutter_animate, shimmer, percent_indicator, dotted_border |

---

## 📁 Project Structure

```
lib/
├── admin/                  # Admin panel screens
├── home_page/              # Student home page widgets
├── pages/                  # Main feature pages
│   ├── home_page.dart
│   ├── my_courses_page.dart
│   ├── transcript_page.dart
│   ├── fee_page.dart
│   ├── leave_status_page.dart
│   └── downloads_page.dart
├── services/               # Business logic & data services
│   ├── student_data_service.dart
│   ├── timetable_service.dart
│   ├── download_service.dart
│   └── database_helper.dart
├── teacher_management/     # Teacher-specific screens
├── main.dart               # App entry point
├── auth_wrapper.dart       # Auth state listener
├── home_screen.dart        # Student home screen
├── login_screen.dart       # Student login
├── teacher_login.dart      # Teacher login
├── parent_login.dart       # Parent login
├── splash_screen.dart      # Animated splash screen
├── to_do_list.dart         # Local to-do feature
└── firebase_options.dart   # Firebase config
```

---

## 🚀 Getting Started

> 📖 **Full Setup Manual:** See [RUN_GUIDE.md](file:///c:/Users/hp/Downloads/buic_app/buic_app/RUN_GUIDE.md) for step-by-step instructions on setting up and running the Python AI backend and Flutter mobile app.

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK `^3.9.0`)
- [Firebase CLI](https://firebase.google.com/docs/cli) configured
- Android Studio / VS Code

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/sabeeh676/buic_app.git
   cd buic_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Update `lib/firebase_options.dart` with your config

4. **Run the app**
   ```bash
   flutter run
   ```

---

## 📦 Key Dependencies

```yaml
firebase_auth, firebase_core, cloud_firestore, firebase_storage,
firebase_messaging, cloud_functions, flutter_riverpod, provider,
hive, sqflite, fl_chart, dio, image_picker, file_picker,
flutter_animate, shimmer, table_calendar, cached_network_image
```

---

## 🔒 Security Note

> ⚠️ **Important:** The `lib/firebase_options.dart` file may contain sensitive Firebase API keys. Make sure to restrict your Firebase API keys in the [Google Cloud Console](https://console.cloud.google.com) and never expose production credentials publicly.

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

---

## 📄 License

This project is for educational purposes at **Bahria University Islamabad Campus**.

---

<p align="center">Built with ❤️ using Flutter & Firebase</p>

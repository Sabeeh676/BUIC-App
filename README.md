# 🎓 BUIC App

A comprehensive cross-platform Flutter application built for **Bahria University Islamabad Campus (BUIC)** students, teachers, and parents. It features an integrated **AI Assistant (RAG Chatbot)** for university rules & regulations, along with complete academic management powered by Firebase.

---

## ✨ Features

### 👨‍🎓 Student Portal
- **BU AI Assistant** — RAG-based AI chatbot trained on the official Bahria University handbook with multi-turn conversation memory and source page citations
- **Dashboard** — Quick overview of academic status and daily schedule
- **My Courses** — View enrolled courses, grades, and details
- **Transcript** — Access academic transcripts
- **Fee Management** — Check fee status and payment details
- **Leave Status** — Apply for and track leave requests
- **Downloads** — Download academic resources and documents
- **Timetable** — View weekly class schedule
- **To-Do List** — Personal task management with local storage

### 👨‍🏫 Teacher Portal
- **Teacher Login** — Separate authentication flow for faculty
- **Teacher Management** — Manage courses, assignments, quizzes, and student interactions

### 👨‍👩‍👦 Parent Portal
- **Parent Login** — Dedicated login for parents
- **Parent Dashboard** — Monitor ward's academic progress

### 🔐 Authentication & Control
- Firebase Authentication (Email/Password)
- Role-based routing (Student / Teacher / Parent / Admin)
- Persistent sessions with `SharedPreferences`

---

## 🏗️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Mobile Framework** | Flutter (Dart `^3.9.0`) |
| **App Database & Auth** | Firebase (Auth, Firestore, Storage, Functions, Messaging) |
| **AI Backend Server** | Python 3.9+, FastAPI, Uvicorn |
| **AI / LLM Model** | Groq (`gemma2-9b-it`) via LangChain |
| **Vector DB & Search** | FAISS Vector Store + Google Generative AI Embeddings (`embedding-001`) |
| **AI Architecture** | RAG (Retrieval-Augmented Generation) with History-Aware Multi-Turn Memory |
| **State Management** | Riverpod + Provider |
| **Local Database** | Hive + SQLite (`sqflite`) |
| **HTTP Client** | Dio |
| **UI Extras** | `flutter_animate`, `shimmer`, `fl_chart`, `percent_indicator` |

---

## 📁 Project Structure

```text
buic_app/
├── backend/                       # Python AI Backend Server
│   ├── api.py                     # FastAPI RAG server & LangChain pipeline
│   ├── requirements.txt           # Python AI dependencies
│   ├── BU_Chatbot_Project_Report_Updated.pdf # Detailed project report
│   └── data/
│       └── handbook.pdf           # University Handbook dataset
├── lib/                           # Flutter Mobile Application
│   ├── admin/                     # Admin panel screens
│   ├── home_page/                 # Student home widgets & Chatbot UI
│   │   └── chatbot_page.dart      # Chatbot interface with session history
│   ├── pages/                     # Main feature pages
│   │   └── home_page.dart         # Main student dashboard
│   ├── services/                  # Business logic & APIs
│   │   └── chatbot_service.dart   # Dio service connecting to AI backend
│   ├── teacher_management/        # Faculty management screens
│   ├── main.dart                  # App entry point
│   ├── auth_wrapper.dart          # Role-based auth routing
│   └── firebase_options.dart      # Firebase configuration
├── RUN_GUIDE.md                   # Step-by-step setup manual
└── README.md                      # Project documentation
```

---

## 🚀 Getting Started

> 📖 **Full Setup Manual:** For detailed instructions, see [RUN_GUIDE.md](RUN_GUIDE.md).

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.9.0`)
- Android Studio / VS Code (with Flutter & Dart plugins)
- [Python](https://www.python.org/downloads/) (`3.9+`)
- [Groq API Key](https://console.groq.com/keys) & [Google AI API Key](https://aistudio.google.com/app/apikey)

### Quick Setup

#### 1. Start the Python AI Backend
```bash
cd backend
pip install -r requirements.txt
# Set GROQ_API_KEY and GOOGLE_API_KEY in api.py
uvicorn api:app --host 0.0.0.0 --port 8000 --reload
```

#### 2. Start the Flutter App
```bash
# In a new terminal window at project root
flutter pub get
flutter run
```

---

## 📦 Key Dependencies

### Flutter Frontend (`pubspec.yaml`)
```yaml
firebase_auth, firebase_core, cloud_firestore, firebase_storage,
firebase_messaging, cloud_functions, flutter_riverpod, provider,
hive, sqflite, fl_chart, dio, image_picker, file_picker,
flutter_animate, shimmer, table_calendar
```

### Python AI Backend (`backend/requirements.txt`)
```text
fastapi, uvicorn, langchain, langchain-groq, langchain-google-genai,
langchain-community, faiss-cpu, pypdf, python-multipart
```

---

## 🔒 Security Note

> ⚠️ **Important:** Ensure that your `GROQ_API_KEY`, `GOOGLE_API_KEY`, and `firebase_options.dart` keys are kept secure and restricted in their respective developer consoles.

---

## 📄 License

This project is created for educational and academic purposes at **Bahria University Islamabad Campus (BUIC)**.

---

<p align="center">Built with ❤️ using Flutter, Python, LangChain & Firebase</p>

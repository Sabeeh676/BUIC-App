# 🚀 How to Run the BUIC App & AI Chatbot

This guide provides step-by-step instructions to set up and run both the **Python AI Backend Server** and the **Flutter Mobile App**.

---

## 📋 Prerequisites

Before running the application, make sure you have the following installed:

1. **Python** (version `3.9` or higher) — [Download Python](https://www.python.org/downloads/)
2. **Flutter SDK** — [Install Flutter](https://docs.flutter.dev/get-started/install)
3. **IDE / Editor:** Android Studio or VS Code (with Flutter & Dart extensions)
4. **API Keys:**
   - **Groq API Key:** Free key from [console.groq.com](https://console.groq.com/)
   - **Google AI API Key:** Free key from [aistudio.google.com](https://aistudio.google.com/)

---

## 🛠️ Step 1: Start the Python AI Backend Server

The AI Chatbot relies on a Python FastAPI server running RAG (Retrieval-Augmented Generation) on the official Bahria University student handbook.

1. **Open your terminal and navigate to the backend folder:**
   ```bash
   cd buic_app/backend
   ```

2. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure API Keys in `backend/api.py`:**
   Open `backend/api.py` in your text editor and replace the placeholder API keys with your actual keys (lines 20–21):
   ```python
   GROQ_API_KEY   = "your_actual_groq_api_key_here"
   GOOGLE_API_KEY = "your_actual_google_api_key_here"
   ```

4. **Launch the FastAPI Server:**
   ```bash
   uvicorn api:app --host 0.0.0.0 --port 8000 --reload
   ```

   *You should see output indicating that the PDF handbook is loaded and the vector store is ready:*
   ```text
   🔍 Loading handbook and building vector store...
   ✅ BU Chatbot API is ready!
   INFO: Uvicorn running on http://0.0.0.0:8000
   ```

---

## 📱 Step 2: Run the Flutter Mobile App

1. **Open a new terminal window and navigate to the project root:**
   ```bash
   cd buic_app
   ```

2. **Fetch Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Connect a device or launch an emulator:**
   - **Android Emulator:** The app connects to the backend at `http://10.0.2.2:8000` automatically.
   - **Physical Device:** Update `_baseUrl` in `lib/services/chatbot_service.dart` to your computer's local IP address (e.g., `http://192.168.1.50:8000`).

4. **Launch the Flutter app:**
   ```bash
   flutter run
   ```

---

## 🤖 Step 3: Using the BU Assistant Chatbot

1. Open the app and log in to the **Student Portal**.
2. On the main Dashboard, tap the **BU Assistant** menu item (robot icon 🎓).
3. **Ask questions:** Try asking *"What is the attendance policy?"*
4. **Ask follow-up questions:** Try asking *"What happens if it drops below 75%?"* — the AI will remember the context!
5. **Reset Conversation:** Tap the trash bin icon (🗑️) in the top bar to start a fresh chat session.

---

## 🔑 Default Login Credentials

For testing and administrative management, use the default credentials below:

| Role | Email / Username | Password | Access Rights |
| :--- | :--- | :--- | :--- |
| **Admin** | `admin@buic.com` | `admin` | Full admin dashboard to add/edit students, teachers, classes & fees |

---

## ❓ Troubleshooting

| Issue | Solution |
| :--- | :--- |
| **Server Offline status in Flutter app** | Make sure Uvicorn is running in `backend/` on port `8000`. |
| **`500 Internal Server Error`** | Verify that valid Groq and Google Gemini API keys are entered in `backend/api.py`. |
| **Connection refused on physical device** | Ensure your mobile phone and PC are connected to the same Wi-Fi network, and change `_baseUrl` in `lib/services/chatbot_service.dart` to your PC's IP address. |

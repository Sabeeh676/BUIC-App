# 🎓 BU Chatbot Backend API

Python FastAPI backend server for the Bahria University student handbook RAG chatbot.

## 🛠️ Prerequisites

- **Python**: Version 3.9 or higher is required.
- **API Keys Required**:
  - Get your Groq API key from [Groq API Console](https://console.groq.com/keys).
  - Get your Google API key from [Google AI Studio](https://aistudio.google.com/app/apikey).

## 🚀 Installation & Usage

1. **Install required packages**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Configure API Keys**:
   Set `GROQ_API_KEY` and `GOOGLE_API_KEY` in `api.py`.

3. **Run FastAPI Server**:
   ```bash
   uvicorn api:app --host 0.0.0.0 --port 8000 --reload
   ```


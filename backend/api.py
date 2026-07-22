import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from contextlib import asynccontextmanager

from langchain_groq import ChatGroq
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.chains.combine_documents import create_stuff_documents_chain
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain.chains import create_retrieval_chain, create_history_aware_retriever
from langchain_core.messages import HumanMessage, AIMessage
from langchain_community.vectorstores import FAISS
from langchain_community.document_loaders import PyPDFLoader
from langchain_google_genai import GoogleGenerativeAIEmbeddings

# ─────────────────────────────────────────────
# 🔑  API Keys — replace with your actual keys
# ─────────────────────────────────────────────
GROQ_API_KEY    = "your_groq_api_key_here"
GOOGLE_API_KEY  = "your_google_api_key_here"

HANDBOOK_PATH   = "data/handbook.pdf"

# Global state
_retrieval_chain = None


def build_chain():
    """Load handbook PDF, create vector store, and build RAG chain with history memory."""
    os.environ["GOOGLE_API_KEY"] = GOOGLE_API_KEY

    llm = ChatGroq(groq_api_key=GROQ_API_KEY, model_name="gemma2-9b-it")

    embeddings = GoogleGenerativeAIEmbeddings(model="models/embedding-001")

    loader = PyPDFLoader(HANDBOOK_PATH)
    raw_docs = loader.load()

    splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
    documents = splitter.split_documents(raw_docs)

    vector_store = FAISS.from_documents(documents, embeddings)
    retriever = vector_store.as_retriever(search_kwargs={"k": 4})

    # History-aware question reformulator
    contextualize_q_system_prompt = (
        "Given a chat history and the latest user question "
        "which might reference context in the chat history, "
        "formulate a standalone question which can be understood "
        "without the chat history. Do NOT answer the question, "
        "just reformulate it if needed and otherwise return it as is."
    )

    contextualize_q_prompt = ChatPromptTemplate.from_messages(
        [
            ("system", contextualize_q_system_prompt),
            MessagesPlaceholder("chat_history"),
            ("human", "{input}"),
        ]
    )

    history_aware_retriever = create_history_aware_retriever(
        llm, retriever, contextualize_q_prompt
    )

    # QA Prompt with context and history
    qa_prompt = ChatPromptTemplate.from_messages(
        [
            (
                "system",
                "You are a helpful academic assistant for Bahria University Islamabad Campus (BUIC).\n"
                "Answer the student's question based ONLY on the provided handbook context.\n"
                "Be clear, concise, and student-friendly. If the answer is not in the context, say:\n"
                '"I couldn\'t find that information in the university handbook. Please contact the relevant department."\n\n'
                "<context>\n{context}\n</context>",
            ),
            MessagesPlaceholder("chat_history"),
            ("human", "{input}"),
        ]
    )

    question_answer_chain = create_stuff_documents_chain(llm, qa_prompt)
    return create_retrieval_chain(history_aware_retriever, question_answer_chain)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load the RAG chain once when the server starts."""
    global _retrieval_chain
    print("🔍 Loading handbook and building vector store...")
    _retrieval_chain = build_chain()
    print("✅ BU Chatbot API is ready!")
    yield
    print("🛑 Shutting down BU Chatbot API.")


app = FastAPI(
    title="BU Chatbot API",
    description="RAG-based chatbot for Bahria University handbook queries",
    version="1.0.0",
    lifespan=lifespan,
)

# Allow Flutter app (any origin) to call this API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─────────────────────────────────────────────
# Request / Response models
# ─────────────────────────────────────────────
class MessageTurn(BaseModel):
    role: str  # "user" or "assistant"
    content: str


class ChatRequest(BaseModel):
    question: str
    history: list[MessageTurn] = []


class SourceDoc(BaseModel):
    page_content: str
    page: int


class ChatResponse(BaseModel):
    answer: str
    sources: list[SourceDoc]


# ─────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────
@app.get("/")
def health_check():
    return {"status": "ok", "message": "BU Chatbot API is running 🎓"}


@app.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest):
    if not request.question.strip():
        raise HTTPException(status_code=400, detail="Question cannot be empty.")

    if _retrieval_chain is None:
        raise HTTPException(status_code=503, detail="Chatbot is not ready yet. Please try again.")

    formatted_history = []
    for msg in request.history:
        if msg.role == "user":
            formatted_history.append(HumanMessage(content=msg.content))
        elif msg.role == "assistant":
            formatted_history.append(AIMessage(content=msg.content))

    result = _retrieval_chain.invoke({
        "input": request.question,
        "chat_history": formatted_history,
    })

    sources = []
    for doc in result.get("context", []):
        sources.append(
            SourceDoc(
                page_content=doc.page_content[:500],  # trim for mobile
                page=doc.metadata.get("page", 0) + 1,
            )
        )

    return ChatResponse(answer=result["answer"], sources=sources)


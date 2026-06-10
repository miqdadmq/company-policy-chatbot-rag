# Company Policy Chatbot 🤖

An end-to-end RAG (Retrieval-Augmented Generation) chatbot that answers employee questions about company policies — built with Databricks, n8n, Qdrant, Groq, and Telegram.

---

## 🏗️ Architecture

```
PDF Documents
     │
     ▼
Databricks Community Edition
  ├── Parse & chunk PDFs (pdfplumber)
  ├── Generate embeddings (Gemini Embedding-2)
  └── Trigger webhook → n8n
     │
     ▼
n8n (self-hosted on VPS)
  ├── [Ingest Workflow]
  │     ├── Receive chunks from Databricks
  │     └── Store vectors → Qdrant
  │
  └── [Chat Workflow]
        ├── Telegram Trigger (user question)
        ├── Embed question (Gemini Embedding-2)
        ├── Vector search → Qdrant (top 5 chunks)
        ├── Build RAG prompt
        ├── Generate answer → Groq (Llama 3.1)
        └── Send answer → Telegram
```

---

## 🛠️ Tech Stack

| Component | Tool | Cost |
|---|---|---|
| Data Engineering | Databricks Community Edition | Free |
| PDF Parsing | pdfplumber | Free |
| Embedding Model | Gemini Embedding-2 | Free |
| Workflow Orchestration | n8n (self-hosted) | Free |
| Vector Database | Qdrant | Free |
| LLM | Groq — Llama 3.1 8b Instant | Free |
| Chat Interface | Telegram Bot | Free |
| VPS | InterServer (1 Core, 2GB RAM) | ~$6/month |
| Domain & SSL | Custom domain + Let's Encrypt | ~$1/month |

**Total cost: ~$7/month**

---

## 📁 Repository Structure

```
├── databricks/
│   └── company_policy_rag_notebook.py   # Databricks notebook
├── n8n/
│   └── 3_n8n_workflow.json              # n8n workflow (import-ready)
├── infra/
│   ├── 1_setup_vps.sh                   # VPS setup script
│   └── 2_docker_compose.yml             # Docker Compose (n8n + Qdrant)
└── README.md
```

---

## 🚀 How to Run

### Prerequisites
- Databricks Community Edition account
- Google AI Studio API key (for Gemini Embedding)
- Groq API key (for LLM)
- Telegram Bot token (from @BotFather)
- VPS with Ubuntu 24.04 (min 2GB RAM)
- Domain name

### Step 1 — Setup VPS
```bash
ssh root@YOUR_VPS_IP
bash infra/1_setup_vps.sh
```

### Step 2 — Run Docker (n8n + Qdrant)
```bash
cd /opt/chatbot
# Edit 2_docker_compose.yml — replace YOUR_VPS_IP and password
docker compose -f 2_docker_compose.yml up -d
```

### Step 3 — Setup Nginx + SSL
```bash
apt install -y nginx certbot python3-certbot-nginx
certbot --nginx -d yourdomain.com
```

### Step 4 — Create Qdrant Collection
```bash
curl -X PUT http://localhost:6333/collections/policy_chunks \
  -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 768, "distance": "Cosine"}}'
```

### Step 5 — Import n8n Workflow
1. Open n8n at `https://yourdomain.com`
2. Import `n8n/3_n8n_workflow.json`
3. Add credentials:
   - Gemini API key (HTTP Query Auth)
   - Groq API key (hardcoded in Code node)
   - Telegram Bot token
4. Click **Publish**

### Step 6 — Run Databricks Notebook
1. Upload PDF policy documents to Databricks
2. Open `databricks/company_policy_rag_notebook.py`
3. Fill in `GEMINI_API_KEY` and `N8N_WEBHOOK_URL` in Cell 2
4. Run all cells

### Step 7 — Test the Bot
Open Telegram → search your bot → send `/start` → ask a question!

---

## 💡 Key Design Decisions

**Why RAG instead of full-document approach?**
RAG retrieves only the most relevant chunks (~1,500 tokens) instead of sending all documents (~18,000 tokens) to the LLM on every query. This makes it 12x more cost-efficient and faster to respond.

**Why Groq instead of Gemini for generation?**
Groq's free tier is more generous and significantly faster for inference. Gemini is used only for embeddings where consistency matters most.

**Why Qdrant?**
Qdrant runs as a lightweight Docker container on the same VPS as n8n, avoiding the need for an external vector database service.

**Why Telegram instead of a web UI?**
Telegram provides a production-like interface that's instantly accessible to anyone without requiring login or setup — ideal for portfolio demos.

---

## 📊 Performance

- **Accuracy**: 10/10 questions answered correctly in testing
- **Response time**: ~5-8 seconds per query
- **Daily capacity**: ~500 queries/day (Groq free tier)
- **Documents supported**: Multiple PDFs (tested with 4 policy documents)

---

## 🔧 Configuration

Key parameters in `databricks/company_policy_rag_notebook.py`:

```python
CHUNK_SIZE    = 1200   # characters per chunk
CHUNK_OVERLAP = 200    # overlap between chunks
EMBEDDING_MODEL = "models/gemini-embedding-2"
OUTPUT_DIM    = 768    # embedding dimensions
```

---

## 📌 Future Improvements

- [ ] Add document update detection (auto re-ingest when PDF changes)
- [ ] Multi-language support (Bahasa Indonesia + English)
- [ ] Web UI using Streamlit for broader accessibility
- [ ] User feedback collection to improve retrieval accuracy
- [ ] Upgrade to paid tier for production use

---

## 👤 Author

Built as a portfolio project to demonstrate end-to-end AI engineering skills:
- Data Engineering (Databricks, Delta Lake)
- RAG Pipeline (chunking, embedding, vector search)
- LLM Integration (Gemini, Groq)
- DevOps (Docker, VPS, Nginx, SSL)
- Workflow Automation (n8n)

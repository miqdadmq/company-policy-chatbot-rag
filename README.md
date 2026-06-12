# Company Policy Chatbot 🤖

An end-to-end RAG (Retrieval-Augmented Generation) chatbot that answers employee questions about company policies — built with Databricks, n8n, Qdrant, Groq, and Telegram.

---

## 📊 Evaluation Results

| Setup | Accuracy | Avg Score | Accuracy | Completeness | Groundedness | Clarity |
|---|---|---|---|---|---|---|
| Baseline (top_k=5) | 76% | 3.8/5 | 4.2/5 | 3.2/5 | 4.2/5 | 5.0/5 |
| Improved (top_k=8) | **88%** | **4.4/5** | **5.0/5** | **4.4/5** | **5.0/5** | **5.0/5** |

**Key finding:** Completeness was identified as the main bottleneck (3.2/5). By tuning the retrieval parameter from `top_k=5` to `top_k=8`, overall accuracy improved from **76% → 88%** — a 12% gain with a single parameter change.

Evaluation methodology: **LLM-as-Judge** using Groq (Llama 3.1) as evaluator across 4 dimensions — accuracy, completeness, groundedness, and clarity. Results stored in Databricks Delta table for trend analysis.

---

## 🏗️ Architecture

```
PDF Documents
     │
     ▼
Databricks Community Edition
  ├── Parse & chunk PDFs (pdfplumber)
  ├── Generate embeddings (Gemini Embedding-2, 768 dim)
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
        ├── Vector search → Qdrant (top_k=8 chunks)
        ├── Build RAG prompt
        ├── Generate answer → Groq (Llama 3.1)
        └── Send answer + 👍👎 rating buttons → Telegram
```

---

## 🛠️ Tech Stack

| Component | Tool | Cost |
|---|---|---|
| Data Engineering | Databricks Community Edition | Free |
| PDF Parsing | pdfplumber | Free |
| Embedding Model | Gemini Embedding-2 (768 dim) | Free |
| Workflow Orchestration | n8n (self-hosted) | Free |
| Vector Database | Qdrant (self-hosted) | Free |
| LLM | Groq — Llama 3.1 8b Instant | Free |
| Chat Interface | Telegram Bot | Free |
| RAG Evaluation | LLM-as-Judge (Groq) | Free |
| VPS | InterServer (1 Core, 2GB RAM) | ~$3/month |
| Domain & SSL | Custom domain + Let's Encrypt | ~$1/year |

**Total cost: ~$3/month**

---

## 📁 Repository Structure

```
├── databricks/
│   ├── company_policy_rag_notebook.py   # PDF parsing, chunking, embedding
│   └── evaluation_notebook.py           # LLM-as-Judge evaluation
├── n8n/
│   └── 3_n8n_workflow.json              # n8n workflow (import-ready)
├── infra/
│   ├── 1_setup_vps.sh                   # VPS setup script (Ubuntu 24.04)
│   └── 2_docker_compose.yml             # Docker Compose (n8n + Qdrant)
└── README.md
```

---

## 🚀 How to Run

### Prerequisites
- Databricks Community Edition account
- Google AI Studio API key (Gemini Embedding)
- Groq API key (LLM generation + evaluation)
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
# Edit 2_docker_compose.yml — replace YOUR_DOMAIN and password
docker compose -f 2_docker_compose.yml up -d
```

### Step 3 — Setup Nginx + SSL
```bash
apt install -y nginx certbot python3-certbot-nginx
certbot --nginx -d your-domain.com
```

### Step 4 — Create Qdrant Collection
```bash
curl -X PUT http://localhost:6333/collections/policy_chunks \
  -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 768, "distance": "Cosine"}}'
```

### Step 5 — Import n8n Workflow
1. Open n8n at `https://your-domain.com`
2. Import `n8n/3_n8n_workflow.json`
3. Add credentials:
   - Gemini API key (HTTP Query Auth, name: `key`)
   - Groq API key (in Code node)
   - Telegram Bot token
4. Replace `YOUR_QDRANT_IP` with actual Qdrant container IP:
   ```bash
   docker inspect qdrant | grep IPAddress
   ```
5. Click **Publish**

### Step 6 — Run Databricks Notebook
1. Upload PDF policy documents to Databricks
2. Open `databricks/company_policy_rag_notebook.py`
3. Fill in `GEMINI_API_KEY` and `N8N_WEBHOOK_URL` in Cell 2
4. Run all cells

### Step 7 — Evaluate Accuracy (optional)
1. Open `databricks/evaluation_notebook.py`
2. Fill in `GEMINI_API_KEY`, `GROQ_API_KEY`, and `QDRANT_URL`
3. Update test questions in Cell 3 to match your policy documents
4. Run all cells

### Step 8 — Test the Bot
Open Telegram → search your bot → send `/start` → ask a question!

---

## 💡 Key Design Decisions

**Why RAG instead of full-document approach?**
RAG retrieves only the most relevant chunks (~1,500 tokens) instead of sending all documents (~18,000 tokens) to the LLM on every query — 12x more token-efficient and significantly faster.

**Why top_k=8?**
Evaluation showed completeness improved from 3.2/5 to 4.4/5 when increasing from top_k=5 to top_k=8. Policy information is often spread across multiple chunks, so retrieving more context leads to more complete answers.

**Why Groq instead of Gemini for generation?**
Groq's free tier is more generous and significantly faster for inference. Gemini is used only for embeddings where model consistency matters.

**Why Qdrant?**
Runs as a lightweight Docker container on the same VPS as n8n — no external vector database service needed, keeping costs minimal.

**Why Telegram instead of a web UI?**
Telegram provides a production-like interface instantly accessible to anyone without login or setup — ideal for portfolio demos and real-world deployment.

**Why LLM-as-Judge for evaluation?**
More practical than RAGAS for self-hosted setups — no dependency conflicts, produces interpretable scores with reasoning, and works without a pre-defined ground truth dataset.

---

## 📈 Evaluation

The system is evaluated using **LLM-as-Judge** on a test dataset of 5 questions:

```
Score dimensions : Accuracy | Completeness | Groundedness | Clarity
Scale            : 1-5 per dimension
Evaluator model  : Groq (Llama 3.1 8b)
Results stored in: policy_eval_results (Databricks Delta table)
```

To run evaluation:
```bash
# In Databricks, run evaluation_notebook.py
# Results will be saved to Delta table and printed to console
```

---

## 🔧 Configuration

Key parameters in `databricks/company_policy_rag_notebook.py`:

```python
CHUNK_SIZE      = 1200  # characters per chunk
CHUNK_OVERLAP   = 200   # overlap between chunks
EMBEDDING_MODEL = "models/gemini-embedding-2"
OUTPUT_DIM      = 768   # embedding dimensions
```

Key parameters in n8n Qdrant Search node:
```javascript
top: 8,               // number of chunks to retrieve
score_threshold: 0.3  // minimum similarity score
```

---

## 📌 Future Improvements

- [ ] Hybrid search (vector + BM25 keyword) for better recall
- [ ] Query expansion — paraphrase question before retrieval
- [ ] Reranking — re-score retrieved chunks before passing to LLM
- [ ] Multi-language support (Bahasa Indonesia + English)
- [ ] Auto re-ingest when PDF documents are updated
- [ ] Web UI using Streamlit for broader accessibility
- [ ] Upgrade to paid tier for production scale

---

## 👤 Miqdad

Built as a portfolio project to demonstrate end-to-end AI engineering skills:
- **Data Engineering** — Databricks, Delta Lake, PDF processing
- **RAG Pipeline** — chunking, embedding, vector search, prompt engineering
- **LLM Integration** — Gemini, Groq, LLM-as-Judge evaluation
- **DevOps** — Docker, VPS, Nginx, SSL, self-hosted deployment
- **Workflow Automation** — n8n, webhook-based pipeline
- **Evaluation** — systematic accuracy measurement and iterative improvement

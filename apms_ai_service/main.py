import os
import re
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from langchain_groq import ChatGroq
# LangChain Imports
from langchain_community.utilities import SQLDatabase
from langchain_openai import ChatOpenAI
# from langchain.chains import create_sql_query_chain
# from langchain_community.chains import create_sql_query_chain
from langchain_classic.chains import create_sql_query_chain
from langchain_core.prompts import PromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough
from sqlalchemy import create_engine

load_dotenv()

app = FastAPI(title="APMS AI Command Center", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 1. Database Connection (SQLAlchemy)
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "postgres")

# It's recommended to create a read-only user in PostgreSQL for this service,
# but for the sake of this code, we enforce SELECT-only at the application level.
DB_URI = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# Read-only SQLAlchemy engine setup (if the DB user is not already restricted)
engine = create_engine(DB_URI)
db = SQLDatabase(engine)

# 2. LLM Initialization
llm = ChatGroq(
    model="llama-3.3-70b-versatile", 
    groq_api_key=os.getenv("GROQ_API_KEY")
)

# 3. Prompt Template with Strict Guardrails
prompt_template = """
You are an expert PostgreSQL data analyst for a Pharmacy Management System.
Given an input question, create a syntactically correct PostgreSQL query to run.
Unless the user specifies a specific number of examples they wish to obtain, always limit your query to at most {top_k} results.
You can order the results by a relevant column to return the most interesting examples in the database.

IMPORTANT GUARDRAILS:
1. You MUST ONLY output a SELECT statement.
2. NEVER generate queries containing INSERT, UPDATE, DELETE, DROP, ALTER, CREATE, TRUNCATE, or GRANT.
3. If the user asks you to modify data or perform any destructive action, you must refuse and return a SELECT query that simply selects the string 'UNAUTHORIZED_ACTION'.
4. Do NOT wrap the query in markdown block formatting like ```sql or ```. Only output the raw SQL query.

Only use the following tables:
{table_info}

Question: {input}
"""
prompt = PromptTemplate.from_template(prompt_template)

# Create the SQL Query generation chain
generate_query_chain = create_sql_query_chain(llm, db, prompt=prompt)

# Final formatting chain
answer_prompt = PromptTemplate.from_template(
    """Given the following user question, corresponding SQL query, and SQL result, answer the user question in a friendly, helpful, and concise manner.
Focus on the insights from the data.

Question: {question}
SQL Query: {query}
SQL Result: {result}
Answer: """
)

class ChatRequest(BaseModel):
    query: str

class ChatResponse(BaseModel):
    answer: str
    sql_query: str
    raw_result: str

def execute_query(query: str):
    """Safely executes the query after verifying it is a SELECT statement."""
    clean_query = query.strip()
    # Basic safety check (fallback if LLM guardrails fail)
    if not re.match(r"^SELECT\b", clean_query, re.IGNORECASE):
        raise ValueError("Only SELECT queries are allowed. Action blocked by security policy.")
    
    # Execute query
    try:
        result = db.run(clean_query)
        return result
    except Exception as e:
        return str(e)


@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(request: ChatRequest):
    try:
        user_query = request.query
        
        # Step 1: Generate SQL Query
        generated_sql = generate_query_chain.invoke({"question": user_query})
        
        # Step 2: Execute SQL securely
        try:
            sql_result = execute_query(generated_sql)
        except ValueError as e:
             return ChatResponse(
                answer=f"I cannot perform that action. {str(e)}",
                sql_query="BLOCKED",
                raw_result=""
            )
             
        if sql_result == "UNAUTHORIZED_ACTION":
            return ChatResponse(
                answer="I am an AI assistant and I am restricted to read-only operations to protect your data. I cannot modify the database.",
                sql_query=generated_sql,
                raw_result=""
            )
            
        # Step 3: Generate Natural Language Answer
        final_answer_chain = answer_prompt | llm | StrOutputParser()
        answer = final_answer_chain.invoke({
            "question": user_query,
            "query": generated_sql,
            "result": sql_result
        })
        
        return ChatResponse(
            answer=answer,
            sql_query=generated_sql,
            raw_result=str(sql_result)
        )
        
    except Exception as e:
        print(f"Error in chat endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

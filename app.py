import streamlit as st
import boto3
from botocore.exceptions import ClientError
import json
from bedrock_utils import query_knowledge_base, generate_response


# Streamlit UI
st.title("Bedrock Chat Application")

# Sidebar for configurations
st.sidebar.header("Configuration")
model_id = st.sidebar.selectbox("Select LLM Model", ["anthropic.claude-v2", "ai21.j2-ultra", "amazon.titan-text-express-v1"])
kb_id = st.sidebar.text_input("Knowledge Base ID", "your-knowledge-base-id")
temperature = st.sidebar.select_slider("Temperature", [i/10 for i in range(0,11)])
top_p = st.sidebar.select_slider("Top_P", [i/1000 for i in range(0,1001)])

# Initialize chat history
if "messages" not in st.session_state:
    st.session_state.messages = []

# Display chat messages
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])

# Chat input
if prompt := st.chat_input("What would you like to know?"):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    # Query Knowledge Base
    kb_results = query_knowledge_base(prompt, kb_id)
    
    # Prepare context from Knowledge Base results
    context = "\n".join([result['content']['text'] for result in kb_results])
    
    # Generate response using LLM
    full_prompt = f"Human:Context: {context}\n\nUser: {prompt}\n\nAssistant:"
    response = generate_response(full_prompt, model_id, temperature, top_p)
    
    # Display assistant response
    with st.chat_message("assistant"):
        st.markdown(response)
    st.session_state.messages.append({"role": "assistant", "content": response})
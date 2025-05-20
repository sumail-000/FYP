import sys
import subprocess
import pkg_resources
import os
import time
import threading

# Check and install required packages
required_packages = ['flask', 'flask-cors', 'pyngrok', 'requests', 'PyPDF2', 'pillow']
installed_packages = [pkg.key for pkg in pkg_resources.working_set]

missing_packages = [pkg for pkg in required_packages if pkg.lower() not in installed_packages]

if missing_packages:
    print(f"Installing missing packages: {', '.join(missing_packages)}")
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', *missing_packages])
    print("All required packages installed successfully!")

from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import requests
import json

# Import document processing module
import document_processor

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# FastChat settings
FASTCHAT_HOST = "http://localhost:8000"  # Default FastChat server address
API_PREFIX = "/v1/chat/completions"

# ngrok settings
NGROK_AUTH_TOKEN = ""  # Will be set via command line arg
NGROK_URL = ""  # Will be updated after ngrok starts

# Flag to check if FastChat is already set up
fastchat_setup_complete = False

def setup_fastchat():
    """Set up and start FastChat model and API server"""
    global fastchat_setup_complete
    
    if fastchat_setup_complete:
        print("FastChat is already set up.")
        return
    
    print("Setting up FastChat...")
    
    # Check if FastChat is already cloned
    if not os.path.exists("FastChat"):
        print("Cloning FastChat repository...")
        subprocess.run(["git", "clone", "https://github.com/lm-sys/FastChat.git"], check=True)
    
    # Install FastChat
    print("Installing FastChat...")
    os.chdir("FastChat")
    subprocess.run([sys.executable, "-m", "pip", "install", "--upgrade", "pip"], check=True)
    subprocess.run([sys.executable, "-m", "pip", "install", "-e", ".[model_worker,webui]"], check=True)
    
    # Start controller in background
    print("Starting FastChat controller...")
    controller_process = subprocess.Popen(
        [sys.executable, "-m", "fastchat.serve.controller"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    
    # Wait for controller to start
    time.sleep(5)
    
    # Start model worker in background
    print("Starting FastChat model worker (this might take a while to load the model)...")
    model_worker_process = subprocess.Popen(
        [sys.executable, "-m", "fastchat.serve.model_worker", "--model-path", "lmsys/vicuna-7b-v1.5"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    
    # Wait for model worker to start
    time.sleep(10)
    
    # Start API server in background
    print("Starting FastChat API server...")
    api_server_process = subprocess.Popen(
        [sys.executable, "-m", "fastchat.serve.openai_api_server", "--host", "0.0.0.0", "--port", "8000"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    
    # Wait for API server to start
    time.sleep(5)
    
    # Change back to original directory
    os.chdir("..")
    
    # Check if API server is running
    try:
        response = requests.get(f"{FASTCHAT_HOST}/health")
        if response.status_code == 200:
            print("FastChat API server is running!")
            fastchat_setup_complete = True
        else:
            print(f"FastChat API server returned status code: {response.status_code}")
    except requests.exceptions.ConnectionError:
        print("Warning: Could not connect to FastChat API server. It might still be starting up.")
        # We'll still set this to True as the server might just need more time
        fastchat_setup_complete = True
    
    print("FastChat setup complete!")

def start_ngrok(auth_token, port):
    """Start ngrok and get the public URL"""
    global NGROK_URL
    
    # Check if ngrok is installed
    try:
        subprocess.run(["ngrok", "--version"], check=True, capture_output=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("ngrok is not installed. Please install it first.")
        sys.exit(1)
    
    # Set ngrok auth token
    subprocess.run(["ngrok", "config", "add-authtoken", auth_token], check=True)
    
    # Start ngrok in a separate process
    ngrok_process = subprocess.Popen(
        ["ngrok", "http", str(port)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    
    # Wait for ngrok to initialize
    time.sleep(2)
    
    # Get ngrok URL from API
    try:
        response = requests.get("http://localhost:4040/api/tunnels")
        tunnels = response.json()["tunnels"]
        if tunnels:
            NGROK_URL = tunnels[0]["public_url"]
            print(f"ngrok URL: {NGROK_URL}")
            return True
    except Exception as e:
        print(f"Error getting ngrok URL: {e}")
    
    print("Failed to start ngrok or get URL")
    return False

@app.route('/update_api_url', methods=['GET'])
def get_api_url():
    """Return the current ngrok URL for the app to use"""
    return jsonify({"url": f"{NGROK_URL}/chat"})

@app.route('/chat', methods=['POST'])
def chat():
    """Handle chat requests from the app and forward to FastChat"""
    try:
        data = request.json
        message = data.get('message', '')
        conversation_history = data.get('conversation_history', [])
        
        # Format the conversation history for FastChat
        messages = []
        
        # Add system message if not present
        if not conversation_history or conversation_history[0].get('role') != 'SYSTEM':
            messages.append({
                "role": "system",
                "content": "You are a helpful AI assistant."
            })
        
        # Add conversation history
        for msg in conversation_history:
            role = "user" if msg.get('role') == "USER" else "assistant"
            messages.append({
                "role": role,
                "content": msg.get('content', '')
            })
        
        # If the last message in history isn't the current message, add it
        if not messages or messages[-1]['content'] != message:
            messages.append({
                "role": "user",
                "content": message
            })
        
        # Prepare the request to FastChat
        fastchat_payload = {
            "model": "vicuna-7b-v1.5",
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 800
        }
        
        # Send request to FastChat
        fastchat_response = requests.post(
            f"{FASTCHAT_HOST}{API_PREFIX}",
            json=fastchat_payload,
            timeout=60
        )
        
        if fastchat_response.status_code == 200:
            response_data = fastchat_response.json()
            assistant_message = response_data['choices'][0]['message']['content']
            return jsonify({"response": assistant_message})
        else:
            print(f"FastChat error: {fastchat_response.status_code} - {fastchat_response.text}")
            return jsonify({"error": f"Error from FastChat: {fastchat_response.text}"}), 500
            
    except Exception as e:
        print(f"Error in chat endpoint: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/process_document', methods=['POST'])
def process_document():
    """Handle document upload and processing by forwarding to the document processor"""
    try:
        # Check if file is in the request
        if 'file' not in request.files:
            return jsonify({"error": "No file provided"}), 400
            
        file = request.files['file']
        
        # Process the document upload using the document processor module
        result, status_code = document_processor.handle_document_upload(file, request.form, NGROK_URL)
        
        return jsonify(result), status_code
        
    except Exception as e:
        print(f"Error processing document upload: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/document_status/<doc_id>', methods=['GET'])
def get_document_status(doc_id):
    """Get the processing status of a document"""
    try:
        result, status_code = document_processor.get_document_status_data(doc_id)
        return jsonify(result), status_code
        
    except Exception as e:
        print(f"Error getting document status: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/document_text/<doc_id>', methods=['GET'])
def get_document_text(doc_id):
    """Get the extracted text of a document"""
    try:
        result, status_code = document_processor.get_document_text_data(doc_id)
        return jsonify(result), status_code
        
    except Exception as e:
        print(f"Error getting document text: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/document_image/<filename>', methods=['GET'])
def get_document_image(filename):
    """Get a document image"""
    try:
        image_path = document_processor.get_image_path(filename)
        return send_from_directory(os.path.dirname(image_path), os.path.basename(image_path))
    except Exception as e:
        print(f"Error getting document image: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    print("=== AcademiaHub API Server ===")
    print("This server connects your Flutter app to the FastChat model and handles document processing")
    
    # Get ngrok auth token from command line
    if len(sys.argv) > 1:
        NGROK_AUTH_TOKEN = sys.argv[1]
    else:
        print("Usage: python flask_api.py <ngrok_auth_token>")
        sys.exit(1)
    
    # Start FastChat in the background
    fastchat_thread = threading.Thread(target=setup_fastchat)
    fastchat_thread.daemon = True
    fastchat_thread.start()
    
    # Start document processing 
    document_processor.start_document_processing()
    
    # Wait for FastChat to initialize (can be adjusted)
    print("Waiting for FastChat to initialize...")
    time.sleep(10)
    
    # Start ngrok with Flask port
    port = 5000
    print("Starting ngrok tunnel...")
    if start_ngrok(NGROK_AUTH_TOKEN, port):
        # Print instructions for Flutter app
        print("\n=== FLUTTER APP SETUP ===")
        print(f"Chatbot URL: {NGROK_URL}/chat")
        print(f"Document Processing URL: {NGROK_URL}/process_document")
        print("These URLs will expire when this script stops running or when ngrok restarts")
        print("===========================\n")
        
        # Start Flask app
        print("Starting Flask server...")
        app.run(host='0.0.0.0', port=port)
    else:
        print("Failed to start ngrok. Exiting.") 
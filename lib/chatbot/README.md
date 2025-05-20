# AcademiaHub API Server

This API server provides both chatbot and document processing capabilities for the AcademiaHub Flutter app.

## Features

1. **AI Chatbot**
   - Connects to a FastChat AI model (Vicuna 7B)
   - Maintains conversation history
   - Handles responses and errors gracefully

2. **Document Processing**
   - Processes multiple document types (PDF, TXT, images)
   - Extracts text and images from documents
   - Maintains a queue for processing multiple documents
   - Provides status updates

## Prerequisites

- Python 3.7+
- ngrok account with auth token
- FastChat dependencies (will be installed automatically)

## Setup

1. Install ngrok: https://ngrok.com/download
2. Clone this repository
3. Run the API server with your ngrok auth token:

```bash
python flask_api.py your-ngrok-auth-token
```

## API Endpoints

### Chatbot

- **GET /update_api_url**: Returns the current ngrok URL for the app to use
- **POST /chat**: Handles chat requests from the app

### Document Processing

- **POST /process_document**: Uploads and processes documents
- **GET /document_status/{doc_id}**: Checks the status of a document process
- **GET /document_text/{doc_id}**: Retrieves the extracted text from a document
- **GET /document_image/{filename}**: Retrieves an image extracted from a document

## File Structure

- `flask_api.py`: Main Flask API server
- `document_processor.py`: Document processing functionality
- `document_data/`: Directory where processed documents are stored
  - `texts/`: Extracted text files
  - `images/`: Extracted images
  - `documents_data.json`: Database of processed documents

## Usage in Flutter App

The Flutter app automatically detects the API URL from the chatbot settings. The document processing backend will use the same base URL with different endpoints.

## Notes

- The ngrok URL will change each time the server is restarted
- The processing queue is in-memory and will be lost if the server restarts
- For production use, consider using a persistent queue and database 
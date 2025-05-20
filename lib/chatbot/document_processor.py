import os
import uuid
import json
import time
from queue import Queue
from threading import Thread
import PyPDF2
from PIL import Image
from werkzeug.utils import secure_filename

# Document processing settings
UPLOAD_FOLDER = 'document_data'
ALLOWED_EXTENSIONS = {'pdf', 'doc', 'docx', 'txt', 'png', 'jpg', 'jpeg'}

# Document processing queue and status tracking
document_queue = Queue()
document_status = {}
documents_data_file = os.path.join(UPLOAD_FOLDER, 'documents_data.json')

# Initialize folders
def init_document_folders():
    """Create necessary folders for document processing"""
    os.makedirs(UPLOAD_FOLDER, exist_ok=True)
    os.makedirs(os.path.join(UPLOAD_FOLDER, 'images'), exist_ok=True)
    os.makedirs(os.path.join(UPLOAD_FOLDER, 'texts'), exist_ok=True)

# Load existing document data if available
def load_documents_data():
    """Load existing document data from file"""
    if os.path.exists(documents_data_file):
        try:
            with open(documents_data_file, 'r') as f:
                return json.load(f)
        except:
            return {}
    else:
        return {}

documents_data = load_documents_data()

def allowed_file(filename):
    """Check if file extension is allowed"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def process_document_worker():
    """Worker thread to process documents from the queue"""
    print("Document processing worker started")
    while True:
        # Get document from queue
        doc_id = document_queue.get()
        
        if doc_id is None:  # Poison pill to stop thread
            break
            
        try:
            # Update status to processing
            document_status[doc_id] = "processing"
            
            # Get document data
            doc_data = documents_data.get(doc_id, {})
            
            if not doc_data:
                print(f"Error: No data found for document {doc_id}")
                document_status[doc_id] = "error"
                document_queue.task_done()
                continue
                
            # Process document based on file type
            filepath = doc_data.get('filepath')
            file_ext = filepath.split('.')[-1].lower()
            
            # Create doc directory if needed
            doc_dir = os.path.join(UPLOAD_FOLDER, doc_id)
            os.makedirs(doc_dir, exist_ok=True)
            
            # Extract text and images
            text_content = ""
            images = []
            
            if file_ext == 'pdf':
                text_content, images = process_pdf(filepath, doc_dir)
            elif file_ext in ['png', 'jpg', 'jpeg']:
                text_content, images = process_image(filepath, doc_dir)
            elif file_ext in ['txt']:
                with open(filepath, 'r', errors='ignore') as f:
                    text_content = f.read()
            elif file_ext in ['doc', 'docx']:
                # Note: For simplicity, we're not implementing docx processing here
                # In a production app, you would use a library like python-docx
                text_content = f"Document processing for {file_ext} files not implemented yet"
            
            # Save text content
            text_file = os.path.join(UPLOAD_FOLDER, 'texts', f"{doc_id}.txt")
            with open(text_file, 'w', encoding='utf-8') as f:
                f.write(text_content)
                
            # Update document data
            doc_data['text_file'] = text_file
            doc_data['image_count'] = len(images)
            doc_data['images'] = images
            doc_data['processing_complete'] = True
            doc_data['status'] = 'completed'
            
            # Save updated document data
            documents_data[doc_id] = doc_data
            save_documents_data()
                
            # Update status to completed
            document_status[doc_id] = "completed"
            print(f"Document {doc_id} processed successfully")
            
        except Exception as e:
            print(f"Error processing document {doc_id}: {str(e)}")
            document_status[doc_id] = "error"
            
        finally:
            document_queue.task_done()

def save_documents_data():
    """Save documents data to file"""
    with open(documents_data_file, 'w') as f:
        json.dump(documents_data, f, indent=2)

def process_pdf(filepath, doc_dir):
    """Process a PDF file to extract text and images"""
    text_content = ""
    images = []
    
    try:
        # Open the PDF
        with open(filepath, 'rb') as file:
            reader = PyPDF2.PdfReader(file)
            
            # Process each page
            for i, page in enumerate(reader.pages):
                # Extract text
                page_text = page.extract_text()
                if page_text:
                    text_content += f"\n--- Page {i+1} ---\n{page_text}\n"
                    
                # Extract images (if available)
                # Note: This is a simplified approach and may not extract all images
                if '/XObject' in page['/Resources']:
                    xobject = page['/Resources']['/XObject']
                    for obj in xobject:
                        if xobject[obj]['/Subtype'] == '/Image':
                            try:
                                # Save image
                                img_dir = os.path.join(UPLOAD_FOLDER, 'images')
                                img_name = f"{uuid.uuid4()}.png"
                                img_path = os.path.join(img_dir, img_name)
                                
                                # This is a simplified approach
                                # In production, you'd need more robust PDF image extraction
                                with open(img_path, 'wb') as img_file:
                                    img_file.write(xobject[obj].getData())
                                    
                                images.append({
                                    'path': img_path,
                                    'page': i+1,
                                    'filename': img_name
                                })
                            except Exception as e:
                                print(f"Error extracting image: {str(e)}")
        
        return text_content, images
    except Exception as e:
        print(f"Error processing PDF: {str(e)}")
        return f"Error processing PDF: {str(e)}", []

def process_image(filepath, doc_dir):
    """Process an image file to save it and potentially extract text"""
    try:
        # Create a copy in the images directory
        img_dir = os.path.join(UPLOAD_FOLDER, 'images')
        img_name = f"{uuid.uuid4()}.png"
        img_path = os.path.join(img_dir, img_name)
        
        # Open and save the image
        with Image.open(filepath) as img:
            img.save(img_path)
            
        # In a production app, you would use OCR to extract text from the image
        # For now, we'll just return a placeholder
        text_content = f"[Image file: {os.path.basename(filepath)}]"
        
        images = [{
            'path': img_path,
            'page': 1,
            'filename': img_name
        }]
        
        return text_content, images
    except Exception as e:
        print(f"Error processing image: {str(e)}")
        return f"Error processing image: {str(e)}", []

def handle_document_upload(file, form_data, ngrok_url):
    """Handle document upload and add to processing queue"""
    try:
        # Check if file is valid
        if file.filename == '':
            return {"error": "No file selected"}, 400
            
        if not allowed_file(file.filename):
            return {
                "error": f"File type not allowed. Allowed types: {', '.join(ALLOWED_EXTENSIONS)}"
            }, 400
            
        # Generate a unique document ID
        doc_id = str(uuid.uuid4())
        
        # Create document directory
        doc_dir = os.path.join(UPLOAD_FOLDER, doc_id)
        os.makedirs(doc_dir, exist_ok=True)
        
        # Save file
        filename = secure_filename(file.filename)
        filepath = os.path.join(doc_dir, filename)
        file.save(filepath)
        
        # Get metadata from request
        metadata = {
            "title": form_data.get('title', filename),
            "description": form_data.get('description', ''),
            "category": form_data.get('category', ''),
            "tags": form_data.get('tags', ''),
            "user_id": form_data.get('user_id', ''),
            "upload_date": time.strftime("%Y-%m-%d %H:%M:%S"),
        }
        
        # Store document data
        documents_data[doc_id] = {
            "doc_id": doc_id,
            "filepath": filepath,
            "filename": filename,
            "metadata": metadata,
            "processing_complete": False,
            "status": "queued"
        }
        
        # Save document data to file
        save_documents_data()
            
        # Set initial status
        document_status[doc_id] = "queued"
        
        # Add to processing queue
        document_queue.put(doc_id)
        
        # Create status URL
        status_url = f"{ngrok_url}/document_status/{doc_id}"
        
        return {
            "success": True,
            "message": "Document received and queued for processing",
            "document_id": doc_id,
            "status_url": status_url
        }, 200
        
    except Exception as e:
        print(f"Error processing document upload: {str(e)}")
        return {"error": str(e)}, 500

def get_document_status_data(doc_id):
    """Get status information for a document"""
    try:
        # Check if document exists
        if doc_id not in documents_data:
            return {"error": "Document not found"}, 404
            
        # Get document data
        doc_data = documents_data[doc_id]
        
        # Get status
        status = document_status.get(doc_id, "unknown")
        
        # Return status and basic metadata
        result = {
            "document_id": doc_id,
            "status": status,
            "filename": doc_data.get("filename", ""),
            "metadata": doc_data.get("metadata", {}),
        }
        
        # If processing is complete, add more data
        if doc_data.get("processing_complete", False):
            result["processing_complete"] = True
            result["image_count"] = doc_data.get("image_count", 0)
            result["text_available"] = "text_file" in doc_data
            if "images" in doc_data and doc_data["images"]:
                result["images"] = [img["filename"] for img in doc_data["images"]]
        
        return result, 200
        
    except Exception as e:
        print(f"Error getting document status: {str(e)}")
        return {"error": str(e)}, 500

def get_document_text_data(doc_id):
    """Get extracted text for a document"""
    try:
        # Check if document exists
        if doc_id not in documents_data:
            return {"error": "Document not found"}, 404
            
        # Get document data
        doc_data = documents_data[doc_id]
        
        # Check if text is available
        if not doc_data.get("processing_complete", False) or "text_file" not in doc_data:
            return {
                "error": "Text not available yet. Document processing may still be in progress."
            }, 400
            
        # Get text content
        text_file = doc_data["text_file"]
        with open(text_file, 'r', encoding='utf-8') as f:
            text_content = f.read()
            
        return {
            "document_id": doc_id,
            "filename": doc_data.get("filename", ""),
            "text_content": text_content
        }, 200
        
    except Exception as e:
        print(f"Error getting document text: {str(e)}")
        return {"error": str(e)}, 500

def get_image_path(filename):
    """Get the path to an image file"""
    return os.path.join(UPLOAD_FOLDER, 'images', filename)

def start_document_processing():
    """Initialize and start the document processing worker"""
    init_document_folders()
    
    # Start document processing worker thread
    doc_thread = Thread(target=process_document_worker)
    doc_thread.daemon = True
    doc_thread.start()
    
    return doc_thread 
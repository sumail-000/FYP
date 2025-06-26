# Academia Hub

<p align="center">
  <img src="assets/Logo.png" alt="Academia Hub Logo" width="200"/>
</p>

<p align="center">
  A feature-rich, social learning platform designed to connect students and educators, facilitating seamless resource sharing and collaborative learning.
</p>

---

## ✨ Key Features

Academia Hub is more than just a file-sharing app; it's a comprehensive ecosystem designed to enhance the academic journey.

### 📚 Core Functionality

- **Advanced Document Sharing**: Upload and access study materials, notes, and assignments.
- **Powerful Search & Filtering**: A sophisticated dashboard allows users to filter documents by university, department, semester, and course. Content can also be sorted by name, date, file size, and more.
- **Multi-File Upload**: A dedicated upload manager allows for selecting and tagging multiple files at once.
- **Intelligent Metadata Management**: The system uses a Levenshtein distance algorithm to check for semantic similarity when users add new metadata (like courses or departments), preventing duplicate entries and ensuring data consistency.
- **View & Manage Uploads**: Users have a personal dashboard to view, edit, and delete their own contributions.
- **File Downloads**: Users can download resources directly to their device for offline access.

### 👥 Social & Community

- **Real-time Presence**: See which users are currently online and what they are doing within the app (e.g., "in chat with John Doe").
- **Friends System**: Send, receive, and manage friend requests to build your academic network.
- **Pin Friends**: Pin up to three friends for quick access at the top of your friends list.
- **Public Chatroom**: A general chatroom for all users to engage in community discussions.
- **Private Chat**: Secure, one-on-one messaging between friends, complete with read receipts.
- **User Profiles**: View other users' profiles to see their contributions, stats, and earned badges before connecting.

### 🏆 Gamification

- **Activity Points**: Earn points for performing actions that benefit the community, such as:
  - Completing your profile.
  - Verifying a university email.
  - Logging in daily (with a streak system).
  - Uploading new resources.
  - Connecting with friends.
- **Achievement Badges**: Unlock a series of badges (from "Newcomer" to "Academic Leader") as you accumulate points, showcasing your dedication and contributions.
- **Progress Tracking**: A dedicated screen visualizes your points history, streak progress, and shows you how to earn more points.

### 🤖 AI-Powered Features

- **AI Chatbot**: An integrated AI assistant, powered by a Vicuna 7B language model, to help users.
- **Document Processing Backend**: A Python backend capable of processing documents to support AI features.

---

## 🛠️ Technology Stack

The application is built using a modern and scalable technology stack.

- **Frontend**:
  - [Flutter](https://flutter.dev/)
- **Backend & Database**:
  - [Firebase](https://firebase.google.com/):
    - **Authentication**: Firebase Auth (Email/Password, Google Sign-In)
    - **Database**: Cloud Firestore
- **File Storage**:
  - [Cloudinary](https://cloudinary.com/) for cloud-based media storage, optimization, and delivery.
- **AI Backend**:
  - [Python](https://www.python.org/) with [Flask](https://flask.palletsprojects.com/)
  - **AI Model**: Vicuna 7B
  - **Tunneling**: [ngrok](https://ngrok.com/) (for development)
- **Key Flutter Packages**:
  - `firebase_core`, `firebase_auth`, `cloud_firestore`
  - `google_sign_in`
  - `cloudinary_public`, `dio` (for robust file uploads)
  - `file_picker`, `image_picker`, `open_file`
  - `csv` (for parsing university data)
  - `shared_preferences`

---

## 🚀 Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

- Flutter SDK
- A Firebase project
- A Cloudinary account
- Python 3.7+ (for the AI backend)

### Installation & Setup

1.  **Clone the repo:**
    ```sh
    git clone https://github.com/your-username/academia-hub.git
    ```
2.  **Set up Firebase:**
    - Create a Firebase project.
    - Add an Android/iOS app to your Firebase project.
    - Download the `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS) and place them in the appropriate directories.
3.  **Set up Cloudinary:**
    - Create a Cloudinary account.
    - In `assets/config/`, create a `cloudinary_credentials.yaml` file with your credentials:
      ```yaml
      cloud_name: 'YOUR_CLOUD_NAME'
      upload_preset: 'YOUR_UPLOAD_PRESET'
      api_key: 'YOUR_API_KEY'
      api_secret: 'YOUR_API_SECRET'
      ```
4.  **Install Flutter dependencies:**
    ```sh
    flutter pub get
    ```
5.  **Run the app:**
    ```sh
    flutter run
    ```
6.  **Run the AI Backend (Optional):**
    - Navigate to the `lib/chatbot` directory.
    - Install Python dependencies.
    - Run the Flask API with your ngrok token as described in `lib/chatbot/README.md`.

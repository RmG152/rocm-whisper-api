import requests
import os
import argparse
import mimetypes

# API server address
API_URL = "http://localhost:8080/transcribe"

def get_mime_type(file_path):
    """Guess MIME type based on file path."""
    mime_type, _ = mimetypes.guess_type(file_path)
    if mime_type:
        return mime_type
    
    # If guessing fails, return a general type based on extension
    ext = os.path.splitext(file_path)[1].lower()
    if ext == '.m4a':
        return 'audio/mp4'
    if ext == '.mp3':
        return 'audio/mpeg'
    if ext == '.wav':
        return 'audio/wav'
    # Default
    return 'application/octet-stream'

def test_transcribe_api(file_path):
    """
    Send a specified audio file to the Whisper API server and print the result.
    """
    # 1. Check if the file exists
    if not os.path.exists(file_path):
        print(f"Error: Test file not found. '{file_path}'")
        return

    # 2. Dynamically determine the file's MIME type
    mime_type = get_mime_type(file_path)
    print(f"File: '{os.path.basename(file_path)}', MIME type: '{mime_type}'")

    # 3. Open the file in binary read mode ('rb')
    with open(file_path, 'rb') as f:
        files = {'file': (os.path.basename(file_path), f, mime_type)}
        
        print(f"Sending file to API server ({API_URL})...")
        
        try:
            # 4. Send POST request using the requests library
            response = requests.post(API_URL, files=files, timeout=300)

            # 5. Process the response
            if response.status_code == 200:
                result = response.json()
                print("\n--- Transcription successful ---")
                print(f"Filename: {result.get('filename')}")
                print(f"Detected language: {result.get('language')}")
                print(f"Transcribed text: {result.get('text')}")
            else:
                print(f"\n--- Error occurred ---")
                print(f"Status code: {response.status_code}")
                print(f"Error details: {response.text}")

        except requests.exceptions.RequestException as e:
            print(f"\n--- Error occurred during API request ---")
            print(f"Could not connect to server or request failed: {e}")

if __name__ == "__main__":
    # Set up parser to receive arguments from command line
    parser = argparse.ArgumentParser(
        description="Send audio file to Whisper API for transcription",
        epilog="Usage example: python client_example.py ./audio/my_recording.mp3"
    )
    # Add required argument named 'filepath'
    parser.add_argument("filepath", help="Path to audio file to transcribe")
    
    args = parser.parse_args()
    
    # Call API function with the file path received as argument
    test_transcribe_api(args.filepath)


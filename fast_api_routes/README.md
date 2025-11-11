# FastAPI Food Recommendation Service

This service provides AI-powered food recommendations using Groq's LLM API.

## Setup

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Set up environment variables:**
   - Create a `.env` file in this directory
   - Add your Groq API key:
     ```
     GROQ_API_KEY=your_groq_api_key_here
     ```
   - Get your API key from: https://console.groq.com/keys

3. **Run the service:**
   ```bash
   python main.py
   ```

## Environment Variables

- `GROQ_API_KEY`: Your Groq API key (required)
- `GROQ_MODEL`: The model to use (default:  moonshotai/kimi-k2-instruct-0905")

## Security Note

Never commit your actual API key to version control. Always use environment variables or `.env` files that are gitignored.

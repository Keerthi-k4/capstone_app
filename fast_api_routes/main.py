"""
FastAPI Food Recommendation API using LangGraph Agent
Endpoints:
- POST /recommendations/generate - Generate new recommendations
- GET /health - Health check
"""
import os
import json
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# LangGraph imports
from langgraph.prebuilt import create_react_agent
from langchain_core.messages import HumanMessage
from langchain_core.tools import tool
from langchain_groq import ChatGroq


GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GROQ_MODEL = os.getenv("GROQ_MODEL", " moonshotai/kimi-k2-instruct-0905")

if not GROQ_API_KEY:
    raise RuntimeError("GROQ_API_KEY environment variable not set. Please check your .env file.")

# Initialize FastAPI app
app = FastAPI(
    title="Food Recommendation API",
    description="AI-powered food recommendations using LangGraph agents",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure based on your needs
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Groq LLM
llm = ChatGroq(
    api_key=GROQ_API_KEY,
    model=GROQ_MODEL,
    temperature=0.7
)

# ---------------- Pydantic Models ----------------
class FoodLog(BaseModel):
    name: str
    calories: int
    mealType: str
    date: str
    quantity: float

class RecommendationRequest(BaseModel):
    date: str
    logs: List[FoodLog]
    preferences: Optional[List[Dict[str, Any]]] = None  # user dietary preferences
    
class RecommendationItem(BaseModel):
    item: str
    calories: int
    mealType: str
    date: str
    reasoning: str
    quantity: float = 1.0

class GenerateRecommendationsResponse(BaseModel):
    success: bool
    message: str
    recommendations: List[RecommendationItem]
    session_id: str
    agent_logs: Optional[List[str]] = None


# ---------------- LangGraph Tools ----------------
@tool
def analyze_nutrition_gaps(food_logs_json: str) -> str:
    """Analyze nutritional gaps in recent eating patterns"""
    try:
        food_logs = json.loads(food_logs_json)
    except:
        food_logs = []
    
    total_calories = sum(log.get('calories', 0) for log in food_logs)
    meal_types = [log.get('mealType', '') for log in food_logs]
    food_names = [log.get('name', '').lower() for log in food_logs]
    
    gaps = {
        "total_logs": len(food_logs),
        "total_calories": total_calories,
        "avg_daily_calories": total_calories / max(len(set(log.get('date', '') for log in food_logs)), 1),
        "missing_vegetables": not any('salad' in name or 'vegetable' in name or 'broccoli' in name or 'spinach' in name
                                     for name in food_names),
        "low_protein": not any('chicken' in name or 'fish' in name or 'egg' in name or 'bean' in name or 'tofu' in name
                              for name in food_names),
        "high_processed": sum(1 for name in food_names if any(proc in name for proc in ['pizza', 'burger', 'fries', 'chips'])) > len(food_names) * 0.3,
        "missing_breakfast": 'breakfast' not in meal_types,
        "missing_fruits": not any('apple' in name or 'banana' in name or 'berry' in name or 'fruit' in name
                                 for name in food_names),
        "meal_distribution": {meal: meal_types.count(meal) for meal in ['breakfast', 'lunch', 'dinner', 'snack']}
    }
    
    return json.dumps(gaps, indent=2)

@tool
def search_recipe_ideas(cuisine_type: str) -> str:
    """Get guidance for recipe types, but agent should be creative within these constraints"""
    
    guidelines = {
        "indian": "Simple Indian home-style dishes like dal, sabzi, curry, rice dishes, roti meals",
        "healthy": "Basic healthy meals with vegetables, lean proteins, whole grains - nothing fancy",
        "protein": "Simple protein-rich dishes like egg curry, chicken dishes, dal, paneer meals", 
        "vegetables": "Basic vegetable dishes - sabzi, simple curries, vegetable rice",
        "comfort": "Everyday comfort foods like khichdi, simple curries, basic rice dishes"
    }
    
    guidance = guidelines.get(cuisine_type.lower(), guidelines["healthy"])
    
    return f"""Recipe guidance for {cuisine_type}:
{guidance}

IMPORTANT: Don't just copy these words - use your knowledge to suggest ACTUAL simple dish names that fit this category. Think of real, everyday foods people cook at home.

Examples of the style I want:
- "Toor Dal with Rice"
- "Aloo Sabzi with Roti"
- "Chicken Curry with Rice"

Be specific with actual dish names, but keep them SIMPLE and NORMAL."""

@tool
def get_seasonal_ingredients() -> str:
    """Get seasonal ingredients for current month to suggest fresh options"""
    month = datetime.now().month
    seasonal_map = {
        1: ["citrus fruits", "winter squash", "kale", "collard greens", "pomegranates"],
        2: ["citrus fruits", "winter squash", "kale", "collard greens", "pomegranates"],
        3: ["asparagus", "artichokes", "peas", "spring onions", "strawberries"],
        4: ["asparagus", "strawberries", "spring greens", "radishes", "peas"],
        5: ["strawberries", "asparagus", "lettuce", "spinach", "spring herbs"],
        6: ["berries", "tomatoes", "zucchini", "bell peppers", "fresh herbs"],
        7: ["tomatoes", "berries", "corn", "peaches", "cucumber"],
        8: ["tomatoes", "peaches", "corn", "eggplant", "bell peppers"],
        9: ["apples", "winter squash", "brussels sprouts", "pears", "sweet potatoes"],
        10: ["pumpkin", "apples", "sweet potatoes", "brussels sprouts", "cranberries"],
        11: ["cranberries", "sweet potatoes", "winter squash", "pomegranates", "pears"],
        12: ["citrus fruits", "winter squash", "kale", "collard greens", "pomegranates"]
    }
    
    seasonal = seasonal_map.get(month, seasonal_map[6])
    return json.dumps({
        "month": month,
        "seasonal_ingredients": seasonal,
        "suggestion": f"Try incorporating these fresh, seasonal ingredients: {', '.join(seasonal[:3])}"
    }, indent=2)

@tool  
def brainstorm_simple_meals(nutrition_focus: str) -> str:
    """Use your knowledge to brainstorm simple meal ideas based on nutrition focus"""
    
    focus_guidance = {
        "vegetables": "Think of simple ways to add more vegetables - basic sabzis, vegetable rice, simple salads",
        "protein": "Consider everyday protein sources - eggs, dal, chicken, paneer, fish - in simple preparations", 
        "balanced": "Think of complete, balanced meals that are easy to make at home",
        "variety": "Consider different meal types to break monotony - different cuisines but simple versions"
    }
    
    guidance = focus_guidance.get(nutrition_focus.lower(), focus_guidance["balanced"])
    
    return f"""Brainstorming guidance for {nutrition_focus} meals:

{guidance}

Now use your knowledge of Indian and international simple foods to suggest actual dish names. Remember:
- Keep it SIMPLE and homestyle
- Use common ingredients
- Think of what people actually cook daily
- Examples: "Moong Dal Tadka", "Aloo Jeera", "Egg Bhurji", "Simple Chicken Curry"

Don't just repeat examples - use your knowledge to suggest real, simple dishes that fit the nutrition focus."""

# ---------------- Agent Creation ----------------
def create_food_recommendation_agent():
    """Create the LangGraph agent with all tools"""
    
    tools = [
        analyze_nutrition_gaps,
        search_recipe_ideas,
        get_seasonal_ingredients,
        brainstorm_simple_meals
    ]
    
    agent = create_react_agent(llm, tools)
    return agent

# ---------------- Business Logic ----------------
async def generate_recommendations_async(request: RecommendationRequest) -> GenerateRecommendationsResponse:
    """Generate recommendations using the agent"""
    
    # Use logs sent from the request
    food_logs = [log.dict() for log in request.logs]

    if not food_logs:
        return GenerateRecommendationsResponse(
            success=False,
            message="No food logs provided in request.",
            recommendations=[],
            session_id=""
        )
    
    # Create agent
    agent = create_food_recommendation_agent()
    session_id = f"api_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    # Prepare user message
    user_message = f"""You are a practical food recommendation agent. Your goal is to analyze my recent eating patterns and provide 3 SIMPLE, everyday meal recommendations.

IMPORTANT: Think basic home cooking.

Process:
1. First, analyze my recent food logs for nutritional gaps
2. Look at seasonal ingredients for fresh options
3. Use your tools for guidance, then USE YOUR OWN KNOWLEDGE to suggest actual simple dish names
4. Provide 3 practical meal recommendations

Guidelines:
- NO fancy names or creative fusion dishes
- Focus on basic, commonly available ingredients
- Use your knowledge of Indian and international simple foods
- DON'T just copy from tool examples - think of real dishes
- Consider nutritional balance but keep it simple
- Avoid foods they've eaten recently

Recent food logs: {json.dumps(food_logs, indent=2)}
User preferences: {request.preferences or []}

Tools are for guidance only - use your actual knowledge of simple foods to make specific recommendations.

Final output should be exactly 3 SIMPLE recommendations in this JSON format:
{{
  "recommendations": [
    {{
      "item": "Simple dish name",
      "calories": estimated_calories_integer,
      "mealType": "breakfast|lunch|dinner|snack",
      "date": "YYYY-MM-DD",
      "quantity": 1.0,
      "reasoning": "Brief explanation of why this simple meal makes sense"
    }}
  ]
}}

Please use your available tools for analysis, then use YOUR KNOWLEDGE to suggest food names."""

    try:
        # Run the agent
        response = agent.invoke({"messages": [HumanMessage(content=user_message)]})
        final_message = response["messages"][-1].content
        
        # Extract JSON recommendations
        recommendations = []
        if "{" in final_message:
            try:
                json_start = final_message.find("{")
                json_part = final_message[json_start:]
                
                brace_count = 0
                json_end = 0
                for idx, char in enumerate(json_part):
                    if char == "{":
                        brace_count += 1
                    elif char == "}":
                        brace_count -= 1
                        if brace_count == 0:
                            json_end = idx + 1
                            break
                
                if json_end > 0:
                    json_str = json_part[:json_end]
                    parsed = json.loads(json_str)
                    recommendations = parsed.get("recommendations", [])
                    
            except Exception as e:
                return GenerateRecommendationsResponse(
                    success=False,
                    message=f"Error parsing agent response: {str(e)}",
                    recommendations=[],
                    session_id=session_id
                )
        
        if not recommendations:
            return GenerateRecommendationsResponse(
                success=False,
                message="Agent did not return valid recommendations",
                recommendations=[],
                session_id=session_id
            )
        
        # Convert to response format
        response_recs = []
        for rec in recommendations:
            item = rec.get("item", "").strip()
            if not item:
                continue
                
            response_recs.append(RecommendationItem(
                item=item,
                calories=int(rec.get("calories", 0)),
                mealType=rec.get("mealType", "snack"),
                date=rec.get("date", (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")),
                reasoning=rec.get("reasoning", ""),
                quantity=float(rec.get("quantity", 1.0))
            ))
        
        return GenerateRecommendationsResponse(
            success=True,
            message=f"Successfully generated {len(response_recs)} recommendations",
            recommendations=response_recs,
            session_id=session_id
        )
        
    except Exception as e:
        return GenerateRecommendationsResponse(
            success=False,
            message=f"Error generating recommendations: {str(e)}",
            recommendations=[],
            session_id=session_id
        )

# ---------------- API Endpoints ----------------

@app.post("/recommendations/generate", response_model=GenerateRecommendationsResponse)
async def generate_recommendations(request: RecommendationRequest):
    """Generate food recommendations based on provided food logs"""
    recommendations = await generate_recommendations_async(request)
    return recommendations

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "message": "Food Recommendation API is running"
    }

# ---------------- Development Server ----------------
if __name__ == "__main__":
    uvicorn.run(
        app, 
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
        )
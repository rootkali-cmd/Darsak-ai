import pytest
from unittest.mock import AsyncMock, patch

from src.services.ai_analyzer import AIAnalyzer


@pytest.mark.asyncio
async def test_fallback_analysis_with_grades():
    analyzer = AIAnalyzer()
    grades = [
        {"exam": "quiz1", "score": 90, "max_score": 100},
        {"exam": "quiz2", "score": 40, "max_score": 100},
    ]
    result = analyzer._fallback_analysis("math", grades)
    assert "strengths" in result
    assert "weaknesses" in result
    assert "recommended_focus" in result
    assert "next_exercise_suggestion" in result
    assert len(result["strengths"]) > 0
    assert len(result["weaknesses"]) > 0


@pytest.mark.asyncio
async def test_fallback_analysis_empty_grades():
    analyzer = AIAnalyzer()
    result = analyzer._fallback_analysis("math", [])
    assert len(result["strengths"]) > 0
    assert len(result["weaknesses"]) > 0


@pytest.mark.asyncio
async def test_fallback_analysis_avg_calculation():
    analyzer = AIAnalyzer()
    grades = [
        {"exam": "test1", "score": 80, "max_score": 100},
        {"exam": "test2", "score": 65, "max_score": 100},
    ]
    result = analyzer._fallback_analysis("math", grades)
    assert "72.5%" in result["next_exercise_suggestion"]


@pytest.mark.asyncio
async def test_fallback_handles_missing_max_score():
    analyzer = AIAnalyzer()
    grades = [{"exam": "test", "score": 50}]
    result = analyzer._fallback_analysis("math", grades)
    assert "strengths" in result


@pytest.mark.asyncio
async def test_analyze_student_returns_fallback_when_no_key():
    analyzer = AIAnalyzer()
    analyzer.api_key = None
    result = await analyzer.analyze_student("Test", "math", [{"exam": "q1", "score": 70, "max_score": 100}])
    assert "strengths" in result
    assert "weaknesses" in result


@pytest.mark.asyncio
@patch("src.services.ai_analyzer.httpx.AsyncClient")
async def test_groq_api_error_returns_fallback(mock_client):
    mock_instance = AsyncMock()
    mock_instance.__aenter__.return_value = mock_instance
    mock_instance.post.side_effect = Exception("API failed")
    mock_client.return_value = mock_instance

    analyzer = AIAnalyzer()
    analyzer.api_key = "fake-groq-key"
    analyzer.fallback_provider = None

    result = await analyzer.analyze_student("Test", "math", [{"exam": "q1", "score": 70, "max_score": 100}])
    assert "strengths" in result
    assert "weaknesses" in result

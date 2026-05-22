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


@pytest.mark.asyncio
async def test_fallback_analysis_empty_grades():
    analyzer = AIAnalyzer()
    result = analyzer._fallback_analysis("math", [])
    assert len(result["strengths"]) > 0
    assert len(result["weaknesses"]) > 0


@pytest.mark.asyncio
async def test_parse_json_output_clean():
    analyzer = AIAnalyzer()
    raw = '{"strengths": ["good"], "weaknesses": ["bad"], "recommended_focus": ["focus"], "next_exercise_suggestion": "do more"}'
    result = analyzer._parse_json_output(raw)
    assert result["strengths"] == ["good"]


@pytest.mark.asyncio
async def test_parse_json_output_with_markdown():
    analyzer = AIAnalyzer()
    raw = '''```json
{"strengths": ["good"], "weaknesses": ["bad"], "recommended_focus": ["focus"], "next_exercise_suggestion": "do more"}
```'''
    result = analyzer._parse_json_output(raw)
    assert result["strengths"] == ["good"]


@pytest.mark.asyncio
@patch("src.services.ai_analyzer.httpx.AsyncClient")
async def test_ollama_connection_error_returns_fallback(mock_client):
    mock_client.return_value.__aenter__ = AsyncMock(side_effect=Exception("Connection refused"))
    mock_client.return_value.__aexit__ = AsyncMock(return_value=False)

    analyzer = AIAnalyzer()
    result = await analyzer.analyze_student("Test", "math", [{"exam": "q1", "score": 70}])
    assert "strengths" in result
    assert "weaknesses" in result

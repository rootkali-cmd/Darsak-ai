QUIZ_MIGRATIONS_SQL = [
    """CREATE TABLE IF NOT EXISTS quizzes (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
        lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
        total_questions INT DEFAULT 0,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );""",
    """CREATE TABLE IF NOT EXISTS quiz_questions (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
        question_text TEXT NOT NULL,
        options JSONB DEFAULT '[]',
        correct_answer INT DEFAULT 0
    );""",
]

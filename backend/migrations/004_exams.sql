CREATE TABLE IF NOT EXISTS exams (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    teacher_id UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    duration_minutes INT NOT NULL DEFAULT 30,
    total_points INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'closed')),
    source_type VARCHAR(20) CHECK (source_type IN ('pdf', 'images')),
    source_data JSONB,
    answer_key TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS questions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    exam_id UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('multiple_choice', 'essay')),
    question_text TEXT NOT NULL,
    options JSONB,
    correct_answer TEXT,
    points INT DEFAULT 1,
    order_index INT NOT NULL,
    page_number INT DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS student_exams (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    exam_id UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    submitted_at TIMESTAMP WITH TIME ZONE,
    duration_seconds INT,
    status VARCHAR(20) DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'submitted', 'graded')),
    total_score DECIMAL(10,2),
    max_score DECIMAL(10,2),
    UNIQUE(exam_id, student_id)
);

CREATE TABLE IF NOT EXISTS student_answers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    student_exam_id UUID NOT NULL REFERENCES student_exams(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    answer TEXT,
    is_correct BOOLEAN,
    score DECIMAL(10,2),
    feedback TEXT,
    UNIQUE(student_exam_id, question_id)
);

CREATE TABLE IF NOT EXISTS exam_results (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    student_exam_id UUID NOT NULL REFERENCES student_exams(id) ON DELETE CASCADE UNIQUE,
    total_score DECIMAL(10,2),
    max_score DECIMAL(10,2),
    correct_count INT DEFAULT 0,
    wrong_count INT DEFAULT 0,
    essay_score DECIMAL(10,2),
    strengths TEXT,
    weaknesses TEXT,
    recommendations TEXT,
    ai_analysis_raw JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

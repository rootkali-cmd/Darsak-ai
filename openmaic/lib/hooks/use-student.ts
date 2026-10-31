'use client';

import { useEffect, useState } from 'react';

export interface StudentData {
  student_id: string;
  name: string;
  code: string;
  balance: number;
  teacher_id: string;
}

export function useStudent() {
  const [student, setStudent] = useState<StudentData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/student/me')
      .then((r) => r.json())
      .then((data) => {
        setStudent(data.student);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  return { student, loading };
}

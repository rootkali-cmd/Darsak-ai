'use client';

import { useEffect, useRef } from 'react';

interface CanvasRevealEffectProps {
  containerClassName?: string;
  dotSize?: number;
  showGradient?: boolean;
}

export function CanvasRevealEffect({
  containerClassName,
  dotSize = 5,
  showGradient = true,
}: CanvasRevealEffectProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let animId: number;
    let time = 0;
    const gridSize = 28; // Bigger = fewer dots = smoother

    const resize = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    };
    resize();
    window.addEventListener('resize', resize);

    // Pre-compute random values once
    const maxCols = Math.ceil(2000 / gridSize) + 1;
    const maxRows = Math.ceil(1200 / gridSize) + 1;
    const maxTotal = maxCols * maxRows;
    const phases = new Float32Array(maxTotal);
    const speeds = new Float32Array(maxTotal);
    for (let i = 0; i < maxTotal; i++) {
      phases[i] = Math.random() * 6.28;
      speeds[i] = 0.4 + Math.random() * 0.6;
    }

    let lastTime = 0;
    const fps = 30; // Cap at 30fps for performance

    const draw = (timestamp: number) => {
      animId = requestAnimationFrame(draw);
      if (timestamp - lastTime < 1000 / fps) return;
      lastTime = timestamp;

      time += 0.02;
      ctx!.clearRect(0, 0, canvas.width, canvas.height);

      const cols = Math.ceil(canvas.width / gridSize) + 1;
      const rows = Math.ceil(canvas.height / gridSize) + 1;

      for (let i = 0; i < cols; i++) {
        for (let j = 0; j < rows; j++) {
          const idx = i * maxRows + j;
          const x = i * gridSize;
          const y = j * gridSize;

          const opacity = (Math.sin(time * speeds[idx] + phases[idx]) + 1) * 0.5;
          const glow = opacity * opacity;

          if (glow < 0.05) continue;

          const b = Math.floor(160 + glow * 95);
          const a = glow * 0.5;

          // Simple rect — no roundRect, no shadowBlur
          ctx!.fillStyle = `rgba(${b},${b},${b},${a})`;
          ctx!.fillRect(x, y, dotSize, dotSize);
        }
      }
    };

    animId = requestAnimationFrame(draw);
    return () => {
      cancelAnimationFrame(animId);
      window.removeEventListener('resize', resize);
    };
  }, [dotSize]);

  return (
    <div className={`h-full relative w-full ${containerClassName ?? ''}`}>
      <canvas
        ref={canvasRef}
        className="absolute inset-0 w-full h-full"
        style={{ opacity: 0.6 }}
      />
      {showGradient && (
        <div className="absolute inset-0 bg-gradient-to-t from-black via-transparent to-black/60 pointer-events-none" />
      )}
    </div>
  );
}

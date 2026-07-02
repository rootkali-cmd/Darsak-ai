'use client';

import { useEffect, useRef, useState, ReactNode, TouchEvent } from 'react';
import Image from 'next/image';
import { motion } from 'framer-motion';

interface ScrollExpandMediaProps {
  mediaSrc: string;
  bgImageSrc: string;
  title?: string;
  subtitle?: string;
  scrollToExpand?: string;
  children?: ReactNode;
}

const ScrollExpandMedia = ({
  mediaSrc,
  bgImageSrc,
  title,
  subtitle,
  scrollToExpand,
  children,
}: ScrollExpandMediaProps) => {
  const [progress, setProgress] = useState(0);
  const [expanded, setExpanded] = useState(false);
  const [showContent, setShowContent] = useState(false);
  const [touchStart, setTouchStart] = useState(0);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    setIsMobile(window.innerWidth < 768);
    const handleResize = () => setIsMobile(window.innerWidth < 768);
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  useEffect(() => {
    const onWheel = (e: WheelEvent) => {
      if (expanded && e.deltaY < 0 && window.scrollY <= 5) {
        setExpanded(false);
        e.preventDefault();
      } else if (!expanded) {
        e.preventDefault();
        const next = Math.min(Math.max(progress + e.deltaY * 0.0009, 0), 1);
        setProgress(next);
        if (next >= 1) { setExpanded(true); setShowContent(true); }
        else if (next < 0.75) setShowContent(false);
      }
    };

    const onTouchStart = (e: TouchEvent) => setTouchStart(e.touches[0].clientY);

    const onTouchMove = (e: TouchEvent) => {
      if (!touchStart) return;
      const deltaY = touchStart - e.touches[0].clientY;
      if (expanded && deltaY < -20 && window.scrollY <= 5) {
        setExpanded(false);
        e.preventDefault();
      } else if (!expanded) {
        e.preventDefault();
        const factor = deltaY < 0 ? 0.008 : 0.005;
        const next = Math.min(Math.max(progress + deltaY * factor, 0), 1);
        setProgress(next);
        if (next >= 1) { setExpanded(true); setShowContent(true); }
        else if (next < 0.75) setShowContent(false);
        setTouchStart(e.touches[0].clientY);
      }
    };

    const onScroll = () => { if (!expanded) window.scrollTo(0, 0); };

    window.addEventListener('wheel', onWheel as unknown as EventListener, { passive: false });
    window.addEventListener('scroll', onScroll);
    window.addEventListener('touchstart', onTouchStart as unknown as EventListener, { passive: false });
    window.addEventListener('touchmove', onTouchMove as unknown as EventListener, { passive: false });

    return () => {
      window.removeEventListener('wheel', onWheel as unknown as EventListener);
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('touchstart', onTouchStart as unknown as EventListener);
      window.removeEventListener('touchmove', onTouchMove as unknown as EventListener);
    };
  }, [progress, expanded, touchStart]);

  const w = 300 + progress * (isMobile ? 650 : 1250);
  const h = 400 + progress * (isMobile ? 200 : 400);
  const tx = progress * (isMobile ? 180 : 150);

  return (
    <div className='overflow-x-hidden'>
      <section className='relative flex flex-col items-center min-h-[100dvh]'>
        <div className='relative w-full flex flex-col items-center min-h-[100dvh]'>
          {/* Background */}
          <motion.div
            className='absolute inset-0'
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 - progress }}
            transition={{ duration: 0.1 }}
          >
            <Image src={bgImageSrc} alt='' fill className='object-cover' priority />
            <div className='absolute inset-0 bg-gradient-to-b from-black/40 via-black/20 to-[#0a0a1a]' />
          </motion.div>

          <div className='container mx-auto flex flex-col items-center justify-start relative z-10'>
            <div className='flex flex-col items-center justify-center w-full h-[100dvh] relative'>
              {/* Media box */}
              <div
                className='absolute z-0 top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 rounded-2xl overflow-hidden'
                style={{
                  width: `${w}px`,
                  height: `${h}px`,
                  maxWidth: '95vw',
                  maxHeight: '85vh',
                  boxShadow: '0 0 80px rgba(0,0,0,0.5)',
                }}
              >
                <video
                  src={mediaSrc}
                  autoPlay muted loop playsInline preload='auto'
                  className='w-full h-full object-cover'
                />
                <div className='absolute inset-0 bg-gradient-to-t from-black/40 via-transparent to-black/20' />
              </div>

              {/* Title row */}
              <div className='flex items-center justify-center text-center gap-4 w-full relative z-10 flex-col'>
                <motion.h2
                  className='text-4xl md:text-6xl lg:text-7xl font-black text-white leading-none'
                  style={{ transform: `translateX(-${tx}vw)` }}
                >
                  {title}
                </motion.h2>
                {subtitle && (
                  <motion.p
                    className='text-lg md:text-2xl text-indigo-200/80 font-medium'
                    style={{ transform: `translateX(${tx}vw)` }}
                  >
                    {subtitle}
                  </motion.p>
                )}
              </div>

              {/* Scroll hint */}
              {scrollToExpand && !expanded && (
                <motion.div
                  className='absolute bottom-12 text-center z-10'
                  animate={{ opacity: progress > 0.1 ? 0 : 1 }}
                >
                  <p className='text-sm text-white/50'>{scrollToExpand}</p>
                  <motion.div
                    className='mt-2 w-5 h-8 border-2 border-white/30 rounded-full mx-auto'
                    animate={{ y: [0, 4, 0] }}
                    transition={{ repeat: Infinity, duration: 1.5 }}
                  >
                    <div className='w-1 h-2 bg-white/40 rounded-full mx-auto mt-2' />
                  </motion.div>
                </motion.div>
              )}
            </div>

            {/* Children content */}
            <motion.section
              className='flex flex-col w-full px-6 md:px-16 py-16 md:py-24'
              initial={{ opacity: 0 }}
              animate={{ opacity: showContent ? 1 : 0 }}
              transition={{ duration: 0.7 }}
            >
              {children}
            </motion.section>
          </div>
        </div>
      </section>
    </div>
  );
};

export default ScrollExpandMedia;

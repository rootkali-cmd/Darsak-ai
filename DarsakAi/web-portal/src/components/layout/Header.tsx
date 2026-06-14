'use client'

import { useEffect, useRef, useState } from 'react'
import { Bell, Search, ChevronDown, User, LogOut } from 'lucide-react'
import { authApi } from '@/lib/api'

function useClickOutside(ref: React.RefObject<HTMLElement | null>, handler: () => void) {
  const savedHandler = useRef(handler)
  savedHandler.current = handler
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        savedHandler.current()
      }
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [ref])
}

export function Header() {
  const [userName, setUserName] = useState('')
  const [searchFocused, setSearchFocused] = useState(false)
  const [showNotifications, setShowNotifications] = useState(false)
  const [showProfile, setShowProfile] = useState(false)

  const notifRef = useRef<HTMLDivElement>(null)
  const profileRef = useRef<HTMLDivElement>(null)

  useClickOutside(notifRef, () => setShowNotifications(false))
  useClickOutside(profileRef, () => setShowProfile(false))

  useEffect(() => {
    authApi.getMe().then((res) => {
      setUserName(res.data.full_name)
    }).catch(() => {})
  }, [])

  return (
    <header className="sticky top-0 z-30 px-6 py-3 border-b border-white/[0.08] bg-slate-900/80 backdrop-blur-md">
      <div className="flex items-center justify-between gap-4">
        <div className="text-xs text-slate-400">لوحة التحكم</div>

        <div className="flex items-center gap-2">
          <div className={`relative transition-all duration-300 ${searchFocused ? 'w-40 md:w-56' : 'w-28 md:w-40'}`}>
            <Search className={`absolute right-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 ${searchFocused ? 'text-indigo-400' : 'text-slate-500'}`} />
            <input
              type="text"
              placeholder="بحث..."
              onFocus={() => setSearchFocused(true)}
              onBlur={() => setSearchFocused(false)}
              className="w-full py-1.5 pr-8 pl-2 rounded-xl bg-white/[0.05] border border-white/[0.08] text-white text-xs placeholder:text-slate-500 focus:outline-none focus:border-indigo-500/50 transition-colors"
            />
          </div>

          <div className="relative" ref={notifRef}>
            <button
              onClick={() => { setShowNotifications(!showNotifications); setShowProfile(false) }}
              className="relative p-2 rounded-xl border border-white/[0.08] hover:border-white/[0.15] transition-colors"
              aria-label="الإشعارات"
            >
              <Bell size={16} className="text-slate-400" />
              {showNotifications && (
                <span className="absolute -top-1 -left-1 w-3.5 h-3.5 bg-indigo-500 text-[7px] flex items-center justify-center text-white font-bold rounded-full">
                  3
                </span>
              )}
            </button>

            {showNotifications && (
              <div className="absolute left-0 top-full mt-2 w-64 z-50 bg-slate-900/95 backdrop-blur-md border border-white/[0.08] rounded-2xl shadow-lg shadow-black/50 p-3">
                <h3 className="text-xs font-bold mb-3 text-slate-400">الإشعارات</h3>
                {[
                  { text: 'تم إضافة طالب جديد', time: 'منذ 5 دقائق' },
                  { text: 'تم تحديث درجات مجموعة الرياضيات', time: 'منذ ساعة' },
                  { text: 'تقرير AI جاهز للمراجعة', time: 'منذ 3 ساعات' },
                ].map((notif, i) => (
                  <div key={i} className="p-2 border-b border-white/[0.06] last:border-b-0 hover:bg-white/[0.04] transition-colors cursor-pointer rounded-lg">
                    <p className="text-xs text-white">{notif.text}</p>
                    <p className="text-[10px] text-slate-500 mt-0.5">{notif.time}</p>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="relative" ref={profileRef}>
            <button
              onClick={() => { setShowProfile(!showProfile); setShowNotifications(false) }}
              className="flex items-center gap-2 px-3 py-1.5 rounded-xl border border-white/[0.08] hover:border-white/[0.15] transition-colors"
              aria-label="القائمة الشخصية"
            >
              <div className="w-6 h-6 rounded-full flex items-center justify-center" style={{ background: 'linear-gradient(135deg, #6366f1, #8b5cf6)' }}>
                <span className="text-white text-xs font-bold">
                  {userName?.charAt(0) || 'M'}
                </span>
              </div>
              <span className="text-xs hidden md:inline text-slate-400">{userName || 'المعلم'}</span>
              <ChevronDown size={12} className={`text-slate-400 transition-transform ${showProfile ? 'rotate-180' : ''}`} />
            </button>

            {showProfile && (
              <div className="absolute left-0 top-full mt-2 w-48 z-50 bg-slate-900/95 backdrop-blur-md border border-white/[0.08] rounded-2xl shadow-lg shadow-black/50 p-2">
                <div className="p-2 border-b border-white/[0.08] mb-1">
                  <p className="text-sm font-bold text-white">{userName || 'المعلم'}</p>
                  <p className="text-[10px] text-slate-500">معلم</p>
                </div>
                <button className="w-full text-right px-2 py-1.5 text-xs hover:bg-white/[0.04] transition-colors rounded-lg flex items-center gap-2 text-white">
                  <User size={12} />
                  الملف الشخصي
                </button>
                <button className="w-full text-right px-2 py-1.5 text-xs text-red-400 hover:bg-red-500/10 transition-colors rounded-lg flex items-center gap-2">
                  <LogOut size={12} />
                  تسجيل الخروج
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  )
}

'use client'

import { motion } from 'framer-motion'
import { useQuery } from '@tanstack/react-query'
import {
  BarChart2,
  Download,
  AlertTriangle,
  Monitor,
  Smartphone,
  Wifi,
  WifiOff,
  GitBranch,
  Activity,
  TrendingUp,
  Users,
  XCircle,
  CheckCircle,
} from 'lucide-react'
import { GlassCard } from '@/components/ui'
import { api } from '@/lib/api'
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Legend,
} from 'recharts'
import { useState, useEffect } from 'react'

const COLORS = ['#ff003c', '#00f3ff', '#00ff88', '#f59e0b', '#8b5cf6', '#ec4899']

function SkeletonCard() {
  return (
    <div className="rounded-2xl p-6 animate-pulse" style={{ background: 'var(--card-bg)', border: '1px solid var(--border)' }}>
      <div className="h-4 w-24 bg-gray-700 rounded mb-4" />
      <div className="h-8 w-16 bg-gray-700 rounded" />
    </div>
  )
}

function SkeletonChart() {
  return (
    <div className="rounded-2xl p-6 animate-pulse" style={{ background: 'var(--card-bg)', border: '1px solid var(--border)' }}>
      <div className="h-4 w-32 bg-gray-700 rounded mb-4" />
      <div className="h-64 bg-gray-700 rounded" />
    </div>
  )
}

export default function AdminAnalyticsPage() {
  const [now, setNow] = useState(Date.now())

  useEffect(() => {
    const interval = setInterval(() => setNow(Date.now()), 30000)
    return () => clearInterval(interval)
  }, [])

  const { data: overview, isLoading: loadingOverview } = useQuery({
    queryKey: ['analytics-overview', now],
    queryFn: () => api.get('/analytics/overview').then(r => r.data),
    refetchInterval: 30000,
  })

  const { data: updates, isLoading: loadingUpdates } = useQuery({
    queryKey: ['analytics-updates', now],
    queryFn: () => api.get('/analytics/updates').then(r => r.data),
    refetchInterval: 30000,
  })

  const { data: crashes, isLoading: loadingCrashes } = useQuery({
    queryKey: ['analytics-crashes', now],
    queryFn: () => api.get('/analytics/crashes').then(r => r.data),
    refetchInterval: 30000,
  })

  const { data: platforms, isLoading: loadingPlatforms } = useQuery({
    queryKey: ['analytics-platforms', now],
    queryFn: () => api.get('/analytics/platforms').then(r => r.data),
    refetchInterval: 60000,
  })

  const { data: versionsData, isLoading: loadingVersions } = useQuery({
    queryKey: ['analytics-versions', now],
    queryFn: () => api.get('/analytics/versions-usage').then(r => r.data),
    refetchInterval: 60000,
  })

  const { data: channelsData, isLoading: loadingChannels } = useQuery({
    queryKey: ['analytics-channels', now],
    queryFn: () => api.get('/analytics/channels').then(r => r.data),
    refetchInterval: 60000,
  })

  const { data: eventsData, isLoading: loadingEvents } = useQuery({
    queryKey: ['analytics-events', now],
    queryFn: () => api.get('/analytics/events', { params: { limit: 30 } }).then(r => r.data),
    refetchInterval: 30000,
  })

  const statCards = [
    {
      label: 'المستخدمين النشطين',
      value: overview?.active_users ?? 0,
      icon: Users,
      color: '#ff003c',
      loading: loadingOverview,
    },
    {
      label: 'نسبة نجاح التحديث',
      value: `${overview?.update_success_rate ?? 0}%`,
      icon: CheckCircle,
      color: '#00ff88',
      loading: loadingOverview,
    },
    {
      label: 'نسبة الأعطال',
      value: `${overview?.crash_rate ?? 0}%`,
      icon: XCircle,
      color: overview?.crash_rate > 5 ? '#ff003c' : '#f59e0b',
      loading: loadingOverview,
    },
    {
      label: 'التثبيتات الفاشلة',
      value: overview?.failed_installs ?? 0,
      icon: AlertTriangle,
      color: '#ff003c',
      loading: loadingOverview,
    },
  ]

  const platformData = platforms?.platforms?.map((p: { key: string; count: number }) => ({
    name: p.key === 'windows' ? 'Windows' : p.key === 'android' ? 'Android' : p.key === 'linux' ? 'Linux' : p.key,
    value: p.count,
  })) ?? []

  const versionChartData = versionsData?.versions?.slice(0, 10).map((v: { key: string; count: number }) => ({
    name: v.key,
    count: v.count,
  })) ?? []

  const channelChartData = channelsData?.channels?.map((c: { key: string; count: number }) => ({
    name: c.key === 'stable' ? 'Stable' : c.key === 'beta' ? 'Beta' : c.key === 'dev' ? 'Dev' : c.key === 'nightly' ? 'Nightly' : c.key,
    value: c.count,
  })) ?? []

  const updateSteps = [
    { name: 'فحص', value: updates?.checks ?? 0, fill: '#6366f1' },
    { name: 'متاح', value: updates?.available ?? 0, fill: '#f59e0b' },
    { name: 'بدأ', value: updates?.started ?? 0, fill: '#3b82f6' },
    { name: 'تم التحميل', value: updates?.downloaded ?? 0, fill: '#8b5cf6' },
    { name: 'مثبت', value: updates?.installed ?? 0, fill: '#00ff88' },
    { name: 'فشل', value: updates?.failed ?? 0, fill: '#ff003c' },
  ]

  return (
    <div className="space-y-8 rtl" dir="rtl">
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full glass mb-4">
          <BarChart2 className="w-4 h-4 text-primary" />
          <span className="text-sm text-primary">تحليلات الأداء</span>
        </div>
        <h1 className="text-3xl md:text-4xl font-bold mb-2">
          لوحة <span className="neon-text">المراقبة</span>
        </h1>
        <p className="text-text-secondary">إحصائيات وتحليلات شاملة لكل التطبيقات</p>
      </motion.div>

      {/* Stat Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {statCards.map((stat, i) => {
          const Icon = stat.icon
          return (
            <motion.div key={stat.label} initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.1 }}>
              {stat.loading ? (
                <SkeletonCard />
              ) : (
                <GlassCard className="relative overflow-hidden group">
                  <div className="flex items-start justify-between mb-4">
                    <div className="p-3 rounded-xl" style={{ background: `${stat.color}20` }}>
                      <Icon className="w-6 h-6" style={{ color: stat.color }} />
                    </div>
                  </div>
                  <div className="text-3xl font-black mb-1 neon-text">{stat.value}</div>
                  <p className="text-text-secondary text-sm">{stat.label}</p>
                </GlassCard>
              )}
            </motion.div>
          )
        })}
      </div>

      {/* Charts Row 1 */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Update Funnel */}
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }}>
          {loadingUpdates ? (
            <SkeletonChart />
          ) : (
            <GlassCard>
              <div className="flex items-center gap-3 mb-6">
                <div className="p-2 rounded-lg bg-accent-green/10">
                  <Download className="w-5 h-5 text-accent-green" />
                </div>
                <h2 className="text-lg font-bold">مسار التحديثات</h2>
              </div>
              <div className="h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={updateSteps} layout="vertical">
                    <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
                    <XAxis type="number" stroke="var(--text-muted)" fontSize={12} />
                    <YAxis type="category" dataKey="name" stroke="var(--text-muted)" fontSize={12} width={80} />
                    <Tooltip
                      contentStyle={{
                        background: 'var(--card-bg)',
                        border: '1px solid var(--border)',
                        borderRadius: '12px',
                        color: 'var(--text)',
                      }}
                    />
                    <Bar dataKey="value" radius={[0, 8, 8, 0]}>
                      {updateSteps.map((entry, idx) => (
                        <Cell key={idx} fill={entry.fill} />
                      ))}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </GlassCard>
          )}
        </motion.div>

        {/* Platform Distribution */}
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }}>
          {loadingPlatforms ? (
            <SkeletonChart />
          ) : (
            <GlassCard>
              <div className="flex items-center gap-3 mb-6">
                <div className="p-2 rounded-lg bg-accent-orange/10">
                  <Monitor className="w-5 h-5 text-accent-orange" />
                </div>
                <h2 className="text-lg font-bold">توزيع المنصات</h2>
              </div>
              <div className="h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={platformData.length > 0 ? platformData : [{ name: 'Windows', value: 1 }, { name: 'Android', value: 1 }]}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={90}
                      paddingAngle={5}
                      dataKey="value"
                    >
                      {platformData.map((_: any, idx: number) => (
                        <Cell key={idx} fill={COLORS[idx % COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip
                      contentStyle={{
                        background: 'var(--card-bg)',
                        border: '1px solid var(--border)',
                        borderRadius: '12px',
                        color: 'var(--text)',
                      }}
                    />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            </GlassCard>
          )}
        </motion.div>
      </div>

      {/* Charts Row 2 */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Version Usage */}
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.4 }}>
          {loadingVersions ? (
            <SkeletonChart />
          ) : (
            <GlassCard>
              <div className="flex items-center gap-3 mb-6">
                <div className="p-2 rounded-lg bg-accent-cyan/10">
                  <Activity className="w-5 h-5 text-accent-cyan" />
                </div>
                <h2 className="text-lg font-bold">الإصدارات الأكثر استخداماً</h2>
              </div>
              <div className="h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={versionChartData.length > 0 ? versionChartData : [{ name: '1.2.0', count: 1 }]} layout="vertical">
                    <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" />
                    <XAxis type="number" stroke="var(--text-muted)" fontSize={12} />
                    <YAxis type="category" dataKey="name" stroke="var(--text-muted)" fontSize={11} width={80} />
                    <Tooltip
                      contentStyle={{
                        background: 'var(--card-bg)',
                        border: '1px solid var(--border)',
                        borderRadius: '12px',
                        color: 'var(--text)',
                      }}
                    />
                    <Bar dataKey="count" fill="#00f3ff" radius={[0, 8, 8, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </GlassCard>
          )}
        </motion.div>

        {/* Channel Usage */}
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.5 }}>
          {loadingChannels ? (
            <SkeletonChart />
          ) : (
            <GlassCard>
              <div className="flex items-center gap-3 mb-6">
                <div className="p-2 rounded-lg bg-secondary/10">
                  <GitBranch className="w-5 h-5 text-secondary" />
                </div>
                <h2 className="text-lg font-bold">قنوات التحديث</h2>
              </div>
              <div className="h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={channelChartData.length > 0 ? channelChartData : [{ name: 'Stable', value: 1 }]}
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      dataKey="value"
                      label={({ name, percent }: { name: string; percent: number }) => `${name} ${(percent * 100).toFixed(0)}%`}
                    >
                      {channelChartData.map((_: any, idx: number) => (
                        <Cell key={idx} fill={COLORS[idx % COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip
                      contentStyle={{
                        background: 'var(--card-bg)',
                        border: '1px solid var(--border)',
                        borderRadius: '12px',
                        color: 'var(--text)',
                      }}
                    />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            </GlassCard>
          )}
        </motion.div>

        {/* Crash Info */}
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.6 }}>
          {loadingCrashes ? (
            <SkeletonChart />
          ) : (
            <GlassCard>
              <div className="flex items-center gap-3 mb-6">
                <div className="p-2 rounded-lg bg-danger/10">
                  <AlertTriangle className="w-5 h-5 text-danger" />
                </div>
                <h2 className="text-lg font-bold">حالة الأعطال</h2>
              </div>
              <div className="space-y-6">
                <div>
                  <p className="text-text-secondary text-sm mb-1">إجمالي الأعطال</p>
                  <p className="text-3xl font-black neon-text">{crashes?.total_crashes ?? 0}</p>
                </div>
                <div>
                  <p className="text-text-secondary text-sm mb-1">نسبة الأعطال لكل جلسة</p>
                  <p className={`text-3xl font-black ${(crashes?.crash_rate_per_session ?? 0) > 5 ? 'text-danger' : 'text-accent-green'}`}>
                    {crashes?.crash_rate_per_session ?? 0}%
                  </p>
                </div>
              </div>
            </GlassCard>
          )}
        </motion.div>
      </div>

      {/* Recent Events */}
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.7 }}>
        {loadingEvents ? (
          <SkeletonChart />
        ) : (
          <GlassCard>
            <div className="flex items-center gap-3 mb-6">
              <div className="p-2 rounded-lg bg-accent-cyan/10">
                <Activity className="w-5 h-5 text-accent-cyan" />
              </div>
              <h2 className="text-lg font-bold">آخر الأحداث</h2>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-[var(--border)]">
                    <th className="text-right p-2 text-text-secondary">الحدث</th>
                    <th className="text-right p-2 text-text-secondary">المنصة</th>
                    <th className="text-right p-2 text-text-secondary">الإصدار</th>
                    <th className="text-right p-2 text-text-secondary">التوقيت</th>
                  </tr>
                </thead>
                <tbody>
                  {(eventsData?.events ?? []).slice(0, 15).map((event: any, idx: number) => (
                    <tr key={idx} className="border-b border-[var(--border)] hover:bg-white/5">
                      <td className="p-2">
                        <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs ${
                          event.event?.includes('fail') || event.event?.includes('error') || event.event?.includes('crash')
                            ? 'bg-danger/10 text-danger'
                            : event.event?.includes('installed') || event.event?.includes('success')
                            ? 'bg-accent-green/10 text-accent-green'
                            : 'bg-accent-cyan/10 text-accent-cyan'
                        }`}>
                          {event.event}
                        </span>
                      </td>
                      <td className="p-2 text-text-secondary">{event.platform}</td>
                      <td className="p-2 text-text-secondary">{event.version}</td>
                      <td className="p-2 text-text-secondary text-xs">
                        {event.timestamp ? new Date(event.timestamp).toLocaleString('ar-EG') : '-'}
                      </td>
                    </tr>
                  ))}
                  {(!eventsData?.events || eventsData.events.length === 0) && (
                    <tr>
                      <td colSpan={4} className="p-4 text-center text-text-secondary">
                        لا توجد أحداث بعد
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </GlassCard>
        )}
      </motion.div>
    </div>
  )
}

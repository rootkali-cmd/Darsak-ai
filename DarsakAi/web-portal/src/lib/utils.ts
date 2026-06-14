import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatDate(date: string | Date): string {
  return new Date(date).toLocaleDateString('ar-EG', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
}

export function formatPercentage(value: number): string {
  return `${value.toFixed(1)}%`
}

export function getStatusColor(status: string): string {
  switch (status) {
    case 'present':
    case 'paid':
      return 'text-success'
    case 'absent':
    case 'unpaid':
      return 'text-danger'
    case 'cancelled':
      return 'text-warning'
    default:
      return 'text-text-muted'
  }
}

export function getStatusLabel(status: string): string {
  const labels: Record<string, string> = {
    present: 'حاضر',
    absent: 'غائب',
    cancelled: 'ملغي',
    paid: 'مدفوع',
    unpaid: 'غير مدفوع',
  }
  return labels[status] || status
}

/**
 * フォーマットユーティリティ
 */

/**
 * 日付を日本語フォーマットに変換
 */
export function formatDate(date: string | Date): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  return new Intl.DateTimeFormat('ja-JP', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(d);
}

/**
 * 日時を日本語フォーマットに変換
 */
export function formatDateTime(date: string | Date): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  return new Intl.DateTimeFormat('ja-JP', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(d);
}

/**
 * 申請状態の表示名を取得
 */
export function getStatusLabel(status: string): string {
  const labels: Record<string, string> = {
    '申請中': '申請中',
    '調査中': '調査中',
    '審査中': '審査中',
    '認定済み': '認定済み',
    '却下': '却下',
  };
  return labels[status] || status;
}

/**
 * 申請状態の色を取得
 */
export function getStatusColor(status: string): string {
  const colors: Record<string, string> = {
    '申請中': 'bg-blue-100 text-blue-800',
    '調査中': 'bg-yellow-100 text-yellow-800',
    '審査中': 'bg-orange-100 text-orange-800',
    '認定済み': 'bg-green-100 text-green-800',
    '却下': 'bg-red-100 text-red-800',
  };
  return colors[status] || 'bg-gray-100 text-gray-800';
}

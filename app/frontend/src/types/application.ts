/**
 * 申請管理の型定義
 * 目的: 申請データの型安全性を確保
 */

/**
 * 申請ステータス
 */
export type ApplicationStatus =
  | 'draft'       // 下書き
  | 'submitted'   // 申請中
  | 'approved'    // 承認済み
  | 'rejected'    // 却下
  | 'cancelled';  // 取消

/**
 * 申請種別
 */
export type ApplicationType =
  | 'new_facility'      // 新規事業所指定申請
  | 'change'            // 変更届
  | 'renewal'           // 更新申請
  | 'suspension'        // 休止届
  | 'closure';          // 廃止届

/**
 * 申請データ
 */
export interface Application {
  /** 申請ID */
  id: string;

  /** 事業所ID */
  facilityId: string;

  /** 事業所名 */
  facilityName: string;

  /** 申請者名 */
  applicantName: string;

  /** 申請種別 */
  applicationType: ApplicationType;

  /** ステータス */
  status: ApplicationStatus;

  /** 申請日時 */
  submittedAt: Date | null;

  /** 更新日時 */
  updatedAt: Date;

  /** 作成日時 */
  createdAt: Date;

  /** 備考 */
  notes?: string;
}

/**
 * 申請種別の日本語ラベル
 */
export const APPLICATION_TYPE_LABELS: Record<ApplicationType, string> = {
  new_facility: '新規事業所指定申請',
  change: '変更届',
  renewal: '更新申請',
  suspension: '休止届',
  closure: '廃止届',
};

/**
 * 申請ステータスの日本語ラベル
 */
export const APPLICATION_STATUS_LABELS: Record<ApplicationStatus, string> = {
  draft: '下書き',
  submitted: '申請中',
  approved: '承認済み',
  rejected: '却下',
  cancelled: '取消',
};

/**
 * 申請ステータスの色（Tailwind CSS）
 */
export const APPLICATION_STATUS_COLORS: Record<ApplicationStatus, string> = {
  draft: 'bg-gray-100 text-gray-800',
  submitted: 'bg-blue-100 text-blue-800',
  approved: 'bg-green-100 text-green-800',
  rejected: 'bg-red-100 text-red-800',
  cancelled: 'bg-gray-100 text-gray-600',
};

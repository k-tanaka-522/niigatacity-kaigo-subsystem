/**
 * 認証関連の型定義
 * 目的: Cognito認証で使用する型を定義し、型安全性を確保
 * 影響: すべての認証関連コンポーネント・サービス
 */

/**
 * ユーザー情報
 * 目的: Cognito User Pool のカスタムクレームに対応
 */
export interface User {
  /** Cognito User ID (sub クレーム) */
  id: string;
  /** メールアドレス */
  email: string;
  /** 氏名（フルネーム） */
  name: string;
  /** 姓 */
  familyName: string;
  /** 名 */
  givenName: string;
  /** 所属組織ID */
  organizationId: string;
  /** 所属組織名 */
  organizationName: string;
  /** ユーザーロール */
  role: UserRole;
  /** 職員番号（オプション） */
  employeeId?: string;
  /** 部署名（オプション） */
  department?: string;
}

/**
 * ユーザーロール
 * 目的: アクセス制御に使用
 */
export type UserRole = 'system_admin' | 'org_admin' | 'staff' | 'auditor';

/**
 * Cognito認証チャレンジ
 * 目的: MFA、初回パスワード変更などのチャレンジ種別を定義
 */
export interface CognitoChallenge {
  /** チャレンジ名 */
  challengeName: ChallengeType;
  /** チャレンジパラメーター（Cognitoから返却される追加情報） */
  challengeParameters?: Record<string, string>;
  /** チャレンジセッション（次のステップで必要） */
  session?: string;
}

/**
 * チャレンジタイプ
 * 目的: Cognitoが要求する認証ステップを識別
 */
export type ChallengeType =
  | 'SOFTWARE_TOKEN_MFA'      // TOTP MFA検証
  | 'NEW_PASSWORD_REQUIRED'   // 初回パスワード変更
  | 'MFA_SETUP'               // MFA初期設定
  | 'SMS_MFA'                 // SMS MFA検証（将来対応）
  | 'CUSTOM_CHALLENGE';       // カスタムチャレンジ（将来対応）

/**
 * ログインレスポンス
 * 目的: ログイン成功時の戻り値
 */
export interface LoginResponse {
  /** 認証完了フラグ */
  isSignedIn: boolean;
  /** ユーザー情報（認証完了時のみ） */
  user?: User;
  /** 次のステップ（チャレンジがある場合） */
  nextStep?: CognitoChallenge;
}

/**
 * MFA設定情報
 * 目的: MFA設定状態の管理
 */
export interface MfaSettings {
  /** MFA有効フラグ */
  enabled: boolean;
  /** 優先MFA方式 */
  preferredMfa?: 'TOTP' | 'SMS' | 'NOMFA';
  /** TOTP設定済みフラグ */
  totpEnabled: boolean;
  /** SMS設定済みフラグ */
  smsEnabled: boolean;
}

/**
 * パスワード変更リクエスト
 * 目的: パスワード変更API呼び出し時の型定義
 */
export interface ChangePasswordRequest {
  /** 現在のパスワード */
  oldPassword: string;
  /** 新しいパスワード */
  newPassword: string;
}

/**
 * パスワードリセット開始リクエスト
 * 目的: パスワード忘れフロー開始時の型定義
 */
export interface ForgotPasswordRequest {
  /** ユーザーのメールアドレス */
  email: string;
}

/**
 * パスワードリセット完了リクエスト
 * 目的: パスワードリセット確認コード検証時の型定義
 */
export interface ConfirmForgotPasswordRequest {
  /** ユーザーのメールアドレス */
  email: string;
  /** 確認コード（メールで送信） */
  confirmationCode: string;
  /** 新しいパスワード */
  newPassword: string;
}

/**
 * 認証エラー
 * 目的: Cognitoエラーをアプリケーション固有のエラーに変換
 */
export class AuthError extends Error {
  constructor(
    message: string,
    public code: AuthErrorCode,
    public originalError?: unknown
  ) {
    super(message);
    this.name = 'AuthError';
  }
}

/**
 * 認証エラーコード
 * 目的: エラーハンドリングを統一
 */
export type AuthErrorCode =
  | 'UserNotFoundException'
  | 'NotAuthorizedException'
  | 'UserNotConfirmedException'
  | 'PasswordResetRequiredException'
  | 'TooManyRequestsException'
  | 'InvalidParameterException'
  | 'InvalidPasswordException'
  | 'CodeMismatchException'
  | 'ExpiredCodeException'
  | 'NetworkError'
  | 'UnknownError';

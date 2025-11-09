'use client';

import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { authService } from '@/services/auth.service';
import { User, LoginResponse } from '@/types/auth';

/**
 * 認証コンテキストの型定義
 * 目的: アプリ全体で認証状態を共有するためのコンテキスト型
 */
interface AuthContextType {
  /** 現在ログイン中のユーザー（未ログイン時は null） */
  user: User | null;
  /** 認証状態のロード中フラグ */
  loading: boolean;
  /** ログイン処理 */
  login: (email: string, password: string) => Promise<LoginResponse>;
  /** MFA確認処理 */
  confirmMfa: (totpCode: string) => Promise<LoginResponse>;
  /** 初回パスワード変更処理 */
  completeNewPassword: (newPassword: string) => Promise<LoginResponse>;
  /** ログアウト処理 */
  logout: () => Promise<void>;
  /** パスワード変更処理（ログイン中） */
  changePassword: (oldPassword: string, newPassword: string) => Promise<void>;
  /** パスワードリセット開始 */
  forgotPassword: (email: string) => Promise<void>;
  /** パスワードリセット完了 */
  confirmForgotPassword: (email: string, code: string, newPassword: string) => Promise<void>;
  /** JWTトークン取得 */
  getAccessToken: () => Promise<string>;
}

/**
 * 認証コンテキスト
 * 目的: アプリ全体で認証状態を共有
 * 影響: すべてのページ・コンポーネント
 */
const AuthContext = createContext<AuthContextType | undefined>(undefined);

/**
 * 認証プロバイダー Props
 */
interface AuthProviderProps {
  children: ReactNode;
}

/**
 * 認証プロバイダー
 * 目的: アプリ全体に認証状態を提供
 * 影響: すべての子コンポーネント
 * 前提: App Layoutで使用されること
 *
 * @param children - 子コンポーネント
 */
export function AuthProvider({ children }: AuthProviderProps) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  /**
   * 初回ロード時にセッション確認
   * 目的: ページリロード時に自動ログイン
   * 影響: アプリケーション起動時
   */
  useEffect(() => {
    checkSession();
  }, []);

  /**
   * セッション確認
   * 目的: Cognitoセッションが有効か確認し、ユーザー情報を取得
   * 影響: 自動ログイン、セッション復元
   */
  async function checkSession() {
    try {
      // Cognitoから現在のユーザー情報を取得
      const currentUser = await authService.getCurrentUser();
      setUser(currentUser);
    } catch (error) {
      // セッションがない場合は未ログイン状態
      setUser(null);
    } finally {
      setLoading(false);
    }
  }

  /**
   * ログイン
   * 目的: メールアドレスとパスワードでログイン
   * 影響: 認証状態の更新、ダッシュボードへのリダイレクト
   *
   * @param email - メールアドレス
   * @param password - パスワード
   * @returns LoginResponse（認証完了 or 次のステップ）
   */
  async function login(email: string, password: string): Promise<LoginResponse> {
    const response = await authService.login(email, password);

    // 認証完了の場合のみユーザー情報を設定
    if (response.isSignedIn && response.user) {
      setUser(response.user);
    }

    return response;
  }

  /**
   * MFA確認
   * 目的: TOTPコードを検証してログインを完了
   * 影響: 認証状態の更新
   *
   * @param totpCode - TOTPアプリから取得した6桁のコード
   * @returns LoginResponse（認証完了）
   */
  async function confirmMfa(totpCode: string): Promise<LoginResponse> {
    const response = await authService.confirmMfa(totpCode);

    // 認証完了の場合のみユーザー情報を設定
    if (response.isSignedIn && response.user) {
      setUser(response.user);
    }

    return response;
  }

  /**
   * 初回パスワード変更
   * 目的: 一時パスワードを新しいパスワードに変更
   * 影響: 認証状態の更新
   *
   * @param newPassword - 新しいパスワード
   * @returns LoginResponse（パスワード変更後の次のステップ）
   */
  async function completeNewPassword(newPassword: string): Promise<LoginResponse> {
    const response = await authService.completeNewPassword(newPassword);

    // 認証完了の場合のみユーザー情報を設定
    if (response.isSignedIn && response.user) {
      setUser(response.user);
    }

    return response;
  }

  /**
   * ログアウト
   * 目的: ユーザーセッションを終了
   * 影響: 認証状態のクリア、ログイン画面へのリダイレクト
   */
  async function logout(): Promise<void> {
    await authService.logout();
    setUser(null);
  }

  /**
   * パスワード変更（ログイン中）
   * 目的: ログイン中のユーザーが自分のパスワードを変更
   * 影響: パスワード変更のみ（ログイン状態は維持）
   *
   * @param oldPassword - 現在のパスワード
   * @param newPassword - 新しいパスワード
   */
  async function changePassword(oldPassword: string, newPassword: string): Promise<void> {
    await authService.changePassword({ oldPassword, newPassword });
  }

  /**
   * パスワードリセット開始
   * 目的: パスワードリセットフローを開始し、確認コードをメール送信
   * 影響: ユーザーのメールアドレスに確認コードが送信される
   *
   * @param email - ユーザーのメールアドレス
   */
  async function forgotPassword(email: string): Promise<void> {
    await authService.forgotPassword({ email });
  }

  /**
   * パスワードリセット完了
   * 目的: メールで受け取った確認コードを使ってパスワードをリセット
   * 影響: ユーザーのパスワードが変更される
   *
   * @param email - メールアドレス
   * @param code - 確認コード
   * @param newPassword - 新しいパスワード
   */
  async function confirmForgotPassword(
    email: string,
    code: string,
    newPassword: string
  ): Promise<void> {
    await authService.confirmForgotPassword({
      email,
      confirmationCode: code,
      newPassword
    });
  }

  /**
   * JWTトークン取得
   * 目的: バックエンドAPIリクエストに使用するJWTトークンを取得
   * 影響: すべてのバックエンドAPI呼び出し
   *
   * @returns JWT ID Token（文字列）
   */
  async function getAccessToken(): Promise<string> {
    return await authService.getAccessToken();
  }

  // コンテキスト値
  const value: AuthContextType = {
    user,
    loading,
    login,
    confirmMfa,
    completeNewPassword,
    logout,
    changePassword,
    forgotPassword,
    confirmForgotPassword,
    getAccessToken
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

/**
 * useAuth カスタムフック
 * 目的: 認証コンテキストに簡潔にアクセスするためのフック
 * 影響: すべての認証関連コンポーネント
 * 前提: AuthProvider 配下で使用されること
 *
 * @returns AuthContextType
 * @throws Error - AuthProvider 外で使用された場合
 */
export function useAuth(): AuthContextType {
  const context = useContext(AuthContext);

  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }

  return context;
}

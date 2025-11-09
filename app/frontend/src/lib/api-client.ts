import axios, { AxiosInstance, AxiosError, InternalAxiosRequestConfig } from 'axios';
import { authService } from '@/services/auth.service';

/**
 * API クライアント
 * 目的: すべてのAPIリクエストに自動的にJWTトークンを付与
 * 影響: すべてのバックエンドAPI呼び出し
 * 前提: ユーザーがログイン済み（未ログイン時は401エラー）
 */

/**
 * Axios インスタンス作成
 * 目的: バックエンドAPIとの通信を一元管理
 */
const apiClient: AxiosInstance = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_ENDPOINT || 'http://localhost:5000',
  headers: {
    'Content-Type': 'application/json'
  },
  timeout: 30000 // 30秒でタイムアウト
});

/**
 * リクエストインターセプター
 * 目的: すべてのAPIリクエストに自動的にJWTトークンを付与
 * 影響: すべてのバックエンドAPI呼び出し
 * 前提: ユーザーがログイン済み
 */
apiClient.interceptors.request.use(
  async (config: InternalAxiosRequestConfig) => {
    try {
      // Cognitoから最新のJWTトークンを取得
      const token = await authService.getAccessToken();

      // Authorization ヘッダーに JWT トークンを設定
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }

      return config;
    } catch (error) {
      // トークン取得失敗（未ログイン状態）
      console.error('JWT トークン取得失敗:', error);
      return config;
    }
  },
  (error) => {
    // リクエスト送信前のエラー
    return Promise.reject(error);
  }
);

/**
 * レスポンスインターセプター
 * 目的: 401エラー（未認証）時に自動的にログアウト処理
 * 影響: すべてのバックエンドAPI呼び出し
 * 理由: JWTトークンが期限切れまたは無効な場合、ログイン画面にリダイレクト
 */
apiClient.interceptors.response.use(
  (response) => {
    // 正常レスポンスはそのまま返す
    return response;
  },
  async (error: AxiosError) => {
    // 401 Unauthorized エラーの場合
    if (error.response?.status === 401) {
      // トークンが無効または期限切れ
      console.warn('認証エラー（401）: トークンが無効です。ログアウトします。');

      // ログアウト処理（セッションクリア）
      try {
        await authService.logout();
      } catch (logoutError) {
        console.error('ログアウト処理エラー:', logoutError);
      }

      // ログイン画面にリダイレクト
      if (typeof window !== 'undefined') {
        window.location.href = '/login';
      }
    }

    // 403 Forbidden エラーの場合
    if (error.response?.status === 403) {
      console.warn('権限エラー（403）: このリソースにアクセスする権限がありません。');
    }

    // 500 Internal Server Error の場合
    if (error.response?.status === 500) {
      console.error('サーバーエラー（500）:', error.response.data);
    }

    // その他のエラーはそのまま返す
    return Promise.reject(error);
  }
);

/**
 * API エラーハンドリングヘルパー
 * 目的: Axiosエラーをアプリケーション固有のエラーメッセージに変換
 * 影響: エラー表示の一貫性
 *
 * @param error - Axiosエラーオブジェクト
 * @returns ユーザーフレンドリーなエラーメッセージ
 */
export function getErrorMessage(error: unknown): string {
  if (axios.isAxiosError(error)) {
    // サーバーからのエラーレスポンス
    if (error.response) {
      const data = error.response.data as any;
      return data?.message || data?.error || 'サーバーエラーが発生しました';
    }

    // ネットワークエラー（サーバー到達不可）
    if (error.request) {
      return 'サーバーに接続できませんでした。ネットワーク接続を確認してください。';
    }
  }

  // その他のエラー
  if (error instanceof Error) {
    return error.message;
  }

  return '予期しないエラーが発生しました';
}

export default apiClient;

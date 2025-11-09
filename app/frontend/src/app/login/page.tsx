'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useForm } from 'react-hook-form';
import { useAuth } from '@/contexts/AuthContext';
import { AuthError, ChallengeType } from '@/types/auth';

/**
 * ログインフォーム入力
 */
interface LoginForm {
  email: string;
  password: string;
}

/**
 * MFAフォーム入力
 */
interface MfaForm {
  totpCode: string;
}

/**
 * 新しいパスワードフォーム入力
 */
interface NewPasswordForm {
  newPassword: string;
  confirmPassword: string;
}

/**
 * 認証ステップ
 * 目的: ログインフロー（パスワード認証 → MFA → 完了）の現在位置を管理
 */
type AuthStep = 'login' | 'mfa' | 'new_password';

/**
 * ログイン画面
 * 目的: Cognito認証を使用したログイン（MFA対応）
 * 影響: 認証フロー全体
 * 前提: AuthProvider が適用されていること
 */
export default function LoginPage() {
  const router = useRouter();
  const { login, confirmMfa, completeNewPassword } = useAuth();

  // 現在の認証ステップ
  const [step, setStep] = useState<AuthStep>('login');

  // エラーメッセージ
  const [error, setError] = useState('');

  // ローディング状態
  const [loading, setLoading] = useState(false);

  // 一時保存: メールアドレス（MFA画面で表示用）
  const [email, setEmail] = useState('');

  // フォーム: ログイン
  const loginForm = useForm<LoginForm>();

  // フォーム: MFA
  const mfaForm = useForm<MfaForm>();

  // フォーム: 新しいパスワード
  const newPasswordForm = useForm<NewPasswordForm>();

  /**
   * ステップ1: パスワード認証
   * 目的: メールアドレスとパスワードでログイン
   * 影響: 認証成功 → ダッシュボード、MFAチャレンジ → MFA画面
   */
  const onSubmitLogin = async (data: LoginForm) => {
    setLoading(true);
    setError('');
    setEmail(data.email);

    try {
      const response = await login(data.email, data.password);

      // 認証完了（MFA不要の場合）
      if (response.isSignedIn) {
        router.push('/dashboard');
        return;
      }

      // 次のステップがある場合
      if (response.nextStep) {
        handleNextStep(response.nextStep.challengeName);
      }
    } catch (err) {
      handleError(err);
    } finally {
      setLoading(false);
    }
  };

  /**
   * ステップ2: MFA確認
   * 目的: TOTPコードを検証
   * 影響: 認証成功 → ダッシュボード
   */
  const onSubmitMfa = async (data: MfaForm) => {
    setLoading(true);
    setError('');

    try {
      const response = await confirmMfa(data.totpCode);

      // 認証完了
      if (response.isSignedIn) {
        router.push('/dashboard');
        return;
      }

      // 想定外のチャレンジ
      if (response.nextStep) {
        handleNextStep(response.nextStep.challengeName);
      }
    } catch (err) {
      handleError(err);
    } finally {
      setLoading(false);
    }
  };

  /**
   * ステップ3: 初回パスワード変更
   * 目的: 一時パスワードを新しいパスワードに変更
   * 影響: パスワード変更後、MFAチャレンジまたはダッシュボード
   */
  const onSubmitNewPassword = async (data: NewPasswordForm) => {
    // パスワード一致確認
    if (data.newPassword !== data.confirmPassword) {
      setError('パスワードが一致しません');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const response = await completeNewPassword(data.newPassword);

      // 認証完了
      if (response.isSignedIn) {
        router.push('/dashboard');
        return;
      }

      // 次のステップ（通常はMFA）
      if (response.nextStep) {
        handleNextStep(response.nextStep.challengeName);
      }
    } catch (err) {
      handleError(err);
    } finally {
      setLoading(false);
    }
  };

  /**
   * 次のステップ（チャレンジ）を処理
   * 目的: Cognitoチャレンジに応じて画面を切り替え
   */
  const handleNextStep = (challengeName: ChallengeType) => {
    switch (challengeName) {
      case 'SOFTWARE_TOKEN_MFA':
        setStep('mfa');
        break;
      case 'NEW_PASSWORD_REQUIRED':
        setStep('new_password');
        break;
      default:
        setError(`未対応の認証ステップです: ${challengeName}`);
    }
  };

  /**
   * エラーハンドリング
   * 目的: AuthErrorをユーザーフレンドリーなメッセージに変換
   */
  const handleError = (err: unknown) => {
    if (err instanceof AuthError) {
      setError(err.message);
    } else if (err instanceof Error) {
      setError(err.message);
    } else {
      setError('ログインに失敗しました');
    }
  };

  /**
   * UIレンダリング
   * 目的: 認証ステップに応じた画面を表示
   */
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full">
        {/* ヘッダー */}
        <div className="mb-8">
          <h2 className="text-center text-3xl font-extrabold text-gray-900">
            新潟市介護保険事業所システム
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600">
            {step === 'login' && 'ログインしてください'}
            {step === 'mfa' && '認証コードを入力してください'}
            {step === 'new_password' && '新しいパスワードを設定してください'}
          </p>
        </div>

        {/* エラーメッセージ（全画面共通） */}
        {error && (
          <div className="rounded-md bg-red-50 p-4 mb-6">
            <p className="text-sm text-red-800">{error}</p>
          </div>
        )}

        {/* ステップ1: ログイン画面 */}
        {step === 'login' && (
          <form
            className="bg-white shadow-md rounded-lg px-8 pt-6 pb-8"
            onSubmit={loginForm.handleSubmit(onSubmitLogin)}
          >
            <div className="mb-6">
              <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-2">
                メールアドレス
              </label>
              <input
                id="email"
                {...loginForm.register('email', {
                  required: 'メールアドレスは必須です',
                  pattern: {
                    value: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i,
                    message: '有効なメールアドレスを入力してください'
                  }
                })}
                type="email"
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="example@example.com"
                autoComplete="email"
              />
              {loginForm.formState.errors.email && (
                <p className="mt-1 text-sm text-red-600">
                  {loginForm.formState.errors.email.message}
                </p>
              )}
            </div>

            <div className="mb-6">
              <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-2">
                パスワード
              </label>
              <input
                id="password"
                {...loginForm.register('password', { required: 'パスワードは必須です' })}
                type="password"
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="パスワードを入力"
                autoComplete="current-password"
              />
              {loginForm.formState.errors.password && (
                <p className="mt-1 text-sm text-red-600">
                  {loginForm.formState.errors.password.message}
                </p>
              )}
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-400 disabled:cursor-not-allowed"
            >
              {loading ? 'ログイン中...' : 'ログイン'}
            </button>
          </form>
        )}

        {/* ステップ2: MFA画面 */}
        {step === 'mfa' && (
          <form
            className="bg-white shadow-md rounded-lg px-8 pt-6 pb-8"
            onSubmit={mfaForm.handleSubmit(onSubmitMfa)}
          >
            <div className="mb-6">
              <p className="text-sm text-gray-600 mb-4">
                認証アプリに表示されている6桁のコードを入力してください。
              </p>
              <label htmlFor="totpCode" className="block text-sm font-medium text-gray-700 mb-2">
                認証コード
              </label>
              <input
                id="totpCode"
                {...mfaForm.register('totpCode', {
                  required: '認証コードは必須です',
                  pattern: {
                    value: /^[0-9]{6}$/,
                    message: '6桁の数字を入力してください'
                  }
                })}
                type="text"
                inputMode="numeric"
                maxLength={6}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-center text-2xl tracking-widest"
                placeholder="000000"
                autoComplete="one-time-code"
                autoFocus
              />
              {mfaForm.formState.errors.totpCode && (
                <p className="mt-1 text-sm text-red-600">
                  {mfaForm.formState.errors.totpCode.message}
                </p>
              )}
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-400 disabled:cursor-not-allowed"
            >
              {loading ? '確認中...' : '確認'}
            </button>

            <button
              type="button"
              onClick={() => setStep('login')}
              className="mt-4 w-full text-sm text-gray-600 hover:text-gray-800"
            >
              ← ログイン画面に戻る
            </button>
          </form>
        )}

        {/* ステップ3: 新しいパスワード設定画面 */}
        {step === 'new_password' && (
          <form
            className="bg-white shadow-md rounded-lg px-8 pt-6 pb-8"
            onSubmit={newPasswordForm.handleSubmit(onSubmitNewPassword)}
          >
            <div className="mb-6">
              <p className="text-sm text-gray-600 mb-4">
                初回ログインのため、新しいパスワードを設定してください。
              </p>
              <p className="text-xs text-gray-500 mb-4">
                パスワード要件: 12文字以上、大文字・小文字・数字・記号を含む
              </p>
              <label htmlFor="newPassword" className="block text-sm font-medium text-gray-700 mb-2">
                新しいパスワード
              </label>
              <input
                id="newPassword"
                {...newPasswordForm.register('newPassword', {
                  required: '新しいパスワードは必須です',
                  minLength: {
                    value: 12,
                    message: 'パスワードは12文字以上である必要があります'
                  },
                  pattern: {
                    value: /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{12,}$/,
                    message: 'パスワード要件を満たしていません'
                  }
                })}
                type="password"
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="新しいパスワード"
                autoComplete="new-password"
              />
              {newPasswordForm.formState.errors.newPassword && (
                <p className="mt-1 text-sm text-red-600">
                  {newPasswordForm.formState.errors.newPassword.message}
                </p>
              )}
            </div>

            <div className="mb-6">
              <label htmlFor="confirmPassword" className="block text-sm font-medium text-gray-700 mb-2">
                パスワード（確認）
              </label>
              <input
                id="confirmPassword"
                {...newPasswordForm.register('confirmPassword', {
                  required: 'パスワード（確認）は必須です'
                })}
                type="password"
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="パスワードを再入力"
                autoComplete="new-password"
              />
              {newPasswordForm.formState.errors.confirmPassword && (
                <p className="mt-1 text-sm text-red-600">
                  {newPasswordForm.formState.errors.confirmPassword.message}
                </p>
              )}
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-400 disabled:cursor-not-allowed"
            >
              {loading ? 'パスワード変更中...' : 'パスワードを変更'}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}

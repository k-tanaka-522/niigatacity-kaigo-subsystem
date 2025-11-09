import { Amplify } from 'aws-amplify';

/**
 * AWS Amplify 設定
 * 目的: Cognito User Pool とフロントエンドの統合
 * 影響: すべての認証フロー（ログイン、MFA、パスワードリセット等）
 * 前提: 環境変数に Cognito 設定が存在すること
 */

/**
 * Amplify設定オブジェクト
 * 目的: Cognito User Pool の認証設定を定義
 */
export const amplifyConfig = {
  Auth: {
    Cognito: {
      // Cognito User Pool ID（例: ap-northeast-1_XXXXXXXX）
      userPoolId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID || '',

      // Cognito User Pool Client ID
      userPoolClientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID || '',

      // Cognito Identity Pool ID（フェデレーテッドIDに使用）
      identityPoolId: process.env.NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID || '',

      // ログイン設定
      loginWith: {
        // メールアドレスでのログインを有効化
        email: true,
        // 電話番号でのログインは無効（将来対応）
        phone: false,
        // ユーザー名でのログインは無効
        username: false
      },

      // サインアップ時の検証方法
      signUpVerificationMethod: 'code' as const, // メールで確認コード送信

      // ユーザー属性の要件
      userAttributes: {
        email: {
          required: true // メールアドレスは必須
        },
        family_name: {
          required: true // 姓は必須
        },
        given_name: {
          required: true // 名は必須
        }
      },

      // ゲストアクセスを無効化（認証必須）
      allowGuestAccess: false,

      // パスワードポリシー（Cognito User Pool設定と一致）
      passwordFormat: {
        minLength: 12,
        requireLowercase: true,
        requireUppercase: true,
        requireNumbers: true,
        requireSpecialCharacters: true
      },

      // MFA設定
      mfa: {
        // MFA状態（OPTIONAL: ユーザーが選択、ON: 必須、OFF: 無効）
        status: 'OPTIONAL' as const,
        // TOTP（アプリベースMFA）を優先
        totpEnabled: true,
        // SMS MFAは無効（コスト削減）
        smsEnabled: false
      }
    }
  }
};

/**
 * Amplify初期化
 * 目的: アプリケーション起動時にAmplifyを設定
 * 影響: すべてのAmplify機能（認証、API等）
 * 前提: ブラウザ環境でのみ実行（SSR時はスキップ）
 *
 * 注意: Next.js App Routerではサーバーコンポーネントでも実行される可能性があるため、
 *       window オブジェクトの存在チェックを行う
 */
export function configureAmplify(): void {
  // サーバーサイドでは実行しない（ブラウザのみ）
  if (typeof window === 'undefined') {
    return;
  }

  // 環境変数の存在チェック
  if (!process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID) {
    console.warn('NEXT_PUBLIC_COGNITO_USER_POOL_ID が設定されていません');
  }
  if (!process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID) {
    console.warn('NEXT_PUBLIC_COGNITO_CLIENT_ID が設定されていません');
  }

  // Amplify設定を適用
  Amplify.configure(amplifyConfig, {
    // SSRモード（Next.js App Router対応）
    ssr: true
  });
}

// 自動初期化（モジュールインポート時に実行）
configureAmplify();

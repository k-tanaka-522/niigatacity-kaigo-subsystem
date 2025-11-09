import {
  signIn,
  signOut,
  getCurrentUser,
  fetchAuthSession,
  confirmSignIn,
  resetPassword,
  confirmResetPassword,
  updatePassword,
  fetchUserAttributes,
  type SignInOutput,
  type ConfirmSignInInput
} from 'aws-amplify/auth';
import {
  User,
  LoginResponse,
  CognitoChallenge,
  AuthError,
  MfaSettings,
  ChangePasswordRequest,
  ForgotPasswordRequest,
  ConfirmForgotPasswordRequest,
  ChallengeType
} from '@/types/auth';

/**
 * Cognito 認証サービス
 * 目的: Amplify SDKをラップして統一的なエラーハンドリングと型安全性を提供
 * 影響: すべての認証関連コンポーネント
 * 前提: Amplify が適切に設定されていること（amplify-config.ts）
 */
class AuthService {
  /**
   * ログイン（ステップ1: メールアドレスとパスワード認証）
   * 目的: Cognitoでユーザーを認証
   * 影響: ログイン画面、認証フロー全体
   * 前提: ユーザーがCognito User Poolに登録済み
   *
   * @param email - メールアドレス
   * @param password - パスワード
   * @returns LoginResponse（認証完了 or 次のステップ）
   * @throws AuthError - 認証失敗時
   */
  async login(email: string, password: string): Promise<LoginResponse> {
    try {
      const result: SignInOutput = await signIn({
        username: email, // Cognitoではemailをusernameとして使用
        password
      });

      // 認証完了の場合
      if (result.isSignedIn) {
        const user = await this.getCurrentUser();
        return {
          isSignedIn: true,
          user
        };
      }

      // 追加のチャレンジが必要な場合（MFA、初回パスワード変更等）
      if (result.nextStep) {
        return {
          isSignedIn: false,
          nextStep: this.mapChallengeToResponse(result.nextStep)
        };
      }

      // 予期しない状態
      throw new AuthError(
        'ログインに失敗しました（不明なステータス）',
        'UnknownError'
      );
    } catch (error: any) {
      throw this.handleAuthError(error);
    }
  }

  /**
   * MFA確認（ステップ2: TOTPコード検証）
   * 目的: MFAチャレンジを完了する
   * 影響: MFA入力画面
   * 前提: login() でMFAチャレンジが返されていること
   *
   * @param totpCode - TOTPアプリから取得した6桁のコード
   * @returns LoginResponse（認証完了）
   * @throws AuthError - MFA検証失敗時
   */
  async confirmMfa(totpCode: string): Promise<LoginResponse> {
    try {
      const input: ConfirmSignInInput = {
        challengeResponse: totpCode
      };

      const result: SignInOutput = await confirmSignIn(input);

      if (result.isSignedIn) {
        const user = await this.getCurrentUser();
        return {
          isSignedIn: true,
          user
        };
      }

      // MFA確認後も追加ステップがある場合（通常は発生しない）
      if (result.nextStep) {
        return {
          isSignedIn: false,
          nextStep: this.mapChallengeToResponse(result.nextStep)
        };
      }

      throw new AuthError(
        'MFA検証に失敗しました',
        'UnknownError'
      );
    } catch (error: any) {
      throw this.handleAuthError(error);
    }
  }

  /**
   * 初回パスワード変更
   * 目的: 管理者が設定した一時パスワードを新しいパスワードに変更
   * 影響: 初回ログイン時のパスワード変更画面
   * 前提: login() で NEW_PASSWORD_REQUIRED チャレンジが返されていること
   *
   * @param newPassword - 新しいパスワード（12文字以上、複雑性要件を満たす）
   * @returns LoginResponse（パスワード変更後、MFAチャレンジがある場合あり）
   * @throws AuthError - パスワード変更失敗時
   */
  async completeNewPassword(newPassword: string): Promise<LoginResponse> {
    try {
      const input: ConfirmSignInInput = {
        challengeResponse: newPassword
      };

      const result: SignInOutput = await confirmSignIn(input);

      if (result.isSignedIn) {
        const user = await this.getCurrentUser();
        return {
          isSignedIn: true,
          user
        };
      }

      // パスワード変更後にMFAチャレンジがある場合
      if (result.nextStep) {
        return {
          isSignedIn: false,
          nextStep: this.mapChallengeToResponse(result.nextStep)
        };
      }

      throw new AuthError(
        'パスワード変更に失敗しました',
        'UnknownError'
      );
    } catch (error: any) {
      throw this.handleAuthError(error);
    }
  }

  /**
   * ログアウト
   * 目的: ユーザーセッションを終了
   * 影響: すべての認証状態がクリアされる
   * 前提: ユーザーがログイン済み
   *
   * グローバルサインアウト: すべてのデバイスからログアウト
   */
  async logout(): Promise<void> {
    try {
      await signOut({ global: true });
    } catch (error: any) {
      // ログアウトは失敗しても続行（ローカルセッションはクリアされる）
      console.error('ログアウトエラー:', error);
    }
  }

  /**
   * 現在のユーザー情報取得
   * 目的: ログイン中のユーザー情報を取得
   * 影響: ユーザープロフィール表示、権限チェック
   * 前提: ユーザーがログイン済み
   *
   * @returns User（カスタムクレームを含むユーザー情報）
   * @throws AuthError - 未ログイン時
   */
  async getCurrentUser(): Promise<User> {
    try {
      // Cognito User情報取得（sub、email等の基本情報）
      const { userId } = await getCurrentUser();

      // ユーザー属性取得（カスタムクレームを含む）
      const attributes = await fetchUserAttributes();

      // User型にマッピング
      return {
        id: userId,
        email: attributes.email || '',
        name: `${attributes.family_name || ''} ${attributes.given_name || ''}`.trim(),
        familyName: attributes.family_name || '',
        givenName: attributes.given_name || '',
        organizationId: attributes['custom:organization_id'] || '',
        organizationName: attributes['custom:organization_name'] || '',
        role: (attributes['custom:role'] as any) || 'staff',
        employeeId: attributes['custom:employee_id'],
        department: attributes['custom:department']
      };
    } catch (error: any) {
      throw new AuthError(
        'ユーザー情報の取得に失敗しました',
        'NotAuthorizedException',
        error
      );
    }
  }

  /**
   * JWTアクセストークン取得
   * 目的: バックエンドAPIリクエストに使用するJWTトークンを取得
   * 影響: すべてのバックエンドAPI呼び出し
   * 前提: ユーザーがログイン済み
   *
   * @returns JWT ID Token（文字列）
   * @throws AuthError - 未ログイン時
   */
  async getAccessToken(): Promise<string> {
    try {
      const session = await fetchAuthSession();

      // ID Tokenを取得（バックエンドではこれを検証）
      const idToken = session.tokens?.idToken?.toString();

      if (!idToken) {
        throw new AuthError(
          'トークンが見つかりません',
          'NotAuthorizedException'
        );
      }

      return idToken;
    } catch (error: any) {
      throw this.handleAuthError(error);
    }
  }

  /**
   * パスワード変更（ログイン中）
   * 目的: ログイン中のユーザーが自分のパスワードを変更
   * 影響: パスワード変更画面
   * 前提: ユーザーがログイン済み
   *
   * @param request - 現在のパスワードと新しいパスワード
   * @throws AuthError - パスワード変更失敗時
   */
  async changePassword(request: ChangePasswordRequest): Promise<void> {
    try {
      await updatePassword({
        oldPassword: request.oldPassword,
        newPassword: request.newPassword
      });
    } catch (error: any) {
      throw this.handleAuthError(error);
    }
  }

  /**
   * パスワード忘れ（リセット開始）
   * 目的: パスワードリセットフローを開始し、確認コードをメール送信
   * 影響: パスワード忘れ画面
   * 前提: ユーザーがCognito User Poolに登録済み
   *
   * @param request - ユーザーのメールアドレス
   * @throws AuthError - メール送信失敗時
   */
  async forgotPassword(request: ForgotPasswordRequest): Promise<void> {
    try {
      await resetPassword({
        username: request.email
      });
    } catch (error: any) {
      throw this.handleAuthError(error);
    }
  }

  /**
   * パスワード忘れ（確認コードで完了）
   * 目的: メールで受け取った確認コードを使ってパスワードをリセット
   * 影響: パスワードリセット確認画面
   * 前提: forgotPassword() が呼ばれ、確認コードが送信済み
   *
   * @param request - メールアドレス、確認コード、新しいパスワード
   * @throws AuthError - パスワードリセット失敗時
   */
  async confirmForgotPassword(request: ConfirmForgotPasswordRequest): Promise<void> {
    try {
      await confirmResetPassword({
        username: request.email,
        confirmationCode: request.confirmationCode,
        newPassword: request.newPassword
      });
    } catch (error: any) {
      throw this.handleAuthError(error);
    }
  }

  /**
   * Cognitoチャレンジを内部型にマッピング
   * 目的: Amplify SDKの型を内部型に変換
   * 影響: チャレンジ処理フロー
   */
  private mapChallengeToResponse(nextStep: any): CognitoChallenge {
    return {
      challengeName: nextStep.signInStep as ChallengeType,
      challengeParameters: nextStep.additionalInfo
    };
  }

  /**
   * Cognitoエラーを内部エラーに変換
   * 目的: Amplify SDKのエラーをアプリケーション固有のエラーに統一
   * 影響: すべてのエラーハンドリング
   */
  private handleAuthError(error: any): AuthError {
    const errorName = error.name || 'UnknownError';
    const errorMessage = error.message || '予期しないエラーが発生しました';

    // Cognitoエラーコードに応じたメッセージマッピング
    switch (errorName) {
      case 'UserNotFoundException':
        return new AuthError(
          'ユーザーが見つかりません',
          'UserNotFoundException',
          error
        );
      case 'NotAuthorizedException':
        return new AuthError(
          'メールアドレスまたはパスワードが正しくありません',
          'NotAuthorizedException',
          error
        );
      case 'UserNotConfirmedException':
        return new AuthError(
          'メールアドレスが未確認です',
          'UserNotConfirmedException',
          error
        );
      case 'PasswordResetRequiredException':
        return new AuthError(
          'パスワードのリセットが必要です',
          'PasswordResetRequiredException',
          error
        );
      case 'TooManyRequestsException':
        return new AuthError(
          'リクエスト回数が多すぎます。しばらく待ってから再試行してください',
          'TooManyRequestsException',
          error
        );
      case 'InvalidParameterException':
        return new AuthError(
          'パラメーターが無効です',
          'InvalidParameterException',
          error
        );
      case 'InvalidPasswordException':
        return new AuthError(
          'パスワードが要件を満たしていません（12文字以上、大小英字・数字・記号を含む）',
          'InvalidPasswordException',
          error
        );
      case 'CodeMismatchException':
        return new AuthError(
          '確認コードが正しくありません',
          'CodeMismatchException',
          error
        );
      case 'ExpiredCodeException':
        return new AuthError(
          '確認コードの有効期限が切れています',
          'ExpiredCodeException',
          error
        );
      default:
        return new AuthError(
          errorMessage,
          'UnknownError',
          error
        );
    }
  }
}

// シングルトンインスタンスをエクスポート
export const authService = new AuthService();

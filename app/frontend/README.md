# 新潟市介護保険事業所システム - フロントエンド

介護保険事業所の申請管理・事業所管理を行うWebアプリケーションのフロントエンド実装です。

## 技術スタック

- **フレームワーク**: Next.js 14 (App Router)
- **言語**: TypeScript 5
- **スタイリング**: Tailwind CSS 3.3
- **フォーム管理**: React Hook Form 7.49
- **データフェッチング**: SWR 2.2
- **HTTPクライアント**: Axios 1.6
- **認証**: bcryptjs 3.0（プロトタイプ段階）

## ディレクトリ構成

```
src/
├── app/                          # Next.js App Router
│   ├── layout.tsx                # ルートレイアウト
│   ├── page.tsx                  # トップページ
│   ├── globals.css               # グローバルスタイル
│   ├── login/                    # ログイン画面
│   │   └── page.tsx
│   ├── dashboard/                # ダッシュボード
│   │   └── page.tsx
│   ├── applications/             # 申請管理
│   │   ├── page.tsx              # 申請一覧
│   │   ├── [id]/                 # 申請詳細
│   │   │   └── page.tsx
│   │   └── new/                  # 新規申請作成
│   │       └── page.tsx
│   ├── offices/                  # 事業所管理
│   │   ├── page.tsx              # 事業所一覧
│   │   └── [id]/                 # 事業所詳細
│   │       ├── page.tsx
│   │       └── edit/             # 事業所編集
│   │           └── page.tsx
│   └── documents/                # ドキュメント管理
│       └── page.tsx              # ドキュメント一覧
└── components/                   # 共有コンポーネント
    └── Layout/
        └── MainLayout.tsx        # 共通レイアウト

```

## セットアップ

### 前提条件

- Node.js 18.x 以上
- npm または yarn

### インストール手順

```bash
# 依存パッケージのインストール
cd app/frontend
npm install

# 開発サーバーの起動
npm run dev

# ビルド（本番用）
npm run build

# 本番サーバーの起動
npm run start
```

### 開発サーバー

開発サーバーは http://localhost:3000 で起動します。

```bash
npm run dev
```

## 画面一覧

### 実装済み画面

| URL | 画面名 | 説明 | 実装状態 |
|-----|--------|------|---------|
| `/login` | ログイン | システムへのログイン | ✅ 完了 |
| `/` | トップページ | ログイン後のリダイレクト先 | ✅ 完了 |
| `/dashboard` | ダッシュボード | システム全体の概要表示 | ✅ 完了 |
| `/applications` | 申請一覧 | 各種申請の一覧表示・検索 | ✅ 完了 |
| `/applications/new` | 新規申請作成 | 新しい申請の作成 | ✅ 完了 |
| `/applications/[id]` | 申請詳細 | 申請の詳細情報表示 | ✅ 完了 |
| `/offices` | 事業所一覧 | 介護事業所の一覧表示・検索 | ✅ 完了 |
| `/offices/[id]` | 事業所詳細 | 事業所の詳細情報表示 | ✅ 完了 |
| `/offices/[id]/edit` | 事業所編集 | 事業所情報の編集 | ✅ 完了 |
| `/documents` | ドキュメント管理 | マニュアル・様式のダウンロード | ✅ 完了 |

### 画面の特徴

#### 申請管理
- 申請一覧の検索フィルタリング（申請種別・ステータス・事業所名）
- 申請フォームのバリデーション（React Hook Form）
- ステータス管理（申請中・承認済み・差戻し・却下）

#### 事業所管理
- 事業所一覧の検索フィルタリング（事業所名・サービス種別・地区）
- 事業所情報の表示（基本情報・連絡先・代表者/管理者・指定情報・サービス提供地域）
- 事業所情報の編集（フォームバリデーション付き）

#### ドキュメント管理
- タブ切り替え（マニュアル・通知文書・申請様式）
- ドキュメントのカテゴリ別表示
- ダウンロード機能（プロトタイプ段階）

## 技術仕様

### フォーム管理

React Hook Form を使用したフォーム管理を実装しています。

```typescript
import { useForm } from 'react-hook-form';

const { register, handleSubmit, formState: { errors } } = useForm<FormData>();
```

**バリデーション例**:
- 必須項目チェック
- メールアドレス形式チェック
- 電話番号形式チェック（ハイフン付き）
- 事業所番号形式チェック（10桁の数字）

### スタイリング

Tailwind CSS を使用したユーティリティファーストのスタイリングを実装しています。

```typescript
className="w-full px-3 py-2 border border-gray-300 rounded-md
           focus:outline-none focus:ring-2 focus:ring-blue-500"
```

### 状態管理

現在はプロトタイプ段階のため、`useState` による単純な状態管理を使用しています。

```typescript
const [nameFilter, setNameFilter] = useState('');
```

### データフェッチング

プロトタイプ段階のため、ダミーデータを使用していますが、将来的にはSWRによるAPIフェッチングに移行予定です。

```typescript
// 現在（ダミーデータ）
const dummyOffices: Office[] = [...];

// 将来（API統合後）
import useSWR from 'swr';
const { data, error } = useSWR('/api/offices', fetcher);
```

## 開発中の機能

### プロトタイプ段階の実装

以下の機能はプロトタイプ段階であり、ダミーデータを使用しています：

- ログイン認証（フロントエンドのみ、バックエンド未統合）
- 申請管理のCRUD操作
- 事業所管理のCRUD操作
- ドキュメントダウンロード

### 今後の拡張予定

1. **バックエンドAPI統合**
   - C# ASP.NET Core バックエンドとの統合
   - SWRによるデータフェッチング
   - エラーハンドリングの改善

2. **認証フロー実装**
   - JWT トークンベースの認証
   - セッション管理
   - ログアウト機能

3. **グローバル状態管理**
   - Zustand または Jotai の導入
   - ユーザー情報の共有
   - 通知システム

4. **ファイルアップロード**
   - 申請書類のアップロード
   - プレビュー機能

5. **リアルタイム通知**
   - WebSocket または Server-Sent Events
   - 申請ステータス変更の通知

6. **テスト実装**
   - Jest + React Testing Library
   - E2Eテスト（Playwright）

## コーディング規約

### TypeScript

- Strict モードを有効化
- 型定義は明示的に記述
- interface を優先（type よりも拡張性が高い）

### React

- 関数コンポーネントを使用
- `'use client'` ディレクティブでクライアントコンポーネントを明示
- カスタムフックで再利用可能なロジックを分離

### Tailwind CSS

- ユーティリティクラスを使用
- カスタムCSSは最小限に
- レスポンシブデザイン（`sm:`, `md:`, `lg:` プレフィックス）

### ファイル命名

- コンポーネント: PascalCase（例: `MainLayout.tsx`）
- ページ: snake_case（例: `page.tsx`）
- フック: camelCase（例: `useAuth.ts`）

## トラブルシューティング

### ポート3000が使用中の場合

```bash
# ポート番号を変更して起動
PORT=3001 npm run dev
```

### ビルドエラー

```bash
# node_modulesを削除して再インストール
rm -rf node_modules
npm install
```

### ESLintエラー

```bash
# ESLintを実行
npm run lint

# 自動修正
npm run lint -- --fix
```

## 関連ドキュメント

- [Next.js 14 ドキュメント](https://nextjs.org/docs)
- [Tailwind CSS ドキュメント](https://tailwindcss.com/docs)
- [React Hook Form ドキュメント](https://react-hook-form.com/)
- [SWR ドキュメント](https://swr.vercel.app/)

## ライセンス

本プロジェクトは新潟市介護保険事業所システムの一部です。

# テーマカスタマイズガイド

このガイドでは、新潟市介護保険事業所システムのフロントエンドUIの色合いを変更する方法を説明します。

## 色の変更方法

### 1. CSS変数による変更（推奨）

`app/globals.css` ファイルで色を変更できます。

```css
:root {
  /* プライマリーカラー（メインの色） */
  --primary-500: #3b82f6;  /* ← この値を変更 */

  /* セカンダリーカラー（補助色） */
  --secondary-500: #22c55e;  /* ← この値を変更 */

  /* ステータスカラー */
  --success: #22c55e;
  --warning: #f59e0b;
  --error: #ef4444;
  --info: #3b82f6;
}
```

### 2. カラーパレットの完全なカスタマイズ

各色には50〜900の段階があります。デザインツールで生成したパレットを使う場合は、すべての段階を置き換えてください。

```css
:root {
  --primary-50: #eff6ff;
  --primary-100: #dbeafe;
  --primary-200: #bfdbfe;
  --primary-300: #93c5fd;
  --primary-400: #60a5fa;
  --primary-500: #3b82f6;  /* メインカラー */
  --primary-600: #2563eb;
  --primary-700: #1d4ed8;
  --primary-800: #1e40af;
  --primary-900: #1e3a8a;
}
```

## カラーパレット生成ツール

以下のツールを使用して、メインカラーから段階的なパレットを生成できます：

- [Tailwind Color Shades Generator](https://www.tailwindshades.com/)
- [ColorBox by Lyft Design](https://colorbox.io/)
- [Palettte App](https://palettte.app/)

## 使用例

### 例1: 新潟市のブランドカラーに変更

新潟市の公式カラーが `#0066CC` の場合：

```css
:root {
  /* プライマリーカラーを新潟市ブランドカラーに */
  --primary-50: #e6f2ff;
  --primary-100: #b3d9ff;
  --primary-200: #80bfff;
  --primary-300: #4da6ff;
  --primary-400: #1a8cff;
  --primary-500: #0066CC;  /* 新潟市ブランドカラー */
  --primary-600: #0052a3;
  --primary-700: #003d7a;
  --primary-800: #002952;
  --primary-900: #001429;
}
```

### 例2: グリーン系のテーマ

環境・福祉をイメージしたグリーン系：

```css
:root {
  --primary-50: #f0fdf4;
  --primary-100: #dcfce7;
  --primary-200: #bbf7d0;
  --primary-300: #86efac;
  --primary-400: #4ade80;
  --primary-500: #22c55e;  /* メイングリーン */
  --primary-600: #16a34a;
  --primary-700: #15803d;
  --primary-800: #166534;
  --primary-900: #14532d;
}
```

### 例3: コーポレートカラーに合わせる

組織のコーポレートカラーが複数ある場合：

```css
:root {
  /* プライマリー: メインのコーポレートカラー */
  --primary-500: #your-main-color;

  /* セカンダリー: サブのコーポレートカラー */
  --secondary-500: #your-sub-color;
}
```

## 適用箇所

色を変更すると、以下の要素に反映されます：

- **ヘッダー**: `bg-primary-600`
- **ボタン**: `bg-primary-600`, `hover:bg-primary-700`
- **リンク**: `text-primary-600`
- **フォーカス**: `focus:ring-primary-500`
- **バッジ**: `bg-primary-100`, `text-primary-800`
- **サイドバー**: `bg-primary-100` (アクティブ項目)

## 変更後の確認

1. 開発サーバーを起動:
   ```bash
   npm run dev
   ```

2. ブラウザで http://localhost:3000 を開く

3. 以下のページで色が正しく適用されているか確認:
   - ダッシュボード
   - 申請一覧
   - 各種ボタン・リンク

## トラブルシューティング

### 色が変わらない場合

1. ブラウザのキャッシュをクリア（Ctrl+Shift+R / Cmd+Shift+R）
2. 開発サーバーを再起動
3. CSS変数名が正しいか確認（ハイフン `-` の数など）

### 色のコントラストが悪い場合

[WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/) でアクセシビリティを確認してください。

WCAG 2.1 AA基準:
- 通常テキスト: コントラスト比 4.5:1 以上
- 大きなテキスト: コントラスト比 3:1 以上

## 参考リンク

- [Tailwind CSS Colors](https://tailwindcss.com/docs/customizing-colors)
- [CSS Custom Properties (Variables)](https://developer.mozilla.org/en-US/docs/Web/CSS/Using_CSS_custom_properties)
- [Web Content Accessibility Guidelines (WCAG)](https://www.w3.org/WAI/WCAG21/quickref/)

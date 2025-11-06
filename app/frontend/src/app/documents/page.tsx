/**
 * ドキュメント管理画面
 *
 * マニュアル、通知文書、申請様式などのドキュメントを管理・ダウンロードできます。
 * タブ切り替えでカテゴリ別にドキュメントを表示します。
 * ダミーデータを使用したプロトタイプ実装です。
 *
 * @page /documents
 */
'use client';

import { useState } from 'react';

/** ドキュメントの型定義 */
interface Document {
  /** ドキュメントID */
  id: number;
  /** ドキュメントタイトル */
  title: string;
  /** カテゴリ（マニュアル、通知文書、申請様式） */
  category: "マニュアル" | "通知文書" | "申請様式";
  /** 更新日（YYYY-MM-DD） */
  date: string;
  /** ドキュメントの説明 */
  description: string;
  /** ファイルサイズ（表示用） */
  fileSize: string;
}

/** ダミードキュメントデータ（プロトタイプ用） */
const documents: Document[] = [
  { id: 1, title: "システム利用マニュアル", category: "マニュアル", date: "2025-10-01", description: "本システムの基本的な使い方を説明したマニュアルです。", fileSize: "2.5MB" },
  { id: 2, title: "申請手続きガイド", category: "マニュアル", date: "2025-09-15", description: "各種申請の手続き方法を解説したガイドです。", fileSize: "1.8MB" },
  { id: 3, title: "変更届の提出について", category: "通知文書", date: "2025-10-15", description: "事業所情報変更時の届出に関する通知です。", fileSize: "0.5MB" },
  { id: 4, title: "令和7年度の報酬改定について", category: "通知文書", date: "2025-10-10", description: "介護報酬改定の詳細をお知らせします。", fileSize: "1.2MB" },
  { id: 5, title: "指定更新申請書（様式1）", category: "申請様式", date: "2025-09-01", description: "事業所指定の更新申請に必要な書類です。", fileSize: "0.3MB" },
  { id: 6, title: "変更届出書（様式2）", category: "申請様式", date: "2025-09-01", description: "事業所情報の変更届出に必要な書類です。", fileSize: "0.2MB" },
  { id: 7, title: "休止・廃止届出書（様式3）", category: "申請様式", date: "2025-09-01", description: "事業の休止・廃止届出に必要な書類です。", fileSize: "0.2MB" },
];

/**
 * ドキュメント管理ページコンポーネント
 *
 * タブ切り替えでカテゴリ別にドキュメントを表示し、
 * ダウンロードボタンでファイルを取得できます（プロトタイプ段階では未実装）。
 */
export default function DocumentsPage() {
  // アクティブなタブの状態管理
  const [activeTab, setActiveTab] = useState<Document['category']>("マニュアル");

  /**
   * アクティブなタブに基づいてドキュメントをフィルタリング
   * 選択されたカテゴリのドキュメントのみを表示
   */
  const filteredDocuments = documents.filter(doc => doc.category === activeTab);

  /**
   * ダウンロードボタンのハンドラー
   * プロトタイプ段階では未実装のため、アラート表示のみ
   * 本番環境ではファイルダウンロードAPIを呼び出す予定
   */
  const handleDownload = (docTitle: string) => {
    alert(`ダウンロード機能は未実装です: ${docTitle}`);
  };

  /** タブの配列（カテゴリ一覧） */
  const tabs: Document['category'][] = ["マニュアル", "通知文書", "申請様式"];

  return (
    <div className="min-h-screen bg-gray-50 py-8 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        {/* ページタイトル */}
        <div className="mb-8">
          <h1 className="text-3xl font-extrabold text-gray-900">
            ドキュメント管理
          </h1>
          <p className="mt-2 text-sm text-gray-600">
            マニュアル、通知文書、申請様式をダウンロードできます
          </p>
        </div>

        {/* タブナビゲーション */}
        <div className="mb-6 border-b border-gray-200">
          <nav className="flex space-x-8">
            {tabs.map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`py-4 px-1 border-b-2 font-medium text-sm transition-colors ${
                  activeTab === tab
                    ? 'border-blue-600 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                {tab}
              </button>
            ))}
          </nav>
        </div>

        {/* ドキュメントカードグリッド */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredDocuments.map((doc) => (
            <div
              key={doc.id}
              className="bg-white rounded-lg shadow hover:shadow-lg transition-shadow p-6"
            >
              {/* カテゴリバッジ */}
              <div className="mb-3">
                <span className="inline-block px-3 py-1 text-xs font-semibold text-blue-800 bg-blue-100 rounded-full">
                  {doc.category}
                </span>
              </div>

              {/* タイトル */}
              <h3 className="text-lg font-bold text-gray-900 mb-2">
                {doc.title}
              </h3>

              {/* 説明 */}
              <p className="text-sm text-gray-600 mb-4">
                {doc.description}
              </p>

              {/* メタ情報 */}
              <div className="flex items-center justify-between text-xs text-gray-500 mb-4">
                <span>更新日: {doc.date}</span>
                <span>{doc.fileSize}</span>
              </div>

              {/* ダウンロードボタン */}
              <button
                onClick={() => handleDownload(doc.title)}
                className="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors text-sm font-medium"
              >
                ダウンロード
              </button>
            </div>
          ))}
        </div>

        {/* ドキュメントが0件の場合 */}
        {filteredDocuments.length === 0 && (
          <div className="text-center py-12">
            <p className="text-gray-500 text-sm">
              このカテゴリにはドキュメントがありません
            </p>
          </div>
        )}
      </div>
    </div>
  );
}

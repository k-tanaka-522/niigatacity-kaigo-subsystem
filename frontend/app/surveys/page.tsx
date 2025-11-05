/**
 * 認定調査票一覧ページ
 */

export default function SurveysPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">認定調査票</h1>
        <p className="mt-1 text-sm text-gray-500">
          認定調査票の作成・提出を行います
        </p>
      </div>
      <div className="bg-white rounded-lg shadow p-8 text-center">
        <svg
          className="mx-auto h-12 w-12 text-gray-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
          />
        </svg>
        <h3 className="mt-2 text-sm font-medium text-gray-900">
          認定調査票機能
        </h3>
        <p className="mt-1 text-sm text-gray-500">
          この機能は現在開発中です
        </p>
      </div>
    </div>
  );
}

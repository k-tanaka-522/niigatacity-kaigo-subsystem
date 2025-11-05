/**
 * 基本チェックリスト一覧ページ
 */

export default function ChecklistsPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">基本チェックリスト</h1>
        <p className="mt-1 text-sm text-gray-500">
          基本チェックリストの提出を行います
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
            d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
        <h3 className="mt-2 text-sm font-medium text-gray-900">
          基本チェックリスト機能
        </h3>
        <p className="mt-1 text-sm text-gray-500">
          この機能は現在開発中です
        </p>
      </div>
    </div>
  );
}

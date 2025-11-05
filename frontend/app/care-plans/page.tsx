/**
 * ケアプラン届一覧ページ
 */

export default function CarePlansPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">ケアプラン届</h1>
        <p className="mt-1 text-sm text-gray-500">
          ケアプラン届の提出を行います
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
            d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
          />
        </svg>
        <h3 className="mt-2 text-sm font-medium text-gray-900">
          ケアプラン届機能
        </h3>
        <p className="mt-1 text-sm text-gray-500">
          この機能は現在開発中です
        </p>
      </div>
    </div>
  );
}

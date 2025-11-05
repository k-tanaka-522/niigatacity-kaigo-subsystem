/**
 * ダッシュボードページ
 */

import Link from 'next/link';

export default function Home() {
  const stats = [
    {
      name: '申請中',
      value: '24',
      icon: (
        <svg className="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
          />
        </svg>
      ),
      color: 'text-blue-600',
      bgColor: 'bg-blue-100',
      href: '/applications?status=申請中',
    },
    {
      name: '調査中',
      value: '18',
      icon: (
        <svg className="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
          />
        </svg>
      ),
      color: 'text-yellow-600',
      bgColor: 'bg-yellow-100',
      href: '/applications?status=調査中',
    },
    {
      name: '審査中',
      value: '12',
      icon: (
        <svg className="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
      ),
      color: 'text-orange-600',
      bgColor: 'bg-orange-100',
      href: '/applications?status=審査中',
    },
    {
      name: '認定済み',
      value: '156',
      icon: (
        <svg className="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
      ),
      color: 'text-green-600',
      bgColor: 'bg-green-100',
      href: '/applications?status=認定済み',
    },
  ];

  const quickActions = [
    {
      name: '新規申請作成',
      description: '要介護認定申請を新規作成',
      href: '/applications/new',
      icon: (
        <svg className="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M12 4v16m8-8H4"
          />
        </svg>
      ),
      color: 'text-primary-600',
      bgColor: 'bg-primary-100',
    },
    {
      name: '認定調査票作成',
      description: '認定調査票を作成・提出',
      href: '/surveys/new',
      icon: (
        <svg className="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
          />
        </svg>
      ),
      color: 'text-secondary-600',
      bgColor: 'bg-secondary-100',
    },
    {
      name: '対象者検索',
      description: '対象者情報を検索・閲覧',
      href: '/subjects',
      icon: (
        <svg className="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
          />
        </svg>
      ),
      color: 'text-purple-600',
      bgColor: 'bg-purple-100',
    },
  ];

  return (
    <div className="space-y-6">
      {/* ページタイトル */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">ダッシュボード</h1>
        <p className="mt-1 text-sm text-gray-500">
          システムの概要と最近のアクティビティを表示しています
        </p>
      </div>

      {/* 統計カード */}
      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
        {stats.map((stat) => (
          <Link
            key={stat.name}
            href={stat.href}
            className="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition-shadow"
          >
            <div className="p-5">
              <div className="flex items-center">
                <div className={`flex-shrink-0 ${stat.bgColor} p-3 rounded-md`}>
                  <div className={stat.color}>{stat.icon}</div>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dt className="text-sm font-medium text-gray-500 truncate">
                    {stat.name}
                  </dt>
                  <dd className="mt-1 text-3xl font-semibold text-gray-900">
                    {stat.value}
                  </dd>
                </div>
              </div>
            </div>
          </Link>
        ))}
      </div>

      {/* クイックアクション */}
      <div>
        <h2 className="text-lg font-medium text-gray-900 mb-4">クイックアクション</h2>
        <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {quickActions.map((action) => (
            <Link
              key={action.name}
              href={action.href}
              className="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition-shadow p-6"
            >
              <div className="flex items-center">
                <div className={`flex-shrink-0 ${action.bgColor} p-3 rounded-md`}>
                  <div className={action.color}>{action.icon}</div>
                </div>
                <div className="ml-4">
                  <h3 className="text-lg font-medium text-gray-900">
                    {action.name}
                  </h3>
                  <p className="mt-1 text-sm text-gray-500">{action.description}</p>
                </div>
              </div>
            </Link>
          ))}
        </div>
      </div>

      {/* 最近のアクティビティ */}
      <div>
        <h2 className="text-lg font-medium text-gray-900 mb-4">最近のアクティビティ</h2>
        <div className="bg-white shadow rounded-lg">
          <ul className="divide-y divide-gray-200">
            {[
              {
                id: 1,
                user: '田中 太郎',
                action: '要介護認定申請を作成しました',
                target: 'APP-20250105-12345',
                time: '5分前',
              },
              {
                id: 2,
                user: '佐藤 花子',
                action: '認定調査票を提出しました',
                target: 'SUR-20250105-54321',
                time: '15分前',
              },
              {
                id: 3,
                user: '鈴木 一郎',
                action: 'ケアプラン届を更新しました',
                target: 'PLAN-20250105-98765',
                time: '1時間前',
              },
              {
                id: 4,
                user: '高橋 美咲',
                action: '対象者情報を更新しました',
                target: '被保険者番号: 1234567890',
                time: '2時間前',
              },
            ].map((activity) => (
              <li key={activity.id} className="px-6 py-4 hover:bg-gray-50">
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    <div className="flex-shrink-0">
                      <div className="h-8 w-8 rounded-full bg-gray-200 flex items-center justify-center">
                        <span className="text-sm font-medium text-gray-600">
                          {activity.user[0]}
                        </span>
                      </div>
                    </div>
                    <div className="flex-1">
                      <p className="text-sm text-gray-900">
                        <span className="font-medium">{activity.user}</span>{' '}
                        {activity.action}
                      </p>
                      <p className="text-sm text-gray-500">{activity.target}</p>
                    </div>
                  </div>
                  <div className="text-sm text-gray-500">{activity.time}</div>
                </div>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </div>
  );
}

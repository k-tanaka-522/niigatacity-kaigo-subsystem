'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import MainLayout from '@/components/Layout/MainLayout';
import { applicationsAPI } from '@/lib/api';

export default function DashboardPage() {
  const router = useRouter();
  const [stats, setStats] = useState({ total: 0, draft: 0, submitted: 0, approved: 0, rejected: 0 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    try {
      const response = await applicationsAPI.getAll();
      const applications = response.data;

      const draft = applications.filter((app: any) => app.status === 'draft').length;
      const submitted = applications.filter((app: any) => app.status === 'submitted').length;
      const approved = applications.filter((app: any) => app.status === 'approved').length;
      const rejected = applications.filter((app: any) => app.status === 'rejected').length;

      setStats({
        total: applications.length,
        draft,
        submitted,
        approved,
        rejected,
      });
    } catch (error) {
      console.error('Failed to fetch stats:', error);
    } finally {
      setLoading(false);
    }
  };

  const statsCards = [
    { label: '全申請数', value: stats.total, icon: '📊', color: 'text-gray-900', bgColor: 'bg-gray-50' },
    { label: '下書き', value: stats.draft, icon: '📝', color: 'text-yellow-600', bgColor: 'bg-yellow-50' },
    { label: '提出済み', value: stats.submitted, icon: '📤', color: 'text-blue-600', bgColor: 'bg-blue-50' },
    { label: '承認済み', value: stats.approved, icon: '✅', color: 'text-green-600', bgColor: 'bg-green-50' },
  ];

  const quickActions = [
    {
      title: '新規申請を作成',
      description: '新しい申請書を作成します',
      icon: '➕',
      href: '/applications/new',
      primary: true,
    },
    {
      title: '申請一覧を見る',
      description: 'すべての申請を確認します',
      icon: '📋',
      href: '/applications',
      primary: false,
    },
  ];

  if (loading) {
    return (
      <MainLayout>
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
        </div>
      </MainLayout>
    );
  }

  return (
    <MainLayout>
      <div className="px-4 py-6 sm:px-0">
        {/* ページヘッダー */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900">ダッシュボード</h1>
          <p className="mt-2 text-sm text-gray-600">
            申請の状況を確認して、新しい申請を作成できます
          </p>
        </div>

        {/* 統計カード */}
        <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-8">
          {statsCards.map((stat) => (
            <div
              key={stat.label}
              className="bg-white overflow-hidden shadow-sm rounded-lg border border-gray-200 hover:shadow-md transition-shadow"
            >
              <div className="p-5">
                <div className="flex items-center">
                  <div className={`flex-shrink-0 rounded-md p-3 ${stat.bgColor}`}>
                    <span className="text-2xl">{stat.icon}</span>
                  </div>
                  <div className="ml-5 w-0 flex-1">
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      {stat.label}
                    </dt>
                    <dd className={`mt-1 text-3xl font-semibold ${stat.color}`}>
                      {stat.value}
                    </dd>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* クイックアクション */}
        <div className="bg-white shadow-sm rounded-lg border border-gray-200 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">クイックアクション</h2>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            {quickActions.map((action) => (
              <button
                key={action.title}
                onClick={() => router.push(action.href)}
                className={`group relative flex items-start p-4 rounded-lg border-2 transition-all ${
                  action.primary
                    ? 'border-blue-600 bg-blue-50 hover:bg-blue-100'
                    : 'border-gray-200 hover:border-blue-300 hover:bg-gray-50'
                }`}
              >
                <div className="flex-shrink-0">
                  <span className="text-3xl">{action.icon}</span>
                </div>
                <div className="ml-4 text-left">
                  <h3
                    className={`text-base font-medium ${
                      action.primary ? 'text-blue-900' : 'text-gray-900'
                    }`}
                  >
                    {action.title}
                  </h3>
                  <p className="mt-1 text-sm text-gray-500">{action.description}</p>
                </div>
                <div className="ml-auto flex-shrink-0">
                  <span className="text-gray-400 group-hover:text-blue-600 transition-colors">
                    →
                  </span>
                </div>
              </button>
            ))}
          </div>
        </div>
      </div>
    </MainLayout>
  );
}

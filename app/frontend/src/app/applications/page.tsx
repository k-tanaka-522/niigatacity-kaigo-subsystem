'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import MainLayout from '@/components/Layout/MainLayout';
import { applicationsAPI } from '@/lib/api';
import { Application } from '@/types';

export default function ApplicationsListPage() {
  const router = useRouter();
  const [applications, setApplications] = useState<Application[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<string>('');

  useEffect(() => {
    fetchApplications();
  }, [statusFilter]);

  const fetchApplications = async () => {
    try {
      const response = await applicationsAPI.getAll({ status: statusFilter || undefined });
      setApplications(response.data);
    } catch (error) {
      console.error('Failed to fetch applications:', error);
    } finally {
      setLoading(false);
    }
  };

  const getStatusBadge = (status: string) => {
    const statusConfig: Record<string, { label: string; className: string }> = {
      draft: { label: '下書き', className: 'bg-yellow-100 text-yellow-800' },
      submitted: { label: '提出済み', className: 'bg-blue-100 text-blue-800' },
      in_review: { label: '審査中', className: 'bg-purple-100 text-purple-800' },
      approved: { label: '承認済み', className: 'bg-green-100 text-green-800' },
      rejected: { label: '却下', className: 'bg-red-100 text-red-800' },
    };

    const config = statusConfig[status] || { label: status, className: 'bg-gray-100 text-gray-800' };
    return (
      <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${config.className}`}>
        {config.label}
      </span>
    );
  };

  const statusTabs = [
    { label: 'すべて', value: '' },
    { label: '下書き', value: 'draft' },
    { label: '提出済み', value: 'submitted' },
    { label: '審査中', value: 'in_review' },
    { label: '承認済み', value: 'approved' },
    { label: '却下', value: 'rejected' },
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
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">申請一覧</h1>
            <p className="mt-2 text-sm text-gray-600">
              すべての申請を確認・管理できます
            </p>
          </div>
          <button
            onClick={() => router.push('/applications/new')}
            className="px-4 py-2 border border-transparent rounded-md text-sm font-medium text-white bg-blue-600 hover:bg-blue-700"
          >
            ➕ 新規申請
          </button>
        </div>

        <div className="bg-white shadow-sm rounded-lg border border-gray-200">
          <div className="border-b border-gray-200">
            <nav className="flex -mb-px overflow-x-auto">
              {statusTabs.map((tab) => (
                <button
                  key={tab.value}
                  onClick={() => setStatusFilter(tab.value)}
                  className={`whitespace-nowrap py-4 px-6 border-b-2 font-medium text-sm ${
                    statusFilter === tab.value
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  {tab.label}
                </button>
              ))}
            </nav>
          </div>

          {applications.length === 0 ? (
            <div className="text-center py-12">
              <p className="text-gray-500">申請がありません</p>
              <button
                onClick={() => router.push('/applications/new')}
                className="mt-4 text-blue-600 hover:text-blue-800"
              >
                最初の申請を作成する
              </button>
            </div>
          ) : (
            <div className="divide-y divide-gray-200">
              {applications.map((app) => (
                <div
                  key={app.id}
                  onClick={() => router.push(`/applications/${app.id}`)}
                  className="p-6 hover:bg-gray-50 cursor-pointer transition-colors"
                >
                  <div className="flex items-start justify-between">
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-3 mb-2">
                        <h3 className="text-lg font-medium text-gray-900 truncate">
                          {app.title}
                        </h3>
                        {getStatusBadge(app.status)}
                      </div>
                      <div className="flex items-center gap-4 text-sm text-gray-500">
                        <span>申請番号: {app.applicationNumber}</span>
                        <span>種別: {app.applicationType}</span>
                        <span>事業所: {app.officeName}</span>
                      </div>
                      <div className="mt-2 text-sm text-gray-500">
                        作成: {new Date(app.createdAt).toLocaleString('ja-JP')}
                        {app.submittedAt && (
                          <span className="ml-4">
                            提出: {new Date(app.submittedAt).toLocaleString('ja-JP')}
                          </span>
                        )}
                      </div>
                    </div>
                    <div className="ml-4 flex-shrink-0">
                      <span className="text-gray-400">→</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </MainLayout>
  );
}

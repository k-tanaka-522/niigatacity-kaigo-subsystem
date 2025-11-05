'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import MainLayout from '@/components/Layout/MainLayout';
import { applicationsAPI } from '@/lib/api';

interface Application {
  id: number;
  applicationNumber: string;
  title: string;
  applicationType: string;
  status: string;
  submittedAt: string | null;
  createdAt: string;
}

export default function ApplicationsPage() {
  const router = useRouter();
  const [applications, setApplications] = useState<Application[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterStatus, setFilterStatus] = useState<string>('all');

  useEffect(() => {
    fetchApplications();
  }, []);

  const fetchApplications = async () => {
    try {
      const response = await applicationsAPI.getAll();
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
      approved: { label: '承認済み', className: 'bg-green-100 text-green-800' },
      rejected: { label: '差し戻し', className: 'bg-red-100 text-red-800' },
    };

    const config = statusConfig[status] || { label: status, className: 'bg-gray-100 text-gray-800' };

    return (
      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${config.className}`}>
        {config.label}
      </span>
    );
  };

  const filteredApplications = filterStatus === 'all'
    ? applications
    : applications.filter(app => app.status === filterStatus);

  const formatDate = (dateString: string | null) => {
    if (!dateString) return '-';
    return new Date(dateString).toLocaleString('ja-JP', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

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
        <div className="sm:flex sm:items-center sm:justify-between mb-6">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">申請一覧</h1>
            <p className="mt-2 text-sm text-gray-600">
              すべての申請を確認・管理できます ({filteredApplications.length}件)
            </p>
          </div>
          <div className="mt-4 sm:mt-0">
            <button
              onClick={() => router.push('/applications/new')}
              className="inline-flex items-center px-4 py-2 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <span className="mr-2">➕</span>
              新規申請作成
            </button>
          </div>
        </div>

        {/* フィルター */}
        <div className="mb-6 bg-white rounded-lg border border-gray-200 p-4">
          <div className="flex flex-wrap gap-2">
            <button
              onClick={() => setFilterStatus('all')}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                filterStatus === 'all'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              すべて ({applications.length})
            </button>
            <button
              onClick={() => setFilterStatus('draft')}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                filterStatus === 'draft'
                  ? 'bg-yellow-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              下書き ({applications.filter(a => a.status === 'draft').length})
            </button>
            <button
              onClick={() => setFilterStatus('submitted')}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                filterStatus === 'submitted'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              提出済み ({applications.filter(a => a.status === 'submitted').length})
            </button>
            <button
              onClick={() => setFilterStatus('approved')}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                filterStatus === 'approved'
                  ? 'bg-green-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              承認済み ({applications.filter(a => a.status === 'approved').length})
            </button>
          </div>
        </div>

        {/* 申請リスト */}
        {filteredApplications.length === 0 ? (
          <div className="text-center py-12 bg-white rounded-lg border border-gray-200">
            <span className="text-6xl mb-4 block">📋</span>
            <h3 className="text-lg font-medium text-gray-900 mb-2">申請がありません</h3>
            <p className="text-sm text-gray-500 mb-6">
              {filterStatus === 'all'
                ? '新しい申請を作成してください'
                : 'このステータスの申請はありません'}
            </p>
            {filterStatus === 'all' && (
              <button
                onClick={() => router.push('/applications/new')}
                className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700"
              >
                新規申請作成
              </button>
            )}
          </div>
        ) : (
          <div className="bg-white shadow-sm rounded-lg border border-gray-200 overflow-hidden">
            <ul className="divide-y divide-gray-200">
              {filteredApplications.map((application) => (
                <li
                  key={application.id}
                  className="hover:bg-gray-50 transition-colors cursor-pointer"
                  onClick={() => router.push(`/applications/${application.id}`)}
                >
                  <div className="px-6 py-4">
                    <div className="flex items-center justify-between">
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center space-x-3 mb-2">
                          {getStatusBadge(application.status)}
                          <span className="text-sm text-gray-500">
                            {application.applicationNumber}
                          </span>
                        </div>
                        <p className="text-sm font-medium text-gray-900 truncate">
                          {application.title}
                        </p>
                        <div className="mt-2 flex items-center text-sm text-gray-500 space-x-4">
                          <span className="flex items-center">
                            📝 {application.applicationType}
                          </span>
                          <span className="flex items-center">
                            🕒 {formatDate(application.submittedAt || application.createdAt)}
                          </span>
                        </div>
                      </div>
                      <div className="ml-4 flex-shrink-0">
                        <span className="text-gray-400 hover:text-blue-600 transition-colors">
                          →
                        </span>
                      </div>
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>
    </MainLayout>
  );
}

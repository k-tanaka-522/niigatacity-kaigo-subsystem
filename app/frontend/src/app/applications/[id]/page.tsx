'use client';

import { useEffect, useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import MainLayout from '@/components/Layout/MainLayout';
import { applicationsAPI } from '@/lib/api';

interface ApplicationDetail {
  id: number;
  applicationNumber: string;
  title: string;
  applicationType: string;
  content: string;
  status: string;
  submittedAt: string | null;
  reviewedAt: string | null;
  reviewComment: string | null;
  createdAt: string;
  updatedAt: string;
  office: {
    id: number;
    officeName: string;
    officeCode: string;
  };
  user: {
    id: number;
    name: string;
    email: string;
  };
}

export default function ApplicationDetailPage() {
  const router = useRouter();
  const params = useParams();
  const [application, setApplication] = useState<ApplicationDetail | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (params.id) {
      fetchApplication(Number(params.id));
    }
  }, [params.id]);

  const fetchApplication = async (id: number) => {
    try {
      const response = await applicationsAPI.getById(id);
      setApplication(response.data);
    } catch (error) {
      console.error('Failed to fetch application:', error);
    } finally {
      setLoading(false);
    }
  };

  const getStatusBadge = (status: string) => {
    const statusConfig: Record<string, { label: string; className: string; icon: string }> = {
      draft: { label: '下書き', className: 'bg-yellow-100 text-yellow-800 border-yellow-200', icon: '📝' },
      submitted: { label: '提出済み', className: 'bg-blue-100 text-blue-800 border-blue-200', icon: '📤' },
      approved: { label: '承認済み', className: 'bg-green-100 text-green-800 border-green-200', icon: '✅' },
      rejected: { label: '差し戻し', className: 'bg-red-100 text-red-800 border-red-200', icon: '❌' },
    };

    const config = statusConfig[status] || { label: status, className: 'bg-gray-100 text-gray-800 border-gray-200', icon: '📄' };

    return (
      <span className={`inline-flex items-center px-3 py-1.5 rounded-md text-sm font-medium border ${config.className}`}>
        <span className="mr-1.5">{config.icon}</span>
        {config.label}
      </span>
    );
  };

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

  const handlePrint = () => {
    window.print();
  };

  const handleEdit = () => {
    router.push(`/applications/${params.id}/edit`);
  };

  const handleDelete = async () => {
    if (!confirm('この申請を削除してもよろしいですか?')) return;

    try {
      await applicationsAPI.delete(Number(params.id));
      router.push('/applications');
    } catch (error) {
      console.error('Failed to delete application:', error);
      alert('削除に失敗しました');
    }
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

  if (!application) {
    return (
      <MainLayout>
        <div className="text-center py-12">
          <span className="text-6xl mb-4 block">❓</span>
          <h3 className="text-lg font-medium text-gray-900">申請が見つかりません</h3>
          <button
            onClick={() => router.push('/applications')}
            className="mt-4 inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700"
          >
            申請一覧に戻る
          </button>
        </div>
      </MainLayout>
    );
  }

  return (
    <MainLayout>
      <div className="px-4 py-6 sm:px-0">
        {/* ページヘッダー */}
        <div className="mb-6">
          <div className="flex items-center justify-between mb-4">
            <button
              onClick={() => router.push('/applications')}
              className="inline-flex items-center text-sm text-gray-600 hover:text-gray-900"
            >
              ← 申請一覧に戻る
            </button>
            <div className="flex space-x-2">
              <button
                onClick={handlePrint}
                className="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
              >
                🖨️ 印刷
              </button>
              {application.status === 'draft' && (
                <>
                  <button
                    onClick={handleEdit}
                    className="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                  >
                    ✏️ 編集
                  </button>
                  <button
                    onClick={handleDelete}
                    className="inline-flex items-center px-3 py-2 border border-red-300 shadow-sm text-sm font-medium rounded-md text-red-700 bg-white hover:bg-red-50"
                  >
                    🗑️ 削除
                  </button>
                </>
              )}
            </div>
          </div>
          <h1 className="text-3xl font-bold text-gray-900">申請詳細</h1>
        </div>

        {/* 申請情報カード */}
        <div className="bg-white shadow-sm rounded-lg border border-gray-200 overflow-hidden mb-6">
          {/* ヘッダー */}
          <div className="bg-gray-50 px-6 py-4 border-b border-gray-200">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">申請番号</p>
                <p className="text-lg font-semibold text-gray-900">{application.applicationNumber}</p>
              </div>
              {getStatusBadge(application.status)}
            </div>
          </div>

          {/* 基本情報 */}
          <div className="px-6 py-5">
            <dl className="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
              <div className="sm:col-span-2">
                <dt className="text-sm font-medium text-gray-500">申請タイトル</dt>
                <dd className="mt-1 text-lg font-semibold text-gray-900">{application.title}</dd>
              </div>

              <div>
                <dt className="text-sm font-medium text-gray-500">申請種別</dt>
                <dd className="mt-1 text-sm text-gray-900">{application.applicationType}</dd>
              </div>

              <div>
                <dt className="text-sm font-medium text-gray-500">申請日時</dt>
                <dd className="mt-1 text-sm text-gray-900">{formatDate(application.submittedAt)}</dd>
              </div>

              <div>
                <dt className="text-sm font-medium text-gray-500">事業所名</dt>
                <dd className="mt-1 text-sm text-gray-900">{application.office.officeName}</dd>
              </div>

              <div>
                <dt className="text-sm font-medium text-gray-500">事業所コード</dt>
                <dd className="mt-1 text-sm text-gray-900">{application.office.officeCode}</dd>
              </div>

              <div>
                <dt className="text-sm font-medium text-gray-500">申請者</dt>
                <dd className="mt-1 text-sm text-gray-900">{application.user.name}</dd>
              </div>

              <div>
                <dt className="text-sm font-medium text-gray-500">作成日時</dt>
                <dd className="mt-1 text-sm text-gray-900">{formatDate(application.createdAt)}</dd>
              </div>

              <div className="sm:col-span-2">
                <dt className="text-sm font-medium text-gray-500">申請内容</dt>
                <dd className="mt-2 text-sm text-gray-900 whitespace-pre-wrap bg-gray-50 p-4 rounded-md border border-gray-200">
                  {application.content || '内容が入力されていません'}
                </dd>
              </div>
            </dl>
          </div>
        </div>

        {/* 審査情報 */}
        {(application.reviewedAt || application.reviewComment) && (
          <div className="bg-white shadow-sm rounded-lg border border-gray-200 overflow-hidden">
            <div className="bg-gray-50 px-6 py-4 border-b border-gray-200">
              <h2 className="text-lg font-semibold text-gray-900">審査情報</h2>
            </div>
            <div className="px-6 py-5">
              <dl className="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
                <div>
                  <dt className="text-sm font-medium text-gray-500">審査日時</dt>
                  <dd className="mt-1 text-sm text-gray-900">{formatDate(application.reviewedAt)}</dd>
                </div>

                {application.reviewComment && (
                  <div className="sm:col-span-2">
                    <dt className="text-sm font-medium text-gray-500">審査コメント</dt>
                    <dd className="mt-2 text-sm text-gray-900 whitespace-pre-wrap bg-yellow-50 p-4 rounded-md border border-yellow-200">
                      {application.reviewComment}
                    </dd>
                  </div>
                )}
              </dl>
            </div>
          </div>
        )}
      </div>

      {/* 印刷用スタイル */}
      <style jsx global>{`
        @media print {
          nav, button {
            display: none !important;
          }
          .bg-gray-50 {
            background-color: white !important;
          }
        }
      `}</style>
    </MainLayout>
  );
}

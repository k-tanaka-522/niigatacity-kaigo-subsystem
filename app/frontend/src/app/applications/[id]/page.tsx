'use client';

import { useEffect, useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import MainLayout from '@/components/Layout/MainLayout';
import { applicationsAPI } from '@/lib/api';
import { Application } from '@/types';

export default function ApplicationDetailPage() {
  const router = useRouter();
  const params = useParams();
  const id = Number(params.id);

  const [application, setApplication] = useState<Application | null>(null);
  const [loading, setLoading] = useState(true);
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    const userData = localStorage.getItem('user');
    if (userData) {
      setUser(JSON.parse(userData));
    }
    fetchApplication();
  }, [id]);

  const fetchApplication = async () => {
    try {
      const response = await applicationsAPI.getById(id);
      setApplication(response.data);
    } catch (error) {
      console.error('Failed to fetch application:', error);
      alert('申請の取得に失敗しました');
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = () => {
    router.push(`/applications/${id}/edit`);
  };

  const handleDelete = async () => {
    if (!confirm('この申請を削除してもよろしいですか?')) {
      return;
    }

    try {
      await applicationsAPI.delete(id);
      alert('申請を削除しました');
      router.push('/applications');
    } catch (error: any) {
      alert(error.response?.data?.message || '削除に失敗しました');
    }
  };

  const handleSubmit = async () => {
    if (!confirm('この申請を提出してもよろしいですか?')) {
      return;
    }

    try {
      await applicationsAPI.submit(id);
      alert('申請を提出しました');
      fetchApplication();
    } catch (error: any) {
      alert(error.response?.data?.message || '提出に失敗しました');
    }
  };

  const handleReview = async (approved: boolean) => {
    const comment = prompt(approved ? '承認コメントを入力してください（任意）' : '却下理由を入力してください（任意）');

    try {
      await applicationsAPI.review(id, { approved, comment: comment || undefined });
      alert(approved ? '申請を承認しました' : '申請を却下しました');
      fetchApplication();
    } catch (error: any) {
      alert(error.response?.data?.message || '審査に失敗しました');
    }
  };

  const handlePrint = () => {
    window.print();
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
      <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${config.className}`}>
        {config.label}
      </span>
    );
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
          <p className="text-gray-500">申請が見つかりません</p>
          <button
            onClick={() => router.push('/applications')}
            className="mt-4 text-blue-600 hover:text-blue-800"
          >
            申請一覧に戻る
          </button>
        </div>
      </MainLayout>
    );
  }

  const canEdit = application.status === 'draft' && user?.id === application.userId;
  const canSubmit = application.status === 'draft' && user?.id === application.userId;
  const canReview = (application.status === 'submitted' || application.status === 'in_review') &&
                    (user?.role === 'admin' || user?.role === 'city_staff');

  return (
    <MainLayout>
      <style jsx global>{`
        @media print {
          nav, button, .no-print {
            display: none !important;
          }
        }
      `}</style>

      <div className="px-4 py-6 sm:px-0">
        <div className="mb-6 flex items-center justify-between no-print">
          <button
            onClick={() => router.push('/applications')}
            className="text-gray-600 hover:text-gray-900 flex items-center"
          >
            ← 一覧に戻る
          </button>
          <div className="flex gap-2">
            <button
              onClick={handlePrint}
              className="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
            >
              印刷
            </button>
            {canEdit && (
              <>
                <button
                  onClick={handleEdit}
                  className="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
                >
                  編集
                </button>
                <button
                  onClick={handleDelete}
                  className="px-4 py-2 border border-red-300 rounded-md text-sm font-medium text-red-700 bg-white hover:bg-red-50"
                >
                  削除
                </button>
              </>
            )}
            {canSubmit && (
              <button
                onClick={handleSubmit}
                className="px-4 py-2 border border-transparent rounded-md text-sm font-medium text-white bg-blue-600 hover:bg-blue-700"
              >
                提出する
              </button>
            )}
          </div>
        </div>

        <div className="bg-white shadow-sm rounded-lg border border-gray-200 overflow-hidden">
          <div className="bg-blue-50 border-b border-blue-100 px-6 py-4">
            <div className="flex items-center justify-between">
              <div>
                <h1 className="text-2xl font-bold text-gray-900">{application.title}</h1>
                <p className="mt-1 text-sm text-gray-600">申請番号: {application.applicationNumber}</p>
              </div>
              {getStatusBadge(application.status)}
            </div>
          </div>

          <div className="px-6 py-5 space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <dt className="text-sm font-medium text-gray-500">申請種別</dt>
                <dd className="mt-1 text-base text-gray-900">{application.applicationType}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500">申請事業所</dt>
                <dd className="mt-1 text-base text-gray-900">{application.officeName}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500">申請者</dt>
                <dd className="mt-1 text-base text-gray-900">{application.userName}</dd>
              </div>
              <div>
                <dt className="text-sm font-medium text-gray-500">作成日時</dt>
                <dd className="mt-1 text-base text-gray-900">
                  {new Date(application.createdAt).toLocaleString('ja-JP')}
                </dd>
              </div>
            </div>

            <div className="border-t border-gray-200 pt-6">
              <dt className="text-sm font-medium text-gray-500 mb-2">申請内容</dt>
              <dd className="text-base text-gray-900 whitespace-pre-wrap bg-gray-50 p-4 rounded-md">
                {application.content || '（内容なし）'}
              </dd>
            </div>

            {application.submittedAt && (
              <div className="border-t border-gray-200 pt-6">
                <dt className="text-sm font-medium text-gray-500 mb-2">提出日時</dt>
                <dd className="text-base text-gray-900">
                  {new Date(application.submittedAt).toLocaleString('ja-JP')}
                </dd>
              </div>
            )}

            {application.reviewedAt && (
              <div className="border-t border-gray-200 pt-6 bg-gray-50 -mx-6 px-6 py-4">
                <h3 className="text-lg font-medium text-gray-900 mb-4">審査結果</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <dt className="text-sm font-medium text-gray-500">審査者</dt>
                    <dd className="mt-1 text-base text-gray-900">{application.reviewerName}</dd>
                  </div>
                  <div>
                    <dt className="text-sm font-medium text-gray-500">審査日時</dt>
                    <dd className="mt-1 text-base text-gray-900">
                      {new Date(application.reviewedAt).toLocaleString('ja-JP')}
                    </dd>
                  </div>
                </div>
                {application.reviewComment && (
                  <div className="mt-4">
                    <dt className="text-sm font-medium text-gray-500 mb-2">審査コメント</dt>
                    <dd className="text-base text-gray-900 whitespace-pre-wrap bg-white p-4 rounded-md border border-gray-200">
                      {application.reviewComment}
                    </dd>
                  </div>
                )}
              </div>
            )}
          </div>

          {canReview && (
            <div className="bg-gray-50 border-t border-gray-200 px-6 py-4 flex gap-3 justify-end no-print">
              <button
                onClick={() => handleReview(false)}
                className="px-6 py-2 border border-red-300 rounded-md text-sm font-medium text-red-700 bg-white hover:bg-red-50"
              >
                却下する
              </button>
              <button
                onClick={() => handleReview(true)}
                className="px-6 py-2 border border-transparent rounded-md text-sm font-medium text-white bg-green-600 hover:bg-green-700"
              >
                承認する
              </button>
            </div>
          )}
        </div>
      </div>
    </MainLayout>
  );
}

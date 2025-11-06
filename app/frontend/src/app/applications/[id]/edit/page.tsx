'use client';

import { useEffect, useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { useForm } from 'react-hook-form';
import MainLayout from '@/components/Layout/MainLayout';
import { applicationsAPI } from '@/lib/api';

interface ApplicationForm {
  applicationType: string;
  title: string;
  content: string;
}

export default function ApplicationEditPage() {
  const router = useRouter();
  const params = useParams();
  const id = Number(params.id);

  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  const { register, handleSubmit, setValue, formState: { errors } } = useForm<ApplicationForm>();

  useEffect(() => {
    fetchApplication();
  }, [id]);

  const fetchApplication = async () => {
    try {
      const response = await applicationsAPI.getById(id);
      const app = response.data;

      // Check if it's editable
      if (app.status !== 'draft') {
        alert('下書き状態の申請のみ編集できます');
        router.push(`/applications/${id}`);
        return;
      }

      // Set form values
      setValue('applicationType', app.applicationType);
      setValue('title', app.title);
      setValue('content', app.content || '');
    } catch (error) {
      console.error('Failed to fetch application:', error);
      alert('申請の取得に失敗しました');
      router.push('/applications');
    } finally {
      setLoading(false);
    }
  };

  const onSubmit = async (data: ApplicationForm) => {
    setSubmitting(true);
    try {
      await applicationsAPI.update(id, data);
      alert('申請を更新しました');
      router.push(`/applications/${id}`);
    } catch (error: any) {
      alert(error.response?.data?.message || '更新に失敗しました');
    } finally {
      setSubmitting(false);
    }
  };

  const handleCancel = () => {
    if (confirm('編集内容を破棄してもよろしいですか?')) {
      router.push(`/applications/${id}`);
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

  return (
    <MainLayout>
      <div className="px-4 py-6 sm:px-0">
        <div className="mb-6">
          <button
            onClick={() => router.push(`/applications/${id}`)}
            className="text-gray-600 hover:text-gray-900 flex items-center"
          >
            ← 詳細に戻る
          </button>
        </div>

        <div className="bg-white shadow-sm rounded-lg border border-gray-200 p-6">
          <h1 className="text-2xl font-bold text-gray-900 mb-6">申請を編集</h1>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
            <div>
              <label htmlFor="applicationType" className="block text-sm font-medium text-gray-700 mb-2">
                申請種別 <span className="text-red-600">*</span>
              </label>
              <select
                {...register('applicationType', { required: '申請種別は必須です' })}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">選択してください</option>
                <option value="新規指定">新規指定</option>
                <option value="変更届">変更届</option>
                <option value="廃止届">廃止届</option>
                <option value="休止届">休止届</option>
                <option value="再開届">再開届</option>
              </select>
              {errors.applicationType && (
                <p className="mt-1 text-sm text-red-600">{errors.applicationType.message}</p>
              )}
            </div>

            <div>
              <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-2">
                件名 <span className="text-red-600">*</span>
              </label>
              <input
                {...register('title', { required: '件名は必須です' })}
                type="text"
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="例: 介護サービス事業所の新規指定申請について"
              />
              {errors.title && (
                <p className="mt-1 text-sm text-red-600">{errors.title.message}</p>
              )}
            </div>

            <div>
              <label htmlFor="content" className="block text-sm font-medium text-gray-700 mb-2">
                申請内容
              </label>
              <textarea
                {...register('content')}
                rows={10}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="申請の詳細内容を記載してください..."
              />
            </div>

            <div className="flex gap-3 justify-end pt-4 border-t border-gray-200">
              <button
                type="button"
                onClick={handleCancel}
                disabled={submitting}
                className="px-6 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50"
              >
                キャンセル
              </button>
              <button
                type="submit"
                disabled={submitting}
                className="px-6 py-2 border border-transparent rounded-md text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 disabled:opacity-50"
              >
                {submitting ? '保存中...' : '保存'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </MainLayout>
  );
}

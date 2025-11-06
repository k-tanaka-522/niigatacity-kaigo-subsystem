'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useForm } from 'react-hook-form';
import MainLayout from '@/components/Layout/MainLayout';
import { applicationsAPI } from '@/lib/api';

interface ApplicationForm {
  title: string;
  applicationType: string;
  content: string;
}

export default function NewApplicationPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [saveAsDraft, setSaveAsDraft] = useState(false);
  const { register, handleSubmit, formState: { errors } } = useForm<ApplicationForm>();

  const applicationTypes = [
    { value: '新規申請', label: '新規申請' },
    { value: '変更申請', label: '変更申請' },
    { value: '廃止申請', label: '廃止申請' },
    { value: '更新申請', label: '更新申請' },
  ];

  const onSubmit = async (data: ApplicationForm, isDraft: boolean) => {
    setLoading(true);
    setSaveAsDraft(isDraft);

    try {
      const response = await applicationsAPI.create({
        ...data,
        status: isDraft ? 'draft' : 'submitted',
      });

      alert(isDraft ? '下書きとして保存しました' : '申請を提出しました');
      router.push(`/applications/${response.data.id}`);
    } catch (error) {
      console.error('Failed to create application:', error);
      alert('申請の作成に失敗しました');
    } finally {
      setLoading(false);
      setSaveAsDraft(false);
    }
  };

  return (
    <MainLayout>
      <div className="px-4 py-6 sm:px-0">
        {/* ページヘッダー */}
        <div className="mb-6">
          <button
            onClick={() => router.push('/applications')}
            className="inline-flex items-center text-sm text-gray-600 hover:text-gray-900 mb-4"
          >
            ← 申請一覧に戻る
          </button>
          <h1 className="text-3xl font-bold text-gray-900">新規申請作成</h1>
          <p className="mt-2 text-sm text-gray-600">
            必要事項を入力して、申請を作成してください
          </p>
        </div>

        {/* フォーム */}
        <form onSubmit={handleSubmit((data) => onSubmit(data, false))} className="space-y-6">
          {/* 申請情報カード */}
          <div className="bg-white shadow-sm rounded-lg border border-gray-200 overflow-hidden">
            <div className="bg-gray-50 px-6 py-4 border-b border-gray-200">
              <h2 className="text-lg font-semibold text-gray-900">申請情報</h2>
            </div>
            <div className="px-6 py-5 space-y-6">
              {/* 申請種別 */}
              <div>
                <label htmlFor="applicationType" className="block text-sm font-medium text-gray-700 mb-2">
                  申請種別 <span className="text-red-600">*</span>
                </label>
                <select
                  {...register('applicationType', { required: '申請種別は必須です' })}
                  className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                >
                  <option value="">選択してください</option>
                  {applicationTypes.map((type) => (
                    <option key={type.value} value={type.value}>
                      {type.label}
                    </option>
                  ))}
                </select>
                {errors.applicationType && (
                  <p className="mt-1 text-sm text-red-600">{errors.applicationType.message}</p>
                )}
              </div>

              {/* 申請タイトル */}
              <div>
                <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-2">
                  申請タイトル <span className="text-red-600">*</span>
                </label>
                <input
                  {...register('title', {
                    required: '申請タイトルは必須です',
                    maxLength: { value: 200, message: '200文字以内で入力してください' }
                  })}
                  type="text"
                  className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                  placeholder="例: 訪問介護サービス新規申請"
                />
                {errors.title && (
                  <p className="mt-1 text-sm text-red-600">{errors.title.message}</p>
                )}
              </div>

              {/* 申請内容 */}
              <div>
                <label htmlFor="content" className="block text-sm font-medium text-gray-700 mb-2">
                  申請内容 <span className="text-red-600">*</span>
                </label>
                <textarea
                  {...register('content', { required: '申請内容は必須です' })}
                  rows={10}
                  className="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                  placeholder="申請の詳細内容を入力してください"
                />
                {errors.content && (
                  <p className="mt-1 text-sm text-red-600">{errors.content.message}</p>
                )}
                <p className="mt-2 text-sm text-gray-500">
                  申請の背景、目的、具体的な内容などを詳しく記載してください
                </p>
              </div>
            </div>
          </div>

          {/* 注意事項 */}
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <div className="flex">
              <div className="flex-shrink-0">
                <span className="text-blue-400 text-xl">ℹ️</span>
              </div>
              <div className="ml-3">
                <h3 className="text-sm font-medium text-blue-800">申請にあたっての注意事項</h3>
                <div className="mt-2 text-sm text-blue-700">
                  <ul className="list-disc list-inside space-y-1">
                    <li>提出後は編集できません。内容を十分にご確認ください。</li>
                    <li>下書き保存した申請は後から編集・提出できます。</li>
                    <li>審査には通常3〜5営業日かかります。</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>

          {/* ボタン */}
          <div className="flex justify-between">
            <button
              type="button"
              onClick={() => router.push('/applications')}
              className="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              キャンセル
            </button>
            <div className="flex space-x-3">
              <button
                type="button"
                onClick={handleSubmit((data) => onSubmit(data, true))}
                disabled={loading}
                className="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500 disabled:bg-gray-100 disabled:cursor-not-allowed"
              >
                {saveAsDraft && loading ? (
                  <>
                    <svg className="animate-spin -ml-1 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    保存中...
                  </>
                ) : (
                  <>
                    📝 下書き保存
                  </>
                )}
              </button>
              <button
                type="submit"
                disabled={loading}
                className="inline-flex items-center px-6 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-400 disabled:cursor-not-allowed"
              >
                {!saveAsDraft && loading ? (
                  <>
                    <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    提出中...
                  </>
                ) : (
                  <>
                    📤 申請を提出
                  </>
                )}
              </button>
            </div>
          </div>
        </form>
      </div>
    </MainLayout>
  );
}

/**
 * 事業所編集画面
 *
 * 介護保険事業所の情報を編集します。
 * React Hook Formによるフォーム管理とバリデーションを実装しています。
 * ダミーデータを使用したプロトタイプ実装です。
 *
 * @page /offices/[id]/edit
 */
'use client';

import { useEffect, useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { useForm } from 'react-hook-form';
import MainLayout from '@/components/Layout/MainLayout';

/** 事業所編集フォームの型定義 */
interface OfficeForm {
  /** 事業所名 */
  name: string;
  /** サービス種別 */
  serviceType: string;
  /** 事業所番号（10桁の数字） */
  officeNumber: string;
  /** 住所 */
  address: string;
  /** 電話番号（ハイフン付き） */
  phone: string;
  /** FAX番号（ハイフン付き） */
  fax: string;
  /** メールアドレス */
  email: string;
  /** 代表者氏名 */
  representative: string;
  /** 管理者氏名 */
  manager: string;
  /** 指定日 */
  designatedDate: string;
  /** 有効期限 */
  expiryDate: string;
  /** サービス提供地域の配列 */
  serviceArea: string[];
}

/** ダミー事業所データ（詳細画面と同じ） */
const officeData: { [key: string]: OfficeForm } = {
  "1": {
    name: "介護太郎訪問介護事業所",
    serviceType: "訪問介護",
    officeNumber: "1510100001",
    address: "新潟市中央区東大通1-1-1 介護ビル3F",
    phone: "025-123-4567",
    fax: "025-123-4568",
    email: "info@kaigo-taro.jp",
    representative: "介護 太郎",
    manager: "看護 花子",
    designatedDate: "2020-04-01",
    expiryDate: "2026-03-31",
    serviceArea: ["中央区", "東区", "西区"],
  },
  "2": {
    name: "さくらデイサービス",
    serviceType: "通所介護",
    officeNumber: "1510200002",
    address: "新潟市西区小針3-5-10",
    phone: "025-234-5678",
    fax: "025-234-5679",
    email: "info@sakura-day.jp",
    representative: "桜井 春子",
    manager: "田中 夏美",
    designatedDate: "2019-10-01",
    expiryDate: "2025-09-30",
    serviceArea: ["西区", "中央区"],
  },
  "3": {
    name: "あおぞら居宅介護支援事業所",
    serviceType: "居宅介護支援",
    officeNumber: "1510300003",
    address: "新潟市東区山の下町10-20",
    phone: "025-345-6789",
    fax: "025-345-6790",
    email: "contact@aozora-care.jp",
    representative: "青空 一郎",
    manager: "山下 二郎",
    designatedDate: "2021-07-01",
    expiryDate: "2027-06-30",
    serviceArea: ["東区", "北区"],
  },
  "4": {
    name: "ひまわり訪問看護ステーション",
    serviceType: "訪問看護",
    officeNumber: "1510400004",
    address: "新潟市江南区亀田本町5-1-1",
    phone: "025-456-7890",
    fax: "025-456-7891",
    email: "info@himawari-nursing.jp",
    representative: "向日葵 太郎",
    manager: "亀田 花子",
    designatedDate: "2018-04-01",
    expiryDate: "2024-03-31",
    serviceArea: ["江南区", "秋葉区"],
  },
  "5": {
    name: "もみじ訪問リハビリテーション",
    serviceType: "訪問リハビリテーション",
    officeNumber: "1510500005",
    address: "新潟市南区白根1234",
    phone: "025-567-8901",
    fax: "025-567-8902",
    email: "info@momiji-rehab.jp",
    representative: "紅葉 秋男",
    manager: "白根 冬美",
    designatedDate: "2022-10-01",
    expiryDate: "2028-09-30",
    serviceArea: ["南区", "西蒲区"],
  },
};

/** 新潟市の区一覧（サービス提供地域選択用） */
const availableAreas = [
  "中央区",
  "東区",
  "西区",
  "北区",
  "南区",
  "江南区",
  "秋葉区",
  "西蒲区",
];

/**
 * 事業所編集ページコンポーネント
 *
 * URLパラメータから事業所IDを取得し、該当する事業所の情報を編集フォームで表示します。
 * React Hook Formによるバリデーション付きフォームを実装しています。
 */
export default function OfficeEditPage() {
  const router = useRouter();
  const params = useParams();
  const id = params.id as string;

  // 状態管理
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [selectedAreas, setSelectedAreas] = useState<string[]>([]);

  // React Hook Form の初期化
  const { register, handleSubmit, setValue, formState: { errors } } = useForm<OfficeForm>();

  useEffect(() => {
    fetchOffice();
  }, [id]);

  /**
   * 事業所データの取得とフォームへの初期値設定
   * プロトタイプ段階ではダミーデータから取得
   */
  const fetchOffice = async () => {
    try {
      const office = officeData[id];

      if (!office) {
        alert('事業所が見つかりません');
        router.push('/offices');
        return;
      }

      // React Hook FormのsetValueでフォームに初期値を設定
      setValue('name', office.name);
      setValue('serviceType', office.serviceType);
      setValue('officeNumber', office.officeNumber);
      setValue('address', office.address);
      setValue('phone', office.phone);
      setValue('fax', office.fax);
      setValue('email', office.email);
      setValue('representative', office.representative);
      setValue('manager', office.manager);
      setValue('designatedDate', office.designatedDate);
      setValue('expiryDate', office.expiryDate);
      setSelectedAreas(office.serviceArea);
    } catch (error) {
      console.error('Failed to fetch office:', error);
      alert('事業所の取得に失敗しました');
      router.push('/offices');
    } finally {
      setLoading(false);
    }
  };

  /**
   * フォーム送信ハンドラー
   * プロトタイプ段階ではダミー保存処理（500ms待機）
   * 本番環境ではAPI経由で更新予定
   */
  const onSubmit = async (data: OfficeForm) => {
    setSubmitting(true);
    try {
      // ダミー保存処理（実際のAPI呼び出しはバックエンド実装後）
      await new Promise(resolve => setTimeout(resolve, 500));

      alert('事業所情報を更新しました');
      router.push(`/offices/${id}`);
    } catch (error: any) {
      alert('更新に失敗しました');
    } finally {
      setSubmitting(false);
    }
  };

  /** キャンセルボタンハンドラー（詳細画面に戻る） */
  const handleCancel = () => {
    router.push(`/offices/${id}`);
  };

  /**
   * サービス提供地域のチェックボックス変更ハンドラー
   * チェック時は配列に追加、チェック外し時は配列から削除
   */
  const handleAreaChange = (area: string, checked: boolean) => {
    if (checked) {
      setSelectedAreas([...selectedAreas, area]);
    } else {
      setSelectedAreas(selectedAreas.filter(a => a !== area));
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
        {/* パンくずリスト */}
        <nav className="mb-6 text-sm text-gray-600">
          <button onClick={() => router.push('/')} className="hover:text-gray-900">
            ホーム
          </button>
          <span className="mx-2">&gt;</span>
          <button onClick={() => router.push('/offices')} className="hover:text-gray-900">
            事業所管理
          </button>
          <span className="mx-2">&gt;</span>
          <button onClick={() => router.push(`/offices/${id}`)} className="hover:text-gray-900">
            {officeData[id]?.name || '事業所詳細'}
          </button>
          <span className="mx-2">&gt;</span>
          <span className="text-gray-900">編集</span>
        </nav>

        <div className="bg-white shadow-sm rounded-lg border border-gray-200 p-6">
          <h1 className="text-2xl font-bold text-gray-900 mb-6">事業所情報の編集</h1>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-8">
            {/* 1. 基本情報 */}
            <div className="border-b border-gray-200 pb-6">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">基本情報</h2>
              <div className="space-y-4">
                <div>
                  <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-2">
                    事業所名 <span className="text-red-600">*</span>
                  </label>
                  <input
                    {...register('name', { required: '事業所名は必須です' })}
                    type="text"
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="例: 介護太郎訪問介護事業所"
                  />
                  {errors.name && (
                    <p className="mt-1 text-sm text-red-600">{errors.name.message}</p>
                  )}
                </div>

                <div>
                  <label htmlFor="serviceType" className="block text-sm font-medium text-gray-700 mb-2">
                    サービス種別 <span className="text-red-600">*</span>
                  </label>
                  <select
                    {...register('serviceType', { required: 'サービス種別は必須です' })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="">選択してください</option>
                    <option value="訪問介護">訪問介護</option>
                    <option value="通所介護">通所介護</option>
                    <option value="居宅介護支援">居宅介護支援</option>
                  </select>
                  {errors.serviceType && (
                    <p className="mt-1 text-sm text-red-600">{errors.serviceType.message}</p>
                  )}
                </div>

                <div>
                  <label htmlFor="officeNumber" className="block text-sm font-medium text-gray-700 mb-2">
                    事業所番号 <span className="text-red-600">*</span>
                  </label>
                  <input
                    {...register('officeNumber', {
                      required: '事業所番号は必須です',
                      pattern: {
                        value: /^\d{10}$/,
                        message: '事業所番号は10桁の数字で入力してください',
                      },
                    })}
                    type="text"
                    maxLength={10}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="1510100001"
                  />
                  {errors.officeNumber && (
                    <p className="mt-1 text-sm text-red-600">{errors.officeNumber.message}</p>
                  )}
                </div>
              </div>
            </div>

            {/* 2. 連絡先 */}
            <div className="border-b border-gray-200 pb-6">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">連絡先</h2>
              <div className="space-y-4">
                <div>
                  <label htmlFor="address" className="block text-sm font-medium text-gray-700 mb-2">
                    住所 <span className="text-red-600">*</span>
                  </label>
                  <input
                    {...register('address', { required: '住所は必須です' })}
                    type="text"
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="例: 新潟市中央区東大通1-1-1 介護ビル3F"
                  />
                  {errors.address && (
                    <p className="mt-1 text-sm text-red-600">{errors.address.message}</p>
                  )}
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label htmlFor="phone" className="block text-sm font-medium text-gray-700 mb-2">
                      電話番号 <span className="text-red-600">*</span>
                    </label>
                    <input
                      {...register('phone', {
                        required: '電話番号は必須です',
                        pattern: {
                          value: /^\d{2,4}-\d{2,4}-\d{4}$/,
                          message: '電話番号はハイフン付きで入力してください（例: 025-123-4567）',
                        },
                      })}
                      type="text"
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="025-123-4567"
                    />
                    {errors.phone && (
                      <p className="mt-1 text-sm text-red-600">{errors.phone.message}</p>
                    )}
                  </div>

                  <div>
                    <label htmlFor="fax" className="block text-sm font-medium text-gray-700 mb-2">
                      FAX
                    </label>
                    <input
                      {...register('fax', {
                        pattern: {
                          value: /^\d{2,4}-\d{2,4}-\d{4}$/,
                          message: 'FAXはハイフン付きで入力してください（例: 025-123-4568）',
                        },
                      })}
                      type="text"
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="025-123-4568"
                    />
                    {errors.fax && (
                      <p className="mt-1 text-sm text-red-600">{errors.fax.message}</p>
                    )}
                  </div>
                </div>

                <div>
                  <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-2">
                    メールアドレス <span className="text-red-600">*</span>
                  </label>
                  <input
                    {...register('email', {
                      required: 'メールアドレスは必須です',
                      pattern: {
                        value: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i,
                        message: '有効なメールアドレスを入力してください',
                      },
                    })}
                    type="email"
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="info@example.jp"
                  />
                  {errors.email && (
                    <p className="mt-1 text-sm text-red-600">{errors.email.message}</p>
                  )}
                </div>
              </div>
            </div>

            {/* 3. 代表者・管理者情報 */}
            <div className="border-b border-gray-200 pb-6">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">代表者・管理者情報</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label htmlFor="representative" className="block text-sm font-medium text-gray-700 mb-2">
                    代表者氏名 <span className="text-red-600">*</span>
                  </label>
                  <input
                    {...register('representative', { required: '代表者氏名は必須です' })}
                    type="text"
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="例: 介護 太郎"
                  />
                  {errors.representative && (
                    <p className="mt-1 text-sm text-red-600">{errors.representative.message}</p>
                  )}
                </div>

                <div>
                  <label htmlFor="manager" className="block text-sm font-medium text-gray-700 mb-2">
                    管理者氏名 <span className="text-red-600">*</span>
                  </label>
                  <input
                    {...register('manager', { required: '管理者氏名は必須です' })}
                    type="text"
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="例: 看護 花子"
                  />
                  {errors.manager && (
                    <p className="mt-1 text-sm text-red-600">{errors.manager.message}</p>
                  )}
                </div>
              </div>
            </div>

            {/* 4. 指定情報 */}
            <div className="border-b border-gray-200 pb-6">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">指定情報</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label htmlFor="designatedDate" className="block text-sm font-medium text-gray-700 mb-2">
                    指定日 <span className="text-red-600">*</span>
                  </label>
                  <input
                    {...register('designatedDate', { required: '指定日は必須です' })}
                    type="date"
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                  {errors.designatedDate && (
                    <p className="mt-1 text-sm text-red-600">{errors.designatedDate.message}</p>
                  )}
                </div>

                <div>
                  <label htmlFor="expiryDate" className="block text-sm font-medium text-gray-700 mb-2">
                    有効期限 <span className="text-red-600">*</span>
                  </label>
                  <input
                    {...register('expiryDate', { required: '有効期限は必須です' })}
                    type="date"
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                  {errors.expiryDate && (
                    <p className="mt-1 text-sm text-red-600">{errors.expiryDate.message}</p>
                  )}
                </div>
              </div>
            </div>

            {/* 5. サービス提供地域 */}
            <div className="pb-6">
              <h2 className="text-lg font-semibold text-gray-900 mb-4">サービス提供地域</h2>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                {availableAreas.map((area) => (
                  <label key={area} className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      checked={selectedAreas.includes(area)}
                      onChange={(e) => handleAreaChange(area, e.target.checked)}
                      className="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                    />
                    <span className="text-sm text-gray-700">{area}</span>
                  </label>
                ))}
              </div>
            </div>

            {/* アクションボタン */}
            <div className="flex gap-3 justify-end pt-4 border-t border-gray-200">
              <button
                type="button"
                onClick={handleCancel}
                disabled={submitting}
                className="px-6 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50"
              >
                キャンセル
              >
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

/**
 * 事業所詳細画面
 *
 * 介護保険事業所の詳細情報を表示します。
 * 基本情報、連絡先、代表者/管理者情報、指定情報、サービス提供地域をセクションごとに表示します。
 * ダミーデータを使用したプロトタイプ実装です。
 *
 * @page /offices/[id]
 */
'use client';

import { useEffect, useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import MainLayout from '@/components/Layout/MainLayout';

/** 事業所詳細の型定義 */
interface OfficeDetail {
  /** 事業所ID */
  id: number;
  /** 事業所名 */
  name: string;
  /** サービス種別（訪問介護、通所介護など） */
  serviceType: string;
  /** 事業所番号（10桁） */
  officeNumber: string;
  /** 事業所の所在地 */
  address: string;
  /** 電話番号 */
  phone: string;
  /** FAX番号 */
  fax: string;
  /** メールアドレス */
  email: string;
  /** 代表者氏名 */
  representative: string;
  /** 管理者氏名 */
  manager: string;
  /** 指定日（YYYY-MM-DD） */
  designatedDate: string;
  /** 有効期限（YYYY-MM-DD） */
  expiryDate: string;
  /** サービス提供地域の配列 */
  serviceArea: string[];
}

/** ダミー事業所詳細データ（プロトタイプ用） */
const officeData: { [key: string]: OfficeDetail } = {
  "1": {
    id: 1,
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
    id: 2,
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
    id: 3,
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
    id: 4,
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
    id: 5,
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

/**
 * 事業所詳細ページコンポーネント
 *
 * URLパラメータから事業所IDを取得し、該当する事業所の詳細情報を表示します。
 * 編集画面への遷移や一覧画面への戻りナビゲーションを提供します。
 */
export default function OfficeDetailPage() {
  const router = useRouter();
  const params = useParams();
  const id = params.id as string;

  // 事業所情報とローディング状態の管理
  const [office, setOffice] = useState<OfficeDetail | null>(null);
  const [loading, setLoading] = useState(true);

  /**
   * 事業所詳細データの取得
   * プロトタイプ段階ではダミーデータから取得
   * 本番環境ではAPI経由で取得予定
   */
  useEffect(() => {
    const foundOffice = officeData[id];
    setOffice(foundOffice || null);
    setLoading(false);
  }, [id]);

  /** 編集画面への遷移 */
  const handleEdit = () => {
    router.push(`/offices/${id}/edit`);
  };

  /** 事業所一覧画面への戻り */
  const handleBack = () => {
    router.push('/offices');
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

  if (!office) {
    return (
      <MainLayout>
        <div className="text-center py-12">
          <p className="text-gray-500">事業所が見つかりません</p>
          <button
            onClick={handleBack}
            className="mt-4 text-blue-600 hover:text-blue-800"
          >
            事業所一覧に戻る
          </button>
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
          <button onClick={handleBack} className="hover:text-gray-900">
            事業所管理
          </button>
          <span className="mx-2">&gt;</span>
          <span className="text-gray-900">{office.name}</span>
        </nav>

        {/* ヘッダー */}
        <div className="mb-6 flex items-center justify-between">
          <h1 className="text-3xl font-bold text-gray-900">{office.name}</h1>
          <button
            onClick={handleEdit}
            className="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
          >
            編集
          </button>
        </div>

        {/* カードセクション */}
        <div className="space-y-6">
          {/* 1. 基本情報 */}
          <div className="bg-white shadow-sm rounded-lg border border-gray-200 overflow-hidden">
            <div className="bg-blue-50 border-b border-blue-100 px-6 py-4">
              <h2 className="text-lg font-semibold text-gray-900">基本情報</h2>
            </div>
            <div className="px-6 py-5">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <dt className="text-sm font-medium text-gray-500">事業所名</dt>
                  <dd className="mt-1 text-base text-gray-900">{office.name}</dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500">サービス種別</dt>
                  <dd className="mt-1 text-base text-gray-900">{office.serviceType}</dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500">事業所番号</dt>
                  <dd className="mt-1 text-base text-gray-900">{office.officeNumber}</dd>
                </div>
              </div>
            </div>
          </div>

          {/* 2. 連絡先 */}
          <div className="bg-white shadow-sm rounded-lg border border-gray-200 overflow-hidden">
            <div className="bg-blue-50 border-b border-blue-100 px-6 py-4">
              <h2 className="text-lg font-semibold text-gray-900">連絡先</h2>
            </div>
            <div className="px-6 py-5">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="md:col-span-2">
                  <dt className="text-sm font-medium text-gray-500">住所</dt>
                  <dd className="mt-1 text-base text-gray-900">{office.address}</dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500">電話番号</dt>
                  <dd className="mt-1 text-base text-gray-900">{office.phone}</dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500">FAX</dt>
                  <dd className="mt-1 text-base text-gray-900">{office.fax}</dd>
                </div>
                <div className="md:col-span-2">
                  <dt className="text-sm font-medium text-gray-500">メールアドレス</dt>
                  <dd className="mt-1 text-base text-gray-900">{office.email}</dd>
                </div>
              </div>
            </div>
          </div>

          {/* 3. 代表者・管理者情報 */}
          <div className="bg-white shadow-sm rounded-lg border border-gray-200 overflow-hidden">
            <div className="bg-blue-50 border-b border-blue-100 px-6 py-4">
              <h2 className="text-lg font-semibold text-gray-900">代表者・管理者情報</h2>
            </div>
            <div className="px-6 py-5">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <dt className="text-sm font-medium text-gray-500">代表者氏名</dt>
                  <dd className="mt-1 text-base text-gray-900">{office.representative}</dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500">管理者氏名</dt>
                  <dd className="mt-1 text-base text-gray-900">{office.manager}</dd>
                </div>
              </div>
            </div>
          </div>

          {/* 4. 指定情報 */}
          <div className="bg-white shadow-sm rounded-lg border border-gray-200 overflow-hidden">
            <div className="bg-blue-50 border-b border-blue-100 px-6 py-4">
              <h2 className="text-lg font-semibold text-gray-900">指定情報</h2>
            </div>
            <div className="px-6 py-5">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <dt className="text-sm font-medium text-gray-500">指定日</dt>
                  <dd className="mt-1 text-base text-gray-900">
                    {new Date(office.designatedDate).toLocaleDateString('ja-JP')}
                  </dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500">有効期限</dt>
                  <dd className="mt-1 text-base text-gray-900">
                    {new Date(office.expiryDate).toLocaleDateString('ja-JP')}
                  </dd>
                </div>
              </div>
            </div>
          </div>

          {/* 5. サービス提供地域 */}
          <div className="bg-white shadow-sm rounded-lg border border-gray-200 overflow-hidden">
            <div className="bg-blue-50 border-b border-blue-100 px-6 py-4">
              <h2 className="text-lg font-semibold text-gray-900">サービス提供地域</h2>
            </div>
            <div className="px-6 py-5">
              <div className="flex flex-wrap gap-2">
                {office.serviceArea.map((area, index) => (
                  <span
                    key={index}
                    className="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800"
                  >
                    {area}
                  </span>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* 戻るボタン */}
        <div className="mt-8 flex justify-center">
          <button
            onClick={handleBack}
            className="px-6 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
          >
            戻る
          </button>
        </div>
      </div>
    </MainLayout>
  );
}

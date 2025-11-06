/**
 * 事業所一覧画面
 *
 * 介護保険事業所の一覧を表示し、検索フィルタリング機能を提供します。
 * 事業所名、サービス種別、地区での絞り込みが可能です。
 * ダミーデータを使用したプロトタイプ実装です。
 *
 * @page /offices
 */
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import MainLayout from '@/components/Layout/MainLayout';

/** 事業所の型定義 */
interface Office {
  /** 事業所ID */
  id: number;
  /** 事業所名 */
  name: string;
  /** サービス種別（訪問介護、通所介護、居宅介護支援など） */
  service: string;
  /** 事業所の所在地 */
  address: string;
  /** 事業所の電話番号 */
  phone: string;
}

/** ダミー事業所データ（プロトタイプ用） */
const dummyOffices: Office[] = [
  { id: 1, name: "介護太郎訪問介護事業所", service: "訪問介護", address: "新潟市中央区東大通1-1-1", phone: "025-123-4567" },
  { id: 2, name: "さくらデイサービス", service: "通所介護", address: "新潟市西区小針3-5-10", phone: "025-234-5678" },
  { id: 3, name: "健康ケアプランセンター", service: "居宅介護支援", address: "新潟市東区木戸2-8-15", phone: "025-345-6789" },
  { id: 4, name: "やまびこ訪問介護ステーション", service: "訪問介護", address: "新潟市北区新崎1-7-12", phone: "025-456-7890" },
  { id: 5, name: "すみれ通所介護センター", service: "通所介護", address: "新潟市南区白根1234", phone: "025-567-8901" },
];

/**
 * 事業所一覧ページコンポーネント
 *
 * 事業所の一覧表示と検索フィルタリング機能を提供します。
 * 検索条件: 事業所名（部分一致）、サービス種別、地区
 */
export default function OfficesListPage() {
  const router = useRouter();

  // 検索フィルターの状態管理
  const [nameFilter, setNameFilter] = useState('');
  const [serviceFilter, setServiceFilter] = useState('');
  const [districtFilter, setDistrictFilter] = useState('');

  /**
   * フィルター条件に基づいて事業所リストを絞り込み
   *
   * - 事業所名: 部分一致
   * - サービス種別: 完全一致
   * - 地区: 住所に含まれる地区名で判定
   */
  const filteredOffices = dummyOffices.filter((office) => {
    const matchesName = nameFilter === '' || office.name.includes(nameFilter);
    const matchesService = serviceFilter === '' || office.service === serviceFilter;
    const matchesDistrict = districtFilter === '' || office.address.includes(districtFilter);
    return matchesName && matchesService && matchesDistrict;
  });

  return (
    <MainLayout>
      <div className="px-4 py-6 sm:px-0">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-900">事業所管理</h1>
          <p className="mt-2 text-sm text-gray-600">
            介護事業所の情報を確認・管理できます
          </p>
        </div>

        {/* 検索フィルター */}
        <div className="bg-white shadow-sm rounded-lg border border-gray-200 p-6 mb-6">
          <h2 className="text-lg font-medium text-gray-900 mb-4">検索フィルター</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {/* 事業所名フィルター */}
            <div>
              <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-2">
                事業所名
              </label>
              <input
                type="text"
                id="name"
                value={nameFilter}
                onChange={(e) => setNameFilter(e.target.value)}
                placeholder="事業所名を入力"
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            {/* サービス種別フィルター */}
            <div>
              <label htmlFor="service" className="block text-sm font-medium text-gray-700 mb-2">
                サービス種別
              </label>
              <select
                id="service"
                value={serviceFilter}
                onChange={(e) => setServiceFilter(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">全て</option>
                <option value="訪問介護">訪問介護</option>
                <option value="通所介護">通所介護</option>
                <option value="居宅介護支援">居宅介護支援</option>
              </select>
            </div>

            {/* 地区フィルター */}
            <div>
              <label htmlFor="district" className="block text-sm font-medium text-gray-700 mb-2">
                地区
              </label>
              <select
                id="district"
                value={districtFilter}
                onChange={(e) => setDistrictFilter(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">全て</option>
                <option value="中央区">中央区</option>
                <option value="東区">東区</option>
                <option value="西区">西区</option>
                <option value="北区">北区</option>
                <option value="南区">南区</option>
                <option value="江南区">江南区</option>
                <option value="秋葉区">秋葉区</option>
                <option value="西蒲区">西蒲区</option>
              </select>
            </div>
          </div>

          {/* フィルタークリアボタン */}
          {(nameFilter || serviceFilter || districtFilter) && (
            <div className="mt-4">
              <button
                onClick={() => {
                  setNameFilter('');
                  setServiceFilter('');
                  setDistrictFilter('');
                }}
                className="text-sm text-blue-600 hover:text-blue-800"
              >
                フィルターをクリア
              </button>
            </div>
          )}
        </div>

        {/* 事業所テーブル */}
        <div className="bg-white shadow-sm rounded-lg border border-gray-200 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-lg font-medium text-gray-900">
              事業所一覧 ({filteredOffices.length}件)
            </h2>
          </div>

          {filteredOffices.length === 0 ? (
            <div className="text-center py-12">
              <p className="text-gray-500">該当する事業所がありません</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      事業所名
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      サービス種別
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      所在地
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      電話番号
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      操作
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {filteredOffices.map((office) => (
                    <tr key={office.id} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-medium text-gray-900">{office.name}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                          {office.service}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <div className="text-sm text-gray-900">{office.address}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-gray-900">{office.phone}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        <button
                          onClick={() => router.push(`/offices/${office.id}`)}
                          className="text-blue-600 hover:text-blue-800 font-medium"
                        >
                          詳細
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </MainLayout>
  );
}

/**
 * 申請一覧ページ
 */

'use client';

import { useState } from 'react';
import Link from 'next/link';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Select } from '@/components/ui/Select';
import { Table } from '@/components/ui/Table';
import { Badge } from '@/components/ui/Badge';

// ダミーデータ
const mockApplications = [
  {
    id: '1',
    applicationNumber: 'APP-20250105-12345',
    subjectName: '山田 太郎',
    applicationType: '新規',
    applicationDate: '2025-01-05',
    status: '申請中',
  },
  {
    id: '2',
    applicationNumber: 'APP-20250104-98765',
    subjectName: '佐藤 花子',
    applicationType: '更新',
    applicationDate: '2025-01-04',
    status: '調査中',
  },
  {
    id: '3',
    applicationNumber: 'APP-20250103-55555',
    subjectName: '鈴木 一郎',
    applicationType: '変更',
    applicationDate: '2025-01-03',
    status: '審査中',
  },
  {
    id: '4',
    applicationNumber: 'APP-20250102-11111',
    subjectName: '田中 美咲',
    applicationType: '新規',
    applicationDate: '2025-01-02',
    status: '認定済み',
  },
];

const getStatusBadgeVariant = (status: string) => {
  switch (status) {
    case '申請中':
      return 'info';
    case '調査中':
      return 'warning';
    case '審査中':
      return 'warning';
    case '認定済み':
      return 'success';
    case '却下':
      return 'error';
    default:
      return 'gray';
  }
};

export default function ApplicationsPage() {
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  const columns = [
    {
      key: 'applicationNumber',
      header: '申請番号',
      render: (item: typeof mockApplications[0]) => (
        <Link
          href={`/applications/${item.id}`}
          className="text-primary-600 hover:text-primary-800 font-medium"
        >
          {item.applicationNumber}
        </Link>
      ),
    },
    {
      key: 'subjectName',
      header: '対象者名',
    },
    {
      key: 'applicationType',
      header: '申請区分',
    },
    {
      key: 'applicationDate',
      header: '申請日',
    },
    {
      key: 'status',
      header: '状態',
      render: (item: typeof mockApplications[0]) => (
        <Badge variant={getStatusBadgeVariant(item.status)}>
          {item.status}
        </Badge>
      ),
    },
  ];

  const filteredData = mockApplications.filter((app) => {
    const matchesSearch =
      !searchTerm ||
      app.applicationNumber.toLowerCase().includes(searchTerm.toLowerCase()) ||
      app.subjectName.includes(searchTerm);
    const matchesStatus = !statusFilter || app.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  return (
    <div className="space-y-6">
      {/* ページヘッダー */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">要介護認定申請一覧</h1>
          <p className="mt-1 text-sm text-gray-500">
            申請の一覧を確認・管理できます
          </p>
        </div>
        <Link href="/applications/new">
          <Button>
            <svg
              className="h-5 w-5 mr-2"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M12 4v16m8-8H4"
              />
            </svg>
            新規申請
          </Button>
        </Link>
      </div>

      {/* フィルター */}
      <div className="bg-white p-4 rounded-lg shadow">
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <Input
            placeholder="申請番号、対象者名で検索..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
          <Select
            placeholder="状態で絞り込み"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            options={[
              { value: '', label: 'すべて' },
              { value: '申請中', label: '申請中' },
              { value: '調査中', label: '調査中' },
              { value: '審査中', label: '審査中' },
              { value: '認定済み', label: '認定済み' },
              { value: '却下', label: '却下' },
            ]}
          />
          <Button variant="secondary" onClick={() => {
            setSearchTerm('');
            setStatusFilter('');
          }}>
            フィルターをクリア
          </Button>
        </div>
      </div>

      {/* テーブル */}
      <div className="bg-white rounded-lg shadow">
        <Table
          data={filteredData}
          columns={columns}
          emptyMessage="条件に一致する申請がありません"
        />
      </div>

      {/* ページネーション（張りぼて） */}
      <div className="flex items-center justify-between bg-white px-4 py-3 rounded-lg shadow sm:px-6">
        <div className="flex flex-1 justify-between sm:hidden">
          <Button variant="secondary" size="sm">前へ</Button>
          <Button variant="secondary" size="sm">次へ</Button>
        </div>
        <div className="hidden sm:flex sm:flex-1 sm:items-center sm:justify-between">
          <div>
            <p className="text-sm text-gray-700">
              全 <span className="font-medium">{filteredData.length}</span> 件中{' '}
              <span className="font-medium">1</span> - <span className="font-medium">{filteredData.length}</span> 件を表示
            </p>
          </div>
          <div>
            <nav className="inline-flex -space-x-px rounded-md shadow-sm">
              <Button variant="secondary" size="sm" className="rounded-r-none">
                前へ
              </Button>
              <Button variant="secondary" size="sm" className="rounded-none">
                1
              </Button>
              <Button variant="secondary" size="sm" className="rounded-l-none">
                次へ
              </Button>
            </nav>
          </div>
        </div>
      </div>
    </div>
  );
}

/**
 * 対象者管理ページ
 */

'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Table } from '@/components/ui/Table';

const mockSubjects = [
  {
    id: '1',
    insuredNumber: '1234567890',
    name: '山田 太郎',
    dateOfBirth: '1950-04-15',
    gender: '男性',
    phoneNumber: '025-123-4567',
  },
  {
    id: '2',
    insuredNumber: '0987654321',
    name: '佐藤 花子',
    dateOfBirth: '1955-08-22',
    gender: '女性',
    phoneNumber: '025-987-6543',
  },
];

export default function SubjectsPage() {
  const [searchTerm, setSearchTerm] = useState('');

  const columns = [
    { key: 'insuredNumber', header: '被保険者番号' },
    { key: 'name', header: '氏名' },
    { key: 'dateOfBirth', header: '生年月日' },
    { key: 'gender', header: '性別' },
    { key: 'phoneNumber', header: '電話番号' },
  ];

  const filteredData = mockSubjects.filter(
    (subject) =>
      !searchTerm ||
      subject.insuredNumber.includes(searchTerm) ||
      subject.name.includes(searchTerm)
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">対象者管理</h1>
          <p className="mt-1 text-sm text-gray-500">対象者情報を管理できます</p>
        </div>
        <Button>新規登録</Button>
      </div>

      <div className="bg-white p-4 rounded-lg shadow">
        <Input
          placeholder="被保険者番号、氏名で検索..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
        />
      </div>

      <div className="bg-white rounded-lg shadow">
        <Table data={filteredData} columns={columns} />
      </div>
    </div>
  );
}

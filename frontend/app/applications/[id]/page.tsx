/**
 * 申請詳細ページ
 */

'use client';

import { use } from 'react';
import Link from 'next/link';
import { Button } from '@/components/ui/Button';
import { Badge } from '@/components/ui/Badge';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';

// ダミーデータ
const mockApplication = {
  id: '1',
  applicationNumber: 'APP-20250105-12345',
  subjectId: 'SUB-001',
  subjectName: '山田 太郎',
  subjectKana: 'ヤマダ タロウ',
  dateOfBirth: '1950-04-15',
  gender: '男性',
  insuredNumber: '1234567890',
  address: '新潟県新潟市中央区学校町通1-602-1',
  phoneNumber: '025-123-4567',
  applicationType: '新規',
  applicationDate: '2025-01-05',
  facilityName: '新潟介護サービスセンター',
  status: '申請中',
  certificationResult: null,
  validFrom: null,
  validTo: null,
  remarks: '初回の申請です。',
  createdAt: '2025-01-05T10:30:00',
  updatedAt: '2025-01-05T10:30:00',
};

export default function ApplicationDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);

  return (
    <div className="max-w-5xl mx-auto space-y-6">
      {/* ページヘッダー */}
      <div className="flex items-center justify-between">
        <div>
          <div className="flex items-center space-x-3">
            <h1 className="text-2xl font-bold text-gray-900">
              {mockApplication.applicationNumber}
            </h1>
            <Badge variant="info">{mockApplication.status}</Badge>
          </div>
          <p className="mt-1 text-sm text-gray-500">
            申請詳細情報を表示しています
          </p>
        </div>
        <div className="flex items-center space-x-3">
          <Link href={`/applications/${id}/edit`}>
            <Button variant="secondary">編集</Button>
          </Link>
          <Button variant="danger">削除</Button>
        </div>
      </div>

      {/* 対象者情報 */}
      <Card>
        <CardHeader>
          <CardTitle>対象者情報</CardTitle>
        </CardHeader>
        <CardContent>
          <dl className="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
            <div>
              <dt className="text-sm font-medium text-gray-500">氏名</dt>
              <dd className="mt-1 text-sm text-gray-900">{mockApplication.subjectName}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500">フリガナ</dt>
              <dd className="mt-1 text-sm text-gray-900">{mockApplication.subjectKana}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500">被保険者番号</dt>
              <dd className="mt-1 text-sm text-gray-900">{mockApplication.insuredNumber}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500">生年月日</dt>
              <dd className="mt-1 text-sm text-gray-900">{mockApplication.dateOfBirth}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500">性別</dt>
              <dd className="mt-1 text-sm text-gray-900">{mockApplication.gender}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500">電話番号</dt>
              <dd className="mt-1 text-sm text-gray-900">{mockApplication.phoneNumber}</dd>
            </div>
            <div className="sm:col-span-2">
              <dt className="text-sm font-medium text-gray-500">住所</dt>
              <dd className="mt-1 text-sm text-gray-900">{mockApplication.address}</dd>
            </div>
          </dl>
        </CardContent>
      </Card>

      {/* 申請情報 */}
      <Card>
        <CardHeader>
          <CardTitle>申請情報</CardTitle>
        </CardHeader>
        <CardContent>
          <dl className="grid grid-cols-1 gap-x-4 gap-y-6 sm:grid-cols-2">
            <div>
              <dt className="text-sm font-medium text-gray-500">申請番号</dt>
              <dd className="mt-1 text-sm text-gray-900">{mockApplication.applicationNumber}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500">申請区分</dt>
              <dd className="mt-1 text-sm text-gray-900">{mockApplication.applicationType}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500">申請日</dt>
              <dd className="mt-1 text-sm text-gray-900">{mockApplication.applicationDate}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500">申請事業所</dt>
              <dd className="mt-1 text-sm text-gray-900">{mockApplication.facilityName}</dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500">状態</dt>
              <dd className="mt-1 text-sm text-gray-900">
                <Badge variant="info">{mockApplication.status}</Badge>
              </dd>
            </div>
            <div>
              <dt className="text-sm font-medium text-gray-500">認定結果</dt>
              <dd className="mt-1 text-sm text-gray-900">
                {mockApplication.certificationResult || '-'}
              </dd>
            </div>
            <div className="sm:col-span-2">
              <dt className="text-sm font-medium text-gray-500">備考</dt>
              <dd className="mt-1 text-sm text-gray-900">{mockApplication.remarks || '-'}</dd>
            </div>
          </dl>
        </CardContent>
      </Card>

      {/* タイムライン */}
      <Card>
        <CardHeader>
          <CardTitle>履歴</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flow-root">
            <ul className="-mb-8">
              {[
                {
                  id: 1,
                  content: '申請が作成されました',
                  date: '2025-01-05 10:30',
                  user: '田中 太郎',
                },
                {
                  id: 2,
                  content: '申請内容が更新されました',
                  date: '2025-01-05 14:00',
                  user: '田中 太郎',
                },
              ].map((event, eventIdx, events) => (
                <li key={event.id}>
                  <div className="relative pb-8">
                    {eventIdx !== events.length - 1 && (
                      <span
                        className="absolute left-4 top-4 -ml-px h-full w-0.5 bg-gray-200"
                        aria-hidden="true"
                      />
                    )}
                    <div className="relative flex space-x-3">
                      <div>
                        <span className="h-8 w-8 rounded-full bg-primary-100 flex items-center justify-center ring-8 ring-white">
                          <svg
                            className="h-5 w-5 text-primary-600"
                            fill="currentColor"
                            viewBox="0 0 20 20"
                          >
                            <path
                              fillRule="evenodd"
                              d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z"
                              clipRule="evenodd"
                            />
                          </svg>
                        </span>
                      </div>
                      <div className="flex min-w-0 flex-1 justify-between space-x-4 pt-1.5">
                        <div>
                          <p className="text-sm text-gray-500">
                            {event.content} by{' '}
                            <span className="font-medium text-gray-900">{event.user}</span>
                          </p>
                        </div>
                        <div className="whitespace-nowrap text-right text-sm text-gray-500">
                          {event.date}
                        </div>
                      </div>
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          </div>
        </CardContent>
      </Card>

      {/* 戻るボタン */}
      <div className="flex justify-start">
        <Link href="/applications">
          <Button variant="secondary">
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
                d="M10 19l-7-7m0 0l7-7m-7 7h18"
              />
            </svg>
            一覧に戻る
          </Button>
        </Link>
      </div>
    </div>
  );
}

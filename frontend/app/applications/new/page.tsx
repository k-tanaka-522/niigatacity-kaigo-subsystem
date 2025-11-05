/**
 * 新規申請作成ページ
 */

'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/Button';
import { Input } from '@/components/ui/Input';
import { Select } from '@/components/ui/Select';
import { Textarea } from '@/components/ui/Textarea';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';

export default function NewApplicationPage() {
  const router = useRouter();
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);

    // ダミーの送信処理
    await new Promise((resolve) => setTimeout(resolve, 1000));

    setIsSubmitting(false);
    router.push('/applications');
  };

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* ページヘッダー */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">新規申請作成</h1>
        <p className="mt-1 text-sm text-gray-500">
          要介護認定申請を新規作成します
        </p>
      </div>

      <form onSubmit={handleSubmit}>
        {/* 対象者情報 */}
        <Card className="mb-6">
          <CardHeader>
            <CardTitle>対象者情報</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <Input
                label="被保険者番号"
                placeholder="1234567890"
                required
              />
              <Input
                label="氏名"
                placeholder="山田 太郎"
                required
              />
              <Input
                label="フリガナ"
                placeholder="ヤマダ タロウ"
                required
              />
              <Input
                type="date"
                label="生年月日"
                required
              />
              <Select
                label="性別"
                required
                options={[
                  { value: '男性', label: '男性' },
                  { value: '女性', label: '女性' },
                  { value: 'その他', label: 'その他' },
                ]}
                placeholder="選択してください"
              />
              <Input
                label="電話番号"
                placeholder="025-123-4567"
              />
              <div className="sm:col-span-2">
                <Input
                  label="住所"
                  placeholder="新潟県新潟市中央区..."
                />
              </div>
            </div>
          </CardContent>
        </Card>

        {/* 申請情報 */}
        <Card className="mb-6">
          <CardHeader>
            <CardTitle>申請情報</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 gap-6 sm:grid-cols-2">
              <Select
                label="申請区分"
                required
                options={[
                  { value: '新規', label: '新規' },
                  { value: '更新', label: '更新' },
                  { value: '変更', label: '変更' },
                ]}
                placeholder="選択してください"
              />
              <Input
                type="date"
                label="申請日"
                required
                defaultValue={new Date().toISOString().split('T')[0]}
              />
              <div className="sm:col-span-2">
                <Input
                  label="事業所名"
                  placeholder="〇〇介護サービスセンター"
                />
              </div>
              <div className="sm:col-span-2">
                <Textarea
                  label="備考"
                  placeholder="特記事項がある場合は入力してください..."
                  rows={4}
                />
              </div>
            </div>
          </CardContent>
        </Card>

        {/* フォームアクション */}
        <div className="flex items-center justify-end space-x-4">
          <Button
            type="button"
            variant="secondary"
            onClick={() => router.back()}
          >
            キャンセル
          </Button>
          <Button type="submit" isLoading={isSubmitting}>
            申請を作成
          </Button>
        </div>
      </form>
    </div>
  );
}

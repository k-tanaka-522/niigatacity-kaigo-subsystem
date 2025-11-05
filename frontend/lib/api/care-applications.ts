/**
 * 要介護認定申請API
 */

import { apiClient } from './client';

export interface CareApplication {
  id: string;
  applicationNumber: string;
  subjectId: string;
  subjectName: string;
  applicationType: string;
  applicationDate: string;
  status: string;
  certificationResult?: string;
  validFrom?: string;
  validTo?: string;
  remarks?: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateCareApplicationDto {
  subjectId: string;
  applicationType: string;
  applicationDate: string;
  facilityId?: string;
  remarks?: string;
}

export interface UpdateCareApplicationDto {
  status?: string;
  certificationResult?: string;
  validFrom?: string;
  validTo?: string;
  remarks?: string;
}

export const careApplicationsApi = {
  /**
   * 申請一覧取得
   */
  getAll: async (page: number = 1, pageSize: number = 20) => {
    return apiClient.get<CareApplication[]>(
      `/CareApplications?page=${page}&pageSize=${pageSize}`
    );
  },

  /**
   * 申請詳細取得
   */
  getById: async (id: string) => {
    return apiClient.get<CareApplication>(`/CareApplications/${id}`);
  },

  /**
   * 対象者別申請一覧取得
   */
  getBySubjectId: async (subjectId: string) => {
    return apiClient.get<CareApplication[]>(
      `/CareApplications/subject/${subjectId}`
    );
  },

  /**
   * 事業所別申請一覧取得
   */
  getByFacilityId: async (facilityId: string) => {
    return apiClient.get<CareApplication[]>(
      `/CareApplications/facility/${facilityId}`
    );
  },

  /**
   * 申請新規作成
   */
  create: async (data: CreateCareApplicationDto) => {
    return apiClient.post<CareApplication>('/CareApplications', data);
  },

  /**
   * 申請更新
   */
  update: async (id: string, data: UpdateCareApplicationDto) => {
    return apiClient.put<CareApplication>(`/CareApplications/${id}`, data);
  },

  /**
   * 申請削除
   */
  delete: async (id: string) => {
    return apiClient.delete(`/CareApplications/${id}`);
  },
};

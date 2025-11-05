/**
 * 要介護認定申請カスタムフック
 */

'use client';

import { useState, useEffect } from 'react';
import {
  careApplicationsApi,
  CareApplication,
  CreateCareApplicationDto,
  UpdateCareApplicationDto,
} from '@/lib/api/care-applications';
import { ApiError } from '@/lib/api/client';

export function useCareApplications(page: number = 1, pageSize: number = 20) {
  const [applications, setApplications] = useState<CareApplication[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<ApiError | null>(null);

  useEffect(() => {
    const fetchApplications = async () => {
      try {
        setLoading(true);
        const data = await careApplicationsApi.getAll(page, pageSize);
        setApplications(data);
        setError(null);
      } catch (err) {
        setError(err as ApiError);
      } finally {
        setLoading(false);
      }
    };

    fetchApplications();
  }, [page, pageSize]);

  return { applications, loading, error };
}

export function useCareApplication(id: string | null) {
  const [application, setApplication] = useState<CareApplication | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<ApiError | null>(null);

  useEffect(() => {
    if (!id) {
      setLoading(false);
      return;
    }

    const fetchApplication = async () => {
      try {
        setLoading(true);
        const data = await careApplicationsApi.getById(id);
        setApplication(data);
        setError(null);
      } catch (err) {
        setError(err as ApiError);
      } finally {
        setLoading(false);
      }
    };

    fetchApplication();
  }, [id]);

  return { application, loading, error };
}

export function useCareApplicationActions() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);

  const createApplication = async (data: CreateCareApplicationDto) => {
    try {
      setLoading(true);
      const result = await careApplicationsApi.create(data);
      setError(null);
      return result;
    } catch (err) {
      setError(err as ApiError);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  const updateApplication = async (
    id: string,
    data: UpdateCareApplicationDto
  ) => {
    try {
      setLoading(true);
      const result = await careApplicationsApi.update(id, data);
      setError(null);
      return result;
    } catch (err) {
      setError(err as ApiError);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  const deleteApplication = async (id: string) => {
    try {
      setLoading(true);
      await careApplicationsApi.delete(id);
      setError(null);
    } catch (err) {
      setError(err as ApiError);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  return {
    createApplication,
    updateApplication,
    deleteApplication,
    loading,
    error,
  };
}

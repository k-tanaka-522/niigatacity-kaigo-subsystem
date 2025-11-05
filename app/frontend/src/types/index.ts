export interface User {
  id: number;
  email: string;
  name: string;
  role: string;
  officeId?: number;
  officeName?: string;
}

export interface LoginResponse {
  token: string;
  user: User;
}

export interface Application {
  id: number;
  applicationNumber: string;
  officeId: number;
  officeName?: string;
  userId: number;
  userName?: string;
  applicationType: string;
  title: string;
  content?: string;
  status: string;
  submittedAt?: string;
  reviewedAt?: string;
  reviewedBy?: number;
  reviewerName?: string;
  reviewComment?: string;
  fileCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface ApplicationFormData {
  applicationType: string;
  title: string;
  content?: string;
}

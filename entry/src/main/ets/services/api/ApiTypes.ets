export interface ApiEnvelope<T> {
  code: string;
  message: string;
  data: T;
  requestId: string;
}

export interface RemoteUser {
  id: string;
  nickname: string;
  phone: string;
  email: string;
  role: string;
  isAdmin: boolean;
  department: string;
  campus: string;
}

export interface PasswordLoginData {
  accessToken: string;
  expiresAt: string;
  user: RemoteUser;
}

export interface PasswordLoginRequest {
  account: string;
  password: string;
}

export interface CreatePostRequest {
  kind: string;
  title: string;
  description: string;
  category: string;
  location: string;
  campus: string;
  contact: string;
  imageIds: string[];
}

export interface ClaimRequestBody {
  answer: string;
}

export interface ClueRequestBody {
  content: string;
}

export interface CommentRequestBody {
  content: string;
}

export interface EmptyRequestBody {
  request: string;
}

export interface EmptyResponse {
  status?: string;
}

export interface RemotePostSummary {
  id: string;
  ownerId: string;
  ownerNickname: string;
  kind: string;
  title: string;
  category: string;
  location: string;
  campus: string;
  status: string;
  description?: string;
  imageUrl?: string;
  likeCount?: number;
  isLiked?: boolean;
  favoriteCount?: number;
  isFavorite?: boolean;
  commentCount?: number;
  createdAt: string;
}

export interface RemotePostInteraction {
  postId: string;
  likeCount: number;
  isLiked: boolean;
  favoriteCount: number;
  isFavorite: boolean;
}

export interface InteractionRequestBody {
  enabled: boolean;
}

export interface RemoteImage {
  id: string;
  publicUrl: string;
  contentType: string;
  sizeBytes: number;
  status?: string;
}

export interface RemotePostDetail extends RemotePostSummary {
  description: string;
  contact: string;
  ownerDepartment: string;
  images: RemoteImage[];
}

export interface RemoteClaim {
  id: string;
  postId: string;
  applicantId: string;
  applicantNickname: string;
  answer: string;
  status: string;
  createdAt: string;
  completedAt?: string;
}

export interface RemoteClue {
  id: string;
  postId: string;
  authorId: string;
  authorNickname: string;
  content: string;
  createdAt: string;
}

export interface RemoteComment {
  id: string;
  postId: string;
  userId: string;
  userName: string;
  content: string;
  createdAt: string;
}

export interface PostPageData {
  items: RemotePostSummary[];
  page: number;
  pageSize: number;
  total: number;
}

export interface RemoteNotification {
  id: string;
  type: string;
  title: string;
  content: string;
  postId: string;
  createdAt: string;
  read: boolean;
}

export interface NotificationPageData {
  items: RemoteNotification[];
  total: number;
}

export interface NotificationReadRequest {
  notificationIds: string[];
}

export interface NotificationReadResponse {
  count: number;
}

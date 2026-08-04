export enum PostKind {
  LOST_NOTICE = 'LOST_NOTICE',
  SEARCH_NOTICE = 'SEARCH_NOTICE'
}

export enum PostStatus {
  ACTIVE = 'ACTIVE',
  CLAIMING = 'CLAIMING',
  RESOLVED = 'RESOLVED',
  CLOSED = 'CLOSED'
}

export enum ClaimStatus {
  PENDING = 'PENDING',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
  COMPLETED = 'COMPLETED'
}

export interface PostDraft {
  kind: PostKind;
  title: string;
  description: string;
  category: string;
  location: string;
  occurredAt: string;
  imageKey: string;
}

export interface Post {
  id: string;
  ownerId: string;
  ownerName: string;
  kind: PostKind;
  status: PostStatus;
  title: string;
  description: string;
  category: string;
  location: string;
  occurredAt: string;
  imageKey: string;
  likeCount: number;
  commentCount: number;
  isLiked: boolean;
  isFavorite: boolean;
  createdAt: number;
}

export interface PostComment {
  id: string;
  postId: string;
  userId: string;
  userName: string;
  content: string;
  createdAt: number;
}

export interface ClaimRequest {
  id: string;
  postId: string;
  claimantId: string;
  answer: string;
  status: ClaimStatus;
  createdAt: number;
}

export interface ClueRecord {
  id: string;
  postId: string;
  providerId: string;
  content: string;
  helpful: boolean;
  createdAt: number;
}

export interface AppNotification {
  id: string;
  type: string;
  title: string;
  content: string;
  postId: string;
  createdAt: number;
  read: boolean;
}

export interface PostFilter {
  keyword: string;
  kind?: PostKind;
  category: string;
  status?: PostStatus;
}

export interface ContentSnapshot {
  posts: Post[];
  comments: PostComment[];
  claims: ClaimRequest[];
  clues: ClueRecord[];
  notifications: AppNotification[];
  favoritePostIds: string[];
}

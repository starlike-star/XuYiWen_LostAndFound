import { http } from '@kit.NetworkKit';
import { AppNotification, ClaimRequest, ClaimStatus, ClueRecord, Post, PostComment, PostDraft, PostKind, PostStatus } from '../../models/AppModels';
import { ApiClient } from './ApiClient';
import { ApiEnvelope, ClaimRequestBody, ClueRequestBody, CommentRequestBody, CreatePostRequest, EmptyRequestBody, EmptyResponse,
  InteractionRequestBody,
  NotificationPageData, NotificationReadRequest, NotificationReadResponse, PostPageData, RemoteClaim, RemoteClue, RemoteComment, RemoteNotification, RemotePostDetail,
  RemotePostInteraction, RemotePostSummary } from './ApiTypes';

const PATCH_METHOD: http.RequestMethod = 'PATCH' as http.RequestMethod;
const PUT_METHOD: http.RequestMethod = 'PUT' as http.RequestMethod;

function toPost(item: RemotePostSummary): Post {
  return {
    id: item.id,
    ownerId: item.ownerId,
    ownerName: item.ownerNickname,
    kind: item.kind === PostKind.SEARCH_NOTICE ? PostKind.SEARCH_NOTICE : PostKind.LOST_NOTICE,
    status: item.status === PostStatus.DELETED ? PostStatus.DELETED :
      (item.status === PostStatus.RESOLVED ? PostStatus.RESOLVED : PostStatus.ACTIVE),
    title: item.title,
    description: item.description ?? '',
    imageKey: item.imageUrl ?? '',
    category: item.category,
    location: item.location,
    occurredAt: '',
    likeCount: item.likeCount ?? 0,
    commentCount: item.commentCount ?? 0,
    isLiked: item.isLiked ?? false,
    isFavorite: item.isFavorite ?? false,
    createdAt: Date.parse(item.createdAt)
  };
}

function toClaim(item: RemoteClaim): ClaimRequest {
  return {
    id: item.id,
    postId: item.postId,
    claimantId: item.applicantId,
    answer: item.answer,
    status: item.status === 'COMPLETED' ? ClaimStatus.COMPLETED : ClaimStatus.PENDING,
    createdAt: Date.parse(item.createdAt)
  };
}

function toClue(item: RemoteClue): ClueRecord {
  return {
    id: item.id,
    postId: item.postId,
    providerId: item.authorId,
    content: item.content,
    helpful: false,
    createdAt: Date.parse(item.createdAt)
  };
}

function toComment(item: RemoteComment): PostComment {
  return {
    id: item.id,
    postId: item.postId,
    userId: item.userId,
    userName: item.userName,
    content: item.content,
    createdAt: Date.parse(item.createdAt)
  };
}

function toNotification(item: RemoteNotification): AppNotification {
  const notification: AppNotification = {
    id: item.id,
    type: item.type,
    title: item.title,
    content: item.content,
    postId: item.postId,
    createdAt: Date.parse(item.createdAt),
    read: item.read
  };
  return notification;
}

export class ContentApiRepository {
  private client: ApiClient;

  constructor(client: ApiClient = new ApiClient()) {
    this.client = client;
  }

  async listPosts(token: string): Promise<Post[]> {
    const response: ApiEnvelope<PostPageData> = await this.client.request<PostPageData>(
      http.RequestMethod.GET, '/api/v1/posts?page=1&pageSize=50', undefined, token);
    return response.data.items.map((item: RemotePostSummary) => toPost(item));
  }

  async listAdminPosts(token: string): Promise<Post[]> {
    const response: ApiEnvelope<PostPageData> = await this.client.request<PostPageData>(
      http.RequestMethod.GET, '/api/v1/admin/posts?page=1&pageSize=50', undefined, token);
    return response.data.items.map((item: RemotePostSummary) => toPost(item));
  }

  async setPostDeleted(token: string, postId: string): Promise<Post> {
    const response: ApiEnvelope<RemotePostDetail> = await this.client.request<RemotePostDetail>(
      http.RequestMethod.DELETE, `/api/v1/admin/posts/${postId}`, undefined, token);
    return toPost(response.data);
  }

  async restorePost(token: string, postId: string): Promise<Post> {
    const response: ApiEnvelope<RemotePostDetail> = await this.client.request<RemotePostDetail>(
      http.RequestMethod.PUT, `/api/v1/admin/posts/${postId}/restore`, undefined, token);
    return toPost(response.data);
  }

  async listPublicPosts(): Promise<Post[]> {
    const response: ApiEnvelope<PostPageData> = await this.client.request<PostPageData>(
      http.RequestMethod.GET, '/api/v1/posts/public?page=1&pageSize=50');
    return response.data.items.map((item: RemotePostSummary) => toPost(item));
  }

  async listNotifications(token: string): Promise<AppNotification[]> {
    const response: ApiEnvelope<NotificationPageData> = await this.client.request<NotificationPageData>(
      http.RequestMethod.GET, '/api/v1/notifications', undefined, token);
    return response.data.items.map((item: RemoteNotification) => toNotification(item));
  }

  async markNotificationsRead(token: string, notificationIds: string[]): Promise<void> {
    const body: NotificationReadRequest = { notificationIds: notificationIds };
    await this.client.request<NotificationReadResponse>(
      http.RequestMethod.PUT, '/api/v1/notifications/read', body, token);
  }

  async listComments(token: string, postId: string): Promise<PostComment[]> {
    const response: ApiEnvelope<RemoteComment[]> = await this.client.request<RemoteComment[]>(
      http.RequestMethod.GET, `/api/v1/posts/${postId}/comments`, undefined, token);
    return response.data.map((item: RemoteComment) => toComment(item));
  }

  async createComment(token: string, postId: string, content: string): Promise<PostComment> {
    const body: CommentRequestBody = { content: content.trim() };
    const response: ApiEnvelope<RemoteComment> = await this.client.request<RemoteComment>(
      http.RequestMethod.POST, `/api/v1/posts/${postId}/comments`, body, token);
    return toComment(response.data);
  }

  async getPost(token: string, postId: string): Promise<Post> {
    const response: ApiEnvelope<RemotePostDetail> = await this.client.request<RemotePostDetail>(
      http.RequestMethod.GET, `/api/v1/posts/${postId}`, undefined, token);
    const post: Post = toPost(response.data);
    post.description = response.data.description;
    post.location = response.data.location;
    post.imageKey = response.data.images.length > 0 ? response.data.images[0].publicUrl : '';
    return post;
  }

  async createPost(token: string, draft: PostDraft, campus: string, contact: string,
    imageIds: string[] = []): Promise<Post> {
    const body: CreatePostRequest = {
        kind: draft.kind,
        title: draft.title,
        description: draft.description,
        category: draft.category,
        location: draft.location,
        campus: campus,
        contact: contact,
        imageIds: imageIds
    };
    const response: ApiEnvelope<RemotePostDetail> = await this.client.request<RemotePostDetail>(
      http.RequestMethod.POST, '/api/v1/posts', body, token);
    return this.getPost(token, response.data.id);
  }

  async setLike(token: string, postId: string, enabled: boolean): Promise<RemotePostInteraction> {
    const body: InteractionRequestBody = { enabled: enabled };
    const response: ApiEnvelope<RemotePostInteraction> = await this.client.request<RemotePostInteraction>(
      PUT_METHOD, `/api/v1/posts/${postId}/like`, body, token);
    return response.data;
  }

  async setFavorite(token: string, postId: string, enabled: boolean): Promise<RemotePostInteraction> {
    const body: InteractionRequestBody = { enabled: enabled };
    const response: ApiEnvelope<RemotePostInteraction> = await this.client.request<RemotePostInteraction>(
      PUT_METHOD, `/api/v1/posts/${postId}/favorite`, body, token);
    return response.data;
  }

  async submitClaim(token: string, postId: string, answer: string): Promise<ClaimRequest> {
    const body: ClaimRequestBody = { answer: answer };
    const response: ApiEnvelope<RemoteClaim> = await this.client.request<RemoteClaim>(
      http.RequestMethod.POST, `/api/v1/posts/${postId}/claims`, body, token);
    return toClaim(response.data);
  }

  async submitClue(token: string, postId: string, content: string): Promise<ClueRecord> {
    const body: ClueRequestBody = { content: content };
    const response: ApiEnvelope<RemoteClue> = await this.client.request<RemoteClue>(
      http.RequestMethod.POST, `/api/v1/posts/${postId}/clues`, body, token);
    return toClue(response.data);
  }

  async listClaims(token: string, postId: string): Promise<ClaimRequest[]> {
    const response: ApiEnvelope<RemoteClaim[]> = await this.client.request<RemoteClaim[]>(
      http.RequestMethod.GET, `/api/v1/posts/${postId}/claims`, undefined, token);
    return response.data.map((item: RemoteClaim) => toClaim(item));
  }

  async confirmReturn(token: string, claimId: string): Promise<void> {
    const body: EmptyRequestBody = { request: 'confirm-return' };
    await this.client.request<EmptyResponse>(PATCH_METHOD, `/api/v1/claims/${claimId}/return`, body, token);
  }
}

import {
  AppNotification,
  ClaimRequest,
  ClaimStatus,
  ClueRecord,
  ContentSnapshot,
  Post,
  PostComment,
  PostDraft,
  PostFilter,
  PostKind,
  PostStatus
} from '../models/AppModels';

@Observed
export class AppStore {
  currentUserId: string;
  posts: Post[];
  comments: PostComment[] = [];
  claims: ClaimRequest[] = [];
  clues: ClueRecord[] = [];
  notifications: AppNotification[] = [];
  favoritePostIds: string[] = [];

  constructor(currentUserId: string, posts: Post[]) {
    this.currentUserId = currentUserId;
    this.posts = posts;
    this.favoritePostIds = posts.filter((post: Post) => post.isFavorite).map((post: Post) => post.id);
  }

  static createDemo(currentUserId: string, currentUserName: string = '小林同学'): AppStore {
    const now: number = Date.now();
    const posts: Post[] = [
      AppStore.demoPost('post-1', 'teacher-1', '王老师', PostKind.LOST_NOTICE, '黑色手机等待认领',
        '在第一教学楼 302 教室后排发现，黑色手机壳，已交至学院办公室。', '电子数码', '第一教学楼 302', '今天 10:20', 'phone', now),
      AppStore.demoPost('post-2', 'student-2', '陈同学', PostKind.SEARCH_NOTICE, '寻找蓝色校园卡套',
        '卡套内有校园卡和一张图书馆借阅卡，可能遗失在食堂附近。', '证件卡类', '第二食堂', '昨天 18:40', 'card', now - 1000),
      AppStore.demoPost('post-3', currentUserId, currentUserName, PostKind.LOST_NOTICE, '图书馆拾到钥匙串',
        '银色钥匙三把，带一个绿色小恐龙挂件，请描述其中一把钥匙的特征。', '钥匙钱包', '图书馆二楼', '昨天 16:10', 'keys', now - 2000),
      AppStore.demoPost('post-4', 'staff-1', '保卫处', PostKind.LOST_NOTICE, '运动场拾到白色耳机',
        '充电盒表面有轻微划痕，目前暂存在主校区保卫处。', '电子数码', '东区运动场', '周六 20:30', 'earbuds', now - 3000),
      AppStore.demoPost('post-5', 'student-3', '周同学', PostKind.SEARCH_NOTICE, '寻找高等数学笔记本',
        '牛皮纸封面，第一页写有班级信息，内容对考试很重要。', '书本文具', '逸夫楼', '周五 14:00', 'book', now - 4000),
      AppStore.demoPost('post-6', 'teacher-2', '刘老师', PostKind.SEARCH_NOTICE, '寻找深灰色折叠伞',
        '伞柄处贴有蓝色姓名贴，可能落在校车或行政楼大厅。', '衣物配饰', '行政楼', '周四 17:20', 'umbrella', now - 5000),
      AppStore.demoPost('post-7', 'student-4', '许同学', PostKind.LOST_NOTICE, '食堂发现保温杯',
        '浅绿色保温杯，杯底有卡通贴纸，已放在食堂服务台。', '生活用品', '第一食堂', '周三 12:30', 'cup', now - 6000),
      AppStore.demoPost('post-8', 'student-5', '赵同学', PostKind.SEARCH_NOTICE, '寻找羽毛球拍',
        '黑红配色，拍套侧面写有姓名缩写，训练后遗失。', '运动器材', '体育馆', '周二 21:00', 'racket', now - 7000)
    ];
    const store: AppStore = new AppStore(currentUserId, posts);
    store.notifications = [
      { id: 'notice-1', type: 'MATCH', title: '发现相似物品', content: '有一条新发布的信息可能与你关注的物品相关。', postId: 'post-2', createdAt: now, read: false },
      { id: 'notice-2', type: 'CLAIM', title: '收到认领申请', content: '陈同学申请认领你发布的钥匙串。', postId: 'post-3', createdAt: now - 5000, read: false },
      { id: 'notice-3', type: 'INTERACTION', title: '新的评论', content: '王老师回复了你的留言。', postId: 'post-1', createdAt: now - 10000, read: true }
    ];
    store.claims = [{ id: 'claim-seed', postId: 'post-3', claimantId: 'student-2', answer: '绿色挂件背面有白色划痕', status: ClaimStatus.PENDING, createdAt: now - 6000 }];
    return store;
  }

  static fromSnapshot(currentUserId: string, snapshot: ContentSnapshot): AppStore {
    const copy: ContentSnapshot = JSON.parse(JSON.stringify(snapshot)) as ContentSnapshot;
    const store: AppStore = new AppStore(currentUserId, copy.posts);
    store.comments = copy.comments;
    store.claims = copy.claims;
    store.clues = copy.clues;
    store.notifications = copy.notifications;
    store.favoritePostIds = copy.favoritePostIds;
    return store;
  }

  toSnapshot(): ContentSnapshot {
    const snapshot: ContentSnapshot = {
      posts: this.posts,
      comments: this.comments,
      claims: this.claims,
      clues: this.clues,
      notifications: this.notifications,
      favoritePostIds: this.favoritePostIds
    };
    return JSON.parse(JSON.stringify(snapshot)) as ContentSnapshot;
  }

  private static demoPost(id: string, ownerId: string, ownerName: string, kind: PostKind, title: string,
    description: string, category: string, location: string, occurredAt: string, imageKey: string,
    createdAt: number): Post {
    return {
      id: id,
      ownerId: ownerId,
      ownerName: ownerName,
      kind: kind,
      status: PostStatus.ACTIVE,
      title: title,
      description: description,
      category: category,
      location: location,
      occurredAt: occurredAt,
      imageKey: imageKey,
      likeCount: 3,
      commentCount: 1,
      isLiked: false,
      isFavorite: false,
      createdAt: createdAt
    };
  }

  query(filter: PostFilter): Post[] {
    const keyword: string = filter.keyword.trim().toLowerCase();
    return this.posts.filter((post: Post) => {
      const keywordMatch: boolean = keyword.length === 0 || post.title.toLowerCase().includes(keyword) ||
        post.description.toLowerCase().includes(keyword) || post.location.toLowerCase().includes(keyword);
      const kindMatch: boolean = filter.kind === undefined || post.kind === filter.kind;
      const categoryMatch: boolean = filter.category.length === 0 || post.category === filter.category;
      const statusMatch: boolean = post.status !== PostStatus.DELETED &&
        (filter.status === undefined || post.status === filter.status);
      return keywordMatch && kindMatch && categoryMatch && statusMatch;
    });
  }

  setAdminPostStatus(postId: string, status: PostStatus): boolean {
    const post: Post | undefined = this.findPost(postId);
    if (post === undefined) return false;
    post.status = status;
    this.posts = this.posts.slice();
    return true;
  }

  publish(draft: PostDraft, ownerName: string): string {
    const id: string = `post-${Date.now()}-${this.posts.length}`;
    const post: Post = {
      id: id,
      ownerId: this.currentUserId,
      ownerName: ownerName,
      kind: draft.kind,
      status: PostStatus.ACTIVE,
      title: draft.title.trim(),
      description: draft.description.trim(),
      category: draft.category,
      location: draft.location.trim(),
      occurredAt: draft.occurredAt,
      imageKey: draft.imageKey,
      likeCount: 0,
      commentCount: 0,
      isLiked: false,
      isFavorite: false,
      createdAt: Date.now()
    };
    this.posts.unshift(post);
    this.posts = this.posts.slice();
    return id;
  }

  findPost(postId: string): Post | undefined {
    return this.posts.find((post: Post) => post.id === postId);
  }

  toggleLike(postId: string): void {
    const post: Post | undefined = this.findPost(postId);
    if (post === undefined) {
      return;
    }
    post.isLiked = !post.isLiked;
    post.likeCount = Math.max(0, post.likeCount + (post.isLiked ? 1 : -1));
    this.posts = this.posts.slice();
  }

  toggleFavorite(postId: string): void {
    const post: Post | undefined = this.findPost(postId);
    if (post === undefined) {
      return;
    }
    post.isFavorite = !post.isFavorite;
    if (post.isFavorite) {
      if (!this.favoritePostIds.includes(postId)) {
        this.favoritePostIds.push(postId);
      }
    } else {
      this.favoritePostIds = this.favoritePostIds.filter((id: string) => id !== postId);
    }
    this.posts = this.posts.slice();
    this.favoritePostIds = this.favoritePostIds.slice();
  }

  updatePostInteractions(postId: string, likeCount: number, isLiked: boolean, isFavorite: boolean): void {
    const post: Post | undefined = this.findPost(postId);
    if (post === undefined) return;
    post.likeCount = likeCount;
    post.isLiked = isLiked;
    post.isFavorite = isFavorite;
    if (isFavorite && !this.favoritePostIds.includes(postId)) this.favoritePostIds.push(postId);
    if (!isFavorite) this.favoritePostIds = this.favoritePostIds.filter((id: string) => id !== postId);
    this.posts = this.posts.slice();
    this.favoritePostIds = this.favoritePostIds.slice();
  }

  updatePostCommentCount(postId: string, commentCount: number): void {
    const post: Post | undefined = this.findPost(postId);
    if (post === undefined) return;
    post.commentCount = commentCount;
    this.posts = this.posts.slice();
  }

  markNotificationRead(notificationId: string): boolean {
    const notice: AppNotification | undefined = this.notifications.find((item: AppNotification) =>
      item.id === notificationId);
    if (notice === undefined || notice.read) {
      return false;
    }
    notice.read = true;
    this.notifications = this.notifications.slice();
    return true;
  }

  unreadNotificationCount(): number {
    return this.notifications.filter((item: AppNotification) => !item.read).length;
  }

  markAllNotificationsRead(): boolean {
    let changed = false;
    this.notifications.forEach((item: AppNotification) => {
      if (!item.read) {
        item.read = true;
        changed = true;
      }
    });
    if (changed) this.notifications = this.notifications.slice();
    return changed;
  }

  addComment(postId: string, userName: string, content: string): string {
    const value: string = content.trim();
    const post: Post | undefined = this.findPost(postId);
    if (post === undefined || value.length === 0 || value.length > 200) {
      return '评论须为1~200个字符';
    }
    this.comments.push({ id: `comment-${Date.now()}`, postId: postId, userId: this.currentUserId,
      userName: userName, content: value, createdAt: Date.now() });
    post.commentCount += 1;
    this.comments = this.comments.slice();
    this.posts = this.posts.slice();
    return '';
  }

  submitClaim(postId: string, answer: string): string {
    const post: Post | undefined = this.findPost(postId);
    if (post === undefined || post.kind !== PostKind.LOST_NOTICE || post.status !== PostStatus.ACTIVE ||
      post.ownerId === this.currentUserId) {
      return '';
    }
    const existing: ClaimRequest | undefined = this.claims.find((item: ClaimRequest) =>
      item.postId === postId && item.claimantId === this.currentUserId && item.status === ClaimStatus.PENDING);
    if (existing !== undefined) {
      return existing.id;
    }
    const claim: ClaimRequest = { id: `claim-${Date.now()}-${this.claims.length}`, postId: postId,
      claimantId: this.currentUserId, answer: answer.trim(), status: ClaimStatus.PENDING, createdAt: Date.now() };
    this.claims.push(claim);
    this.notifications.unshift({ id: `notice-${Date.now()}`, type: 'CLAIM', title: '认领申请已提交',
      content: '发布者审核后会通过消息通知你。', postId: postId, createdAt: Date.now(), read: false });
    this.claims = this.claims.slice();
    this.notifications = this.notifications.slice();
    return claim.id;
  }

  reviewClaim(operatorId: string, claimId: string, approved: boolean): string {
    const claim: ClaimRequest | undefined = this.claims.find((item: ClaimRequest) => item.id === claimId);
    if (claim === undefined) {
      return '认领申请不存在';
    }
    if (claim.status !== ClaimStatus.PENDING) {
      return '当前状态无法操作';
    }
    const post: Post | undefined = this.findPost(claim.postId);
    if (post === undefined) {
      return '信息不存在';
    }
    if (post.ownerId !== operatorId) {
      return '无权审核该认领申请';
    }
    claim.status = approved ? ClaimStatus.APPROVED : ClaimStatus.REJECTED;
    if (approved) {
      post.status = PostStatus.CLAIMING;
    }
    this.claims = this.claims.slice();
    this.posts = this.posts.slice();
    return '';
  }

  confirmReturn(operatorId: string, claimId: string): string {
    const claim: ClaimRequest | undefined = this.claims.find((item: ClaimRequest) => item.id === claimId);
    if (claim === undefined) {
      return '认领申请不存在';
    }
    if (claim.status !== ClaimStatus.APPROVED) {
      return '当前状态无法操作';
    }
    const post: Post | undefined = this.findPost(claim.postId);
    if (post === undefined) {
      return '信息不存在';
    }
    if (post.ownerId !== operatorId) {
      return '无权确认归还';
    }
    claim.status = ClaimStatus.COMPLETED;
    post.status = PostStatus.RESOLVED;
    this.notifications.unshift({ id: `notice-${Date.now()}`, type: 'SYSTEM', title: '归还已完成',
      content: '感谢你让物品回到主人身边。', postId: claim.postId, createdAt: Date.now(), read: false });
    this.claims = this.claims.slice();
    this.posts = this.posts.slice();
    this.notifications = this.notifications.slice();
    return '';
  }

  submitClue(postId: string, content: string): string {
    const post: Post | undefined = this.findPost(postId);
    if (post === undefined || post.kind !== PostKind.SEARCH_NOTICE || post.status !== PostStatus.ACTIVE ||
      post.ownerId === this.currentUserId || content.trim().length === 0) {
      return '';
    }
    const clue: ClueRecord = { id: `clue-${Date.now()}-${this.clues.length}`, postId: postId,
      providerId: this.currentUserId, content: content.trim(), helpful: false, createdAt: Date.now() };
    this.clues.push(clue);
    this.notifications.unshift({ id: `notice-${Date.now()}`, type: 'CLUE', title: '线索已提交',
      content: '失主会通过站内消息联系你。', postId: postId, createdAt: Date.now(), read: false });
    this.clues = this.clues.slice();
    this.notifications = this.notifications.slice();
    return clue.id;
  }

  myPosts(): Post[] {
    return this.posts.filter((post: Post) => post.ownerId === this.currentUserId);
  }

  myClaims(): ClaimRequest[] {
    return this.claims.filter((claim: ClaimRequest) => claim.claimantId === this.currentUserId);
  }

  favoritePosts(): Post[] {
    return this.posts.filter((post: Post) => post.status !== PostStatus.DELETED && this.favoritePostIds.includes(post.id));
  }

  hasOpenPosts(): boolean {
    return this.myPosts().some((post: Post) => post.status === PostStatus.ACTIVE || post.status === PostStatus.CLAIMING);
  }
}

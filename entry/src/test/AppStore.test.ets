import { describe, it, expect } from '@ohos/hypium';
import { AppStore } from '../main/ets/stores/AppStore';
import { PostDraft, PostKind, PostStatus } from '../main/ets/models/AppModels';

export default function appStoreTest() {
  describe('appStore', () => {
    it('publishesPostToTopAndMyPosts', 0, () => {
      const store = AppStore.createDemo('student-1');
      const originalMyPosts: number = store.myPosts().length;
      const draft: PostDraft = {
        kind: PostKind.SEARCH_NOTICE,
        title: '寻找蓝色保温杯',
        description: '周一下午在图书馆三楼遗失，杯盖有姓名贴。',
        category: '生活用品',
        location: '图书馆三楼',
        occurredAt: '今天 15:20',
        imageKey: 'cup'
      };
      const postId: string = store.publish(draft, '小林同学');
      expect(store.posts[0].id).assertEqual(postId);
      expect(store.myPosts().length).assertEqual(originalMyPosts + 1);
    });

    it('togglesLikeAndFavoriteWithoutDuplicateCounts', 0, () => {
      const store = AppStore.createDemo('student-1');
      const postId: string = store.posts[0].id;
      const originalLikes: number = store.posts[0].likeCount;
      store.toggleLike(postId);
      expect(store.posts[0].likeCount).assertEqual(originalLikes + 1);
      store.toggleLike(postId);
      expect(store.posts[0].likeCount).assertEqual(originalLikes);
      store.toggleFavorite(postId);
      store.toggleFavorite(postId);
      expect(store.favoritePostIds.length).assertEqual(0);
    });

    it('movesClaimThroughApprovalAndReturn', 0, () => {
      const store = AppStore.createDemo('student-1');
      const targetId: string = store.posts[0].id;
      const claimId: string = store.submitClaim(targetId, '手机壳内侧有一张校园卡贴纸');
      expect(store.myClaims().length).assertEqual(1);
      expect(store.reviewClaim('teacher-1', claimId, true)).assertEqual('');
      expect(store.posts[0].status).assertEqual(PostStatus.CLAIMING);
      expect(store.confirmReturn('teacher-1', claimId)).assertEqual('');
      expect(store.posts[0].status).assertEqual(PostStatus.RESOLVED);
    });

    it('roundTripsContentSnapshotWithoutSharedReferences', 0, () => {
      const original = AppStore.createDemo('student-1', '小林同学');
      original.toggleFavorite('post-1');
      original.addComment('post-1', '小林同学', '我可以提供手机壳特征');
      const snapshot = original.toSnapshot();
      const restored = AppStore.fromSnapshot('student-1', snapshot);
      restored.posts[0].title = '修改后的标题';
      expect(snapshot.posts[0].title).assertEqual('黑色手机等待认领');
      expect(restored.favoritePostIds.length).assertEqual(1);
      expect(restored.comments.length).assertEqual(1);
    });

    it('marksNotificationReadOnlyOnce', 0, () => {
      const store = AppStore.createDemo('student-1', '小林同学');
      expect(store.markNotificationRead('notice-1')).assertTrue();
      expect(store.notifications[0].read).assertTrue();
      expect(store.markNotificationRead('notice-1')).assertFalse();
    });

    it('rejectsClaimReviewByNonOwner', 0, () => {
      const store = AppStore.createDemo('student-1', '小林同学');
      const claimId: string = store.submitClaim('post-1', '手机壳内侧有校园卡贴纸');
      expect(store.reviewClaim('student-2', claimId, true)).assertEqual('无权审核该认领申请');
      expect(store.posts[0].status).assertEqual(PostStatus.ACTIVE);
    });

    it('usesCurrentAccountNameForOwnedDemoPost', 0, () => {
      const store = AppStore.createDemo('teacher-1', '王老师');
      expect(store.findPost('post-3')?.ownerName).assertEqual('王老师');
    });

    it('replacesPostsCollectionAfterNestedPostMutation', 0, () => {
      const store = AppStore.createDemo('student-1');
      const previousPosts = store.posts;
      store.toggleLike('post-1');
      expect(store.posts === previousPosts).assertFalse();
    });

    it('replacesNotificationsCollectionAfterReadMutation', 0, () => {
      const store = AppStore.createDemo('student-1');
      const previousNotifications = store.notifications;
      store.markNotificationRead('notice-1');
      expect(store.notifications === previousNotifications).assertFalse();
    });

    it('replacesClaimCollectionsAfterApprovalMutation', 0, () => {
      const store = AppStore.createDemo('student-1');
      const previousPosts = store.posts;
      const previousClaims = store.claims;
      expect(store.reviewClaim('student-1', 'claim-seed', true)).assertEqual('');
      expect(store.posts === previousPosts).assertFalse();
      expect(store.claims === previousClaims).assertFalse();
    });
  });
}

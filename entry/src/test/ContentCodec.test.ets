import { describe, it, expect } from '@ohos/hypium';
import { joinContentChunks, splitContentText } from '../main/ets/services/ContentCodec';

export default function contentCodecTest() {
  describe('contentCodec', () => {
    it('splitsLargeSnapshotsBelowPreferencesValueLimit', 0, () => {
      const text: string = '校园失物招领'.repeat(2300);
      const chunks: string[] = splitContentText(text);
      expect(chunks.length > 1).assertTrue();
      expect(chunks.every((chunk: string) => chunk.length <= 8000)).assertTrue();
      expect(joinContentChunks(chunks)).assertEqual(text);
    });
  });
}

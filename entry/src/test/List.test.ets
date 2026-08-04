import localUnitTest from './LocalUnit.test';
import accountRulesTest from './AccountRules.test';
import appStoreTest from './AppStore.test';
import contentCodecTest from './ContentCodec.test';

export default function testsuite() {
  localUnitTest();
  accountRulesTest();
  appStoreTest();
  contentCodecTest();
}

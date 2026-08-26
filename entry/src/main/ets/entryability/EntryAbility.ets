import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, font } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // ★ 注册霞鹜文楷字体（全局可用，fontFamily: 'LXGWWenKai'）
    try {
      font.registerFont({
        familyName: 'LXGWWenKai',
        familySrc: $rawfile('fonts/LXGWWenKai.ttf')
      });
      hilog.info(DOMAIN, 'font', '%{public}s', 'LXGW WenKai font registered');
    } catch (e) {
      hilog.warn(DOMAIN, 'font', 'LXGW WenKai register failed: %{public}s', JSON.stringify(e));
    }

    // ★ 设置沉浸式状态栏（让海洋渐变延伸到顶部）
    try {
      const mainWin = windowStage.getMainWindowSync();
      mainWin.setWindowLayoutFullScreen(true);
      mainWin.setWindowSystemBarProperties({
        statusBarContentColor: '#FFFFFF',
        navigationBarContentColor: '#FFFFFF'
      });
    } catch (e) {
      hilog.warn(DOMAIN, 'window', 'set immersive failed: %{public}s', JSON.stringify(e));
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}

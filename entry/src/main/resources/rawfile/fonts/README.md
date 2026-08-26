# 霞鹜文楷 (LXGW WenKai) 字体安装说明

本应用使用 **霞鹜文楷 LXGW WenKai** 作为全局字体。请按以下步骤将字体文件放置到本目录：

## 1. 下载字体

从官方仓库下载 TTF 文件（推荐使用 Regular/Mono 版本）：

- GitHub 发布页：https://github.com/lxgw/LxgwWenKai/releases
- 推荐文件：`LXGWWenKai-Regular.ttf`（常规体）

## 2. 放置文件

将下载的 TTF 重命名为 **`LXGWWenKai.ttf`**，放置于本目录：

```
entry/src/main/resources/rawfile/fonts/LXGWWenKai.ttf
```

## 3. 自动生效

字体由 `EntryAbility.onWindowStageCreate()` 在应用启动时通过 `font.registerFont({ familyName: 'LXGWWenKai', ... })` 注册；所有 UI 组件通过 `.fontFamily(LXGW_FONT)` 引用即可生效。

## 授权

霞鹜文楷以 **SIL Open Font License 1.1** 授权，可免费商用。

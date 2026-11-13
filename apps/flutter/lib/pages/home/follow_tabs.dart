/// “关注”页各分类的标题与接口 URL（与 V9_HOME_TAB_FOLLOW 的 type 参数对应）。
String getFollowTitle(int index) {
  return switch (index) {
    1 => '用户关注',
    2 => '话题关注',
    3 => '数码关注',
    4 => '应用关注',
    _ => '全部关注',
  };
}

String getFollowUrl(int index) {
  String url = '/page?url=V9_HOME_TAB_FOLLOW';
  return switch (index) {
    1 => '$url&type=circle',
    2 => '$url&type=topic',
    3 => '$url&type=product',
    4 => '$url&type=apk',
    _ => url,
  };
}

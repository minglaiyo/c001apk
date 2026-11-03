import '../../constants/constants.dart';

class Api {
  static const String getHomeFeed =
      '${Constants.URL_API2_SERVICE}/v6/main/indexV8';

  static String getDataList = '${Constants.URL_API_SERVICE}/v6/page/dataList';

  static String getDataFromUrl(String url) {
    return '${Constants.URL_API_SERVICE}$url';
  }

  static String getFeedReply =
      '${Constants.URL_API2_SERVICE}/v6/feed/replyList';

  static String getUserFeed = '${Constants.URL_API_SERVICE}/v6/user/feedList';

  static String getAppInfo = '${Constants.URL_API_SERVICE}/v6/apk/detail';

  static String getSearch = '${Constants.URL_API_SERVICE}/v6/search';

  static String getSearchSuggest =
      '${Constants.URL_API_SERVICE}/v6/search/suggestSearchWordsNew';

  static String getProductDetail =
      '${Constants.URL_API_SERVICE}/v6/product/detail';

  static String getFeedChangeHistory =
      '${Constants.URL_API_SERVICE}/v6/feed/changeHistoryList';

  static String checkLoginInfo =
      '${Constants.URL_API_SERVICE}/v6/account/checkLoginInfo';

  static String getAppsUpdate =
      '${Constants.URL_API_SERVICE}/v6/apk/checkUpdate';

  static String getDyhDetail =
      '${Constants.URL_API_SERVICE}/v6/dyhArticle/list';

  static String getCoolPic = '${Constants.URL_API_SERVICE}/v6/picture/list';

  static String getReply2Reply =
      '${Constants.URL_API_SERVICE}/v6/feed/replyList';

  static String getAppDownloadUrl =
      '${Constants.URL_API_SERVICE}/v6/apk/download';

  static String getLoginParam(String url) {
    return '${Constants.URL_ACCOUNT_SERVICE}$url';
  }

  static String onLogin =
      '${Constants.URL_ACCOUNT_SERVICE}/auth/loginByCoolApk';

  static String getProfile = '${Constants.URL_API_SERVICE}/v6/user/profile';

  static String checkCount =
      '${Constants.URL_API_SERVICE}/v6/notification/checkCount';

  static String postReply = '${Constants.URL_API_SERVICE}/v6/feed/reply';

  static String postCreateFeed =
      '${Constants.URL_API_SERVICE}/v6/feed/createFeed';

  static String postRequestValidate =
      '${Constants.URL_API_SERVICE}/v6/account/requestValidate';

  // ---- B 层参考接口（未实测参考，来自 daimiaopeng/coolapk-desktop 公开代码）----
  // 投票、产品图集、评分分布、收藏单写操作、云端浏览历史的端点均属参考级：
  // 解析全部空安全，首次真机使用即当探针，失败时显示提示而非崩溃。
  static String postVote = '${Constants.URL_API_SERVICE}/v6/vote/createUserVote';

  static String getProductMediaList =
      '${Constants.URL_API_SERVICE}/v6/product/mediaList';

  static String postCollectionCreate =
      '${Constants.URL_API_SERVICE}/v6/collection/create';
  static String postCollectionUpdate =
      '${Constants.URL_API_SERVICE}/v6/collection/update';
  static String postCollectionDelete =
      '${Constants.URL_API_SERVICE}/v6/collection/delete';
  static String postCollectionAddItem =
      '${Constants.URL_API_SERVICE}/v6/collection/addItem';
  static String postCollectionRemoveItem =
      '${Constants.URL_API_SERVICE}/v6/collection/removeItem';
  static String postCollectionRemoveUnUseItem =
      '${Constants.URL_API_SERVICE}/v6/collection/removeUnUseItem';
  static String getCollectionList =
      '${Constants.URL_API_SERVICE}/v6/collection/list';
  static String getCollectionItemList =
      '${Constants.URL_API_SERVICE}/v6/collection/itemList';

  static String getHitHistoryList =
      '${Constants.URL_API_SERVICE}/v6/user/hitHistoryList';
}

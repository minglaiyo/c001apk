import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData;

import '../../constants/constants.dart';
import '../../logic/model/feed/data_list_model.dart';
import '../../logic/model/feed/data_model.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/network/api.dart';
import '../../logic/network/api_failure.dart';
import '../../logic/network/request.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/feed/feed_change_history.dart';
import '../../pages/product/product_detail.dart';
import '../../pages/search/search_suggestion.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';
import '../../utils/storage_util.dart';
import '../../utils/token_util.dart';

class NetworkRepo {
  static void requireMessageMutation(Response response) {
    final data = readApiObject(response)['data'];
    final count = data is Map ? data['count'] : data;
    if (count == null || count == false || count.toString().trim().isEmpty) {
      throw const ApiFailure(
          ApiFailureKind.invalidResponse, '服务端未确认操作结果，请刷新后查看');
    }
  }

  static Future<LoadingState<Map<String, dynamic>>> getEventDetail(
      String id) async {
    if (!RegExp(r'^[0-9]+$').hasMatch(id)) {
      return LoadingState.error('活动编号无效');
    }
    try {
      final response = await Request().get(
        Api.getDataFromUrl('/v6/event/detail'),
        queryParameters: {'id': id},
      );
      final data = readApiObject(response)['data'];
      if (data == null) return LoadingState.empty();
      if (data is! Map<String, dynamic> || data['title'] is! String) {
        throw const ApiFailure(ApiFailureKind.parsing, '活动数据格式异常，请稍后重试');
      }
      return LoadingState.success(data);
    } catch (error) {
      return LoadingState.error(ApiFailure.fromError(error).message);
    }
  }

  static Future<Response> postOSSUploadPrepare({
    required FormData data,
  }) async {
    return Request().post(Api.getDataFromUrl('/v6/upload/ossUploadPrepare'),
        data: data,
        options: Options(contentType: Headers.multipartFormDataContentType));
  }

  static Future<Response> sendMessage({
    required dynamic uid,
    required FormData data,
  }) async {
    return Request().post(
      Api.getDataFromUrl('/v6/message/send'),
      queryParameters: {
        'uid': uid,
      },
      data: data,
      options: Options(
          contentType: Headers.multipartFormDataContentType,
          extra: {'silentError': true}),
    );
  }

  static Future<Response> getImageUrl({
    required dynamic id,
  }) async {
    return Request().get(
      Api.getDataFromUrl('/v6/message/showImage'),
      queryParameters: {
        'id': id,
        'type': 's',
      },
      options: Options(followRedirects: false),
    );
  }

  static Future<Response> deleteMsg(
    String url, {
    dynamic ukey,
    dynamic id,
  }) async {
    return Request().get(
      Api.getDataFromUrl(url),
      queryParameters: {
        if (ukey != null) 'ukey': ukey,
        if (id != null) 'id': id,
      },
    );
  }

  static Future<LoadingState> messageOperation(
    String url, {
    String? ukey,
    String? uid,
    int? page,
    dynamic firstItem,
    dynamic lastItem,
  }) async {
    return getListData(
      () => Request().get(
        Api.getDataFromUrl(url),
        queryParameters: {
          if (ukey != null) 'ukey': ukey,
          if (uid != null) 'uid': uid,
          if (page != null) 'page': page,
          if (firstItem != null) 'firstItem': firstItem,
          if (lastItem != null) 'lastItem': lastItem,
        },
      ),
    );
  }

  static Future<Response> getFollow(
    String url, {
    String? tag,
    String? id,
  }) async {
    return Request().get(
      Api.getDataFromUrl(url),
      queryParameters: {
        if (tag != null) 'tag': tag,
        if (id != null) 'id': id,
      },
    );
  }

  static Future<Response> postLikeDeleteFollow(
    String url, {
    dynamic id,
    dynamic uid,
    FormData? data,
  }) async {
    final isLike = [
      '/v6/feed/like',
      '/v6/feed/unlike',
      '/v6/feed/likeReply',
      '/v6/feed/unLikeReply'
    ].contains(url);
    return Request().post(
      Api.getDataFromUrl(url),
      queryParameters: {
        if (id != null) 'id': id,
        if (uid != null) 'uid': uid,
        if (isLike) 'detail': 0,
      },
      data: isLike ? {'trace': ''} : data,
      options: isLike
          ? Options(contentType: Headers.formUrlEncodedContentType)
          : null,
    );
  }

  static Future<Response> postRequestValidate(
    FormData data,
  ) async {
    return Request().post(
      Api.postRequestValidate,
      data: data,
    );
  }

  static Future<Response> getValidateCaptcha() async {
    return Request().get(
      '${Constants.URL_API_SERVICE}/v6/account/captchaImage',
      queryParameters: {
        '_': DateTime.now().millisecondsSinceEpoch,
        'w': 270,
        'h': 113,
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  static Future<Response> postCreateFeed(
    FormData data,
  ) async {
    final body = Map<String, dynamic>.fromEntries(data.fields);
    body['publish_status'] ??= body['status'] == '-1' ? '1' : '0';
    body['status'] = '1';
    final multipart = data.clone();
    multipart.fields
      ..clear()
      ..addAll(body.entries.map((e) => MapEntry(e.key, e.value.toString())));
    return Request().post(
      Api.postCreateFeed,
      data: data.files.isEmpty ? body : multipart,
      options: data.files.isEmpty
          ? Options(contentType: Headers.formUrlEncodedContentType)
          : null,
    );
  }

  static Future<Response> postReply(
    FormData data,
    dynamic id,
    String type,
  ) async {
    return Request().post(
      Api.postReply,
      data: data.files.isEmpty
          ? Map<String, dynamic>.fromEntries(data.fields)
          : data,
      options: data.files.isEmpty
          ? Options(contentType: Headers.formUrlEncodedContentType)
          : null,
      queryParameters: {'id': id, 'type': type},
    );
  }

  static Future<Response> checkCount() async {
    return Request().get(Api.checkCount);
  }

  static Future<Response> getProfile(String uid) async {
    return Request().get(Api.getProfile,
        queryParameters: {'uid': uid},
        options: Options(extra: {'skipCaptcha': true}));
  }

  static Future<Response> onLogin(
    String requestHash,
    String account,
    String pwd,
    String captcha,
  ) async {
    return Request().post(Api.onLogin,
        data: {
          'submit': '1',
          'randomNumber': TokenUtils.createRandomNumber(),
          'requestHash': requestHash,
          'login': account,
          'password': pwd,
          'captcha': captcha,
          'code': '',
        },
        options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.plain));
  }

  static Future<Response> getLoginParam(String url, [Options? options]) async {
    return Request().get(Api.getLoginParam(url), options: options);
  }

  static Future<LoadingState> getReply2Reply({
    required String id,
    required int page,
    required String? firstItem,
    required String? lastItem,
  }) async {
    return getListData(
      () => Request().get(Api.getReply2Reply, queryParameters: {
        'id': id,
        'page': page,
        'listType': '',
        'discussMode': 0,
        'feedType': 'feed_reply',
        'blockStatus': 0,
        'fromFeedAuthor': 0,
        if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
        if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
      }),
    );
  }

  static Future<LoadingState> getCoolPic({
    required String tag,
    required String type,
    required int page,
    required String? firstItem,
    required String? lastItem,
  }) async {
    return getListData(
      () => Request().get(Api.getCoolPic, queryParameters: {
        'tag': tag,
        'type': type,
        'page': page,
        if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
        if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
      }),
    );
  }

  static Future<LoadingState> getDyhDetail({
    required String dyhId,
    required String type,
    required int page,
    required String? firstItem,
    required String? lastItem,
  }) async {
    return getListData(
      () => Request().get(Api.getDyhDetail, queryParameters: {
        'dyhId': dyhId,
        'type': type,
        'page': page,
        if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
        if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
      }),
    );
  }

  static Future<Response> getAppsUpdate(
    String pkgs,
  ) async {
    return Request().post(
      Api.getAppsUpdate,
      queryParameters: {'coolmarket_beta': '0'},
      data: FormData.fromMap({
        'pkgs': pkgs,
      }),
    );
  }

  static Future<Response> checkLoginInfo() async {
    return Request().get(Api.checkLoginInfo,
        options: Options(extra: {'skipCaptcha': true}));
  }

  static Future<LoadingState> getSearch({
    required String type,
    required String feedType,
    required String sort,
    required String searchValue,
    required int isStrict,
    required String? pageType,
    required String? pageParam,
    required int page,
    required String? firstItem,
    required String? lastItem,
  }) async {
    return getListData(
      () => Request().get(Api.getSearch, queryParameters: {
        'type': type,
        'feedType': feedType,
        'sort': sort,
        'searchValue': searchValue,
        'isStrict': isStrict,
        if (!pageType.isNullOrEmpty) 'pageType': pageType,
        if (!pageParam.isNullOrEmpty) 'pageParam': pageParam,
        'page': page,
        if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
        if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
        'showAnonymous': -1,
      }),
    );
  }

  /// Hot-search keywords for the empty global search page, from
  /// `GET /v6/search?type=hotSearch&refresh=1&returnType=all` (the same
  /// request the official client and coolapk-desktop use). Returns an
  /// empty list on any failure so the hot section simply stays hidden
  /// instead of breaking the search page.
  static Future<List<String>> getHotSearches() async {
    try {
      final response = await Request().get(Api.getSearch, queryParameters: {
        'type': 'hotSearch',
        'refresh': 1,
        'returnType': 'all',
      });
      return parseHotSearchKeywords(readApiObject(response)['data']);
    } catch (_) {
      return [];
    }
  }

  /// Input suggestions for a keyword, from
  /// `GET /v6/search/suggestSearchWordsNew`. The `app` variant is tried
  /// first by the caller (like coolapk-desktop); this method only runs
  /// one variant. Returns an empty list on any failure.
  static Future<List<SearchSuggestion>> getSearchSuggestions(
    String query, {
    bool app = false,
  }) async {
    try {
      final response = await Request().get(Api.getSearchSuggest,
          queryParameters: {
            'searchValue': query,
            if (app) 'type': 'app',
          });
      return parseSearchSuggestions(readApiObject(response)['data']);
    } catch (_) {
      return [];
    }
  }

  // ---- B 层参考接口（未实测参考，来自 daimiaopeng/coolapk-desktop 公开代码）----
  // 所有方法只做宽容解析：形状不对时返回空/错误态，绝不抛到 UI 崩溃。
  // 投票提交、收藏写操作的首个真机使用即当探针。

  static String _picFromItem(dynamic item) {
    if (item is String) return item.trim();
    if (item is! Map) return '';
    final arr = item['picArr'] ?? item['imageUriList'];
    if (arr is List && arr.isNotEmpty) {
      final first = arr.first;
      if (first is String && first.trim().isNotEmpty) return first.trim();
      if (first is Map) {
        final url = (first['pic'] ?? first['url'] ?? '').toString().trim();
        if (url.isNotEmpty) return url;
      }
    }
    for (final key in ['pic', 'image', 'url', 'logo', 'cover_pic']) {
      final value = item[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  /// Product media gallery, from
  /// `GET /v6/product/mediaList?id=...&type=image&is_recommend=...&page=...`
  /// (reference only, untested). Returns picture URLs, picArr /
  /// imageUriList / pic兜底；失败或为空时调用方回落到单图 logo。
  static Future<LoadingState<List<String>>> getProductMediaList({
    required String id,
    int page = 1,
    int isRecommend = 0,
  }) async {
    try {
      final response = await Request().get(Api.getProductMediaList,
          queryParameters: {
            'id': id,
            'type': 'image',
            'is_recommend': isRecommend,
            'page': page,
          });
      final raw = readApiObject(response)['data'];
      final items = raw is List
          ? raw
          : raw is Map
              ? (raw['data'] as List? ?? raw['list'] as List? ?? const [])
              : const [];
      final urls = <String>[];
      for (final item in items) {
        final url = _picFromItem(item);
        if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
      }
      return urls.isEmpty
          ? LoadingState.empty()
          : LoadingState.success(urls);
    } catch (error) {
      return LoadingState.error(ApiFailure.fromError(error).message);
    }
  }

  /// Product rating distribution, from
  /// `GET /v6/product/ratingChart?id=...` (reference only, untested).
  /// 原始 Map 原样返回，由 rating_chart.dart 宽容解析总体分布。
  static Future<LoadingState<Map<String, dynamic>>> getProductRatingChart(
      String id) async {
    try {
      final response = await Request().get(Api.getProductRatingChart,
          queryParameters: {'id': id});
      final raw = readApiObject(response)['data'];
      if (raw is Map<String, dynamic>) {
        return LoadingState.success(raw);
      }
      if (raw is Map) {
        return LoadingState.success(Map<String, dynamic>.from(raw));
      }
      return LoadingState.empty();
    } catch (error) {
      return LoadingState.error(ApiFailure.fromError(error).message);
    }
  }

  /// Dynamic vote submit, from POST /v6/vote/createUserVote
  /// (reference only, untested; NOT /v6/goodsList/vote, which is a
  /// goods-list vote). Form: id + select_option[0..n] + anonymous_status.
  /// 成功回包可能 message-only，调用方须 allowSuccessWithoutData。
  static Future<Response> postVote({
    required dynamic feedId,
    required List<String> optionIds,
    bool anonymous = false,
  }) async {
    final fields = <String, dynamic>{
      'id': feedId.toString(),
      'anonymous_status': anonymous ? 1 : 0,
    };
    for (var i = 0; i < optionIds.length; i++) {
      fields['select_option[$i]'] = optionIds[i];
    }
    return postLikeDeleteFollow(
      '/v6/vote/createUserVote',
      data: FormData.fromMap(fields),
    );
  }

  static Future<Response> _postCollection(
    String url,
    Map<String, dynamic> fields,
  ) {
    return postLikeDeleteFollow(url, data: FormData.fromMap(fields));
  }

  /// Collection writes (reference only, untested). update 的 id 必须
  /// 放表单字段；removeItem 的 itemId 是收藏单条目 id，不是动态 id。
  static Future<Response> createCollection({
    required String title,
    String description = '',
    int isOpen = 0,
    String pic = '',
    String sourceId = '',
  }) =>
      _postCollection(Api.postCollectionCreate, {
        'title': title,
        'description': description,
        'isOpen': isOpen,
        'pic': pic,
        'sourceId': sourceId,
      });

  static Future<Response> updateCollection({
    required dynamic id,
    required String title,
    String description = '',
    int isOpen = 0,
    String pic = '',
  }) =>
      _postCollection(Api.postCollectionUpdate, {
        'id': id.toString(),
        'title': title,
        'description': description,
        'isOpen': isOpen,
        'pic': pic,
      });

  static Future<Response> deleteCollection(dynamic id) =>
      _postCollection(Api.postCollectionDelete, {'id': id.toString()});

  /// id = 收藏单 id（可多个时逗号分隔传参由服务端定，单选先行）；
  /// cancelId = 移出的单 id；targetId = 内容 id；type 如 'feed'。
  static Future<Response> addCollectionItem({
    required dynamic id,
    dynamic cancelId,
    required dynamic targetId,
    String type = 'feed',
  }) =>
      _postCollection(Api.postCollectionAddItem, {
        'id': id.toString(),
        if (cancelId != null) 'cancelId': cancelId.toString(),
        'targetId': targetId.toString(),
        'type': type,
        'trace': '',
      });

  static Future<Response> removeCollectionItem(dynamic itemId) =>
      _postCollection(Api.postCollectionRemoveItem, {
        'itemId': itemId.toString(),
      });

  static Future<Response> removeUnUseCollectionItem(dynamic colId) =>
      _postCollection(Api.postCollectionRemoveUnUseItem, {
        'colId': colId.toString(),
      });

  /// Which collections already contain a feed, from
  /// `GET /v6/collection/list?uid=&id={feedId}&type=feed&showDefault=1`
  /// (reference only, untested). Returns collection Datum rows.
  static Future<LoadingState> getCollectionStateForFeed(dynamic feedId) {
    return getDataListFromUrl(
      url: '/v6/collection/list',
      data: {
        'uid': GlobalData().uid,
        'id': feedId.toString(),
        'type': 'feed',
        'showDefault': 1,
        'page': 1,
      },
    );
  }

  /// Cloud browsing history, from
  /// `GET /v6/user/hitHistoryList?type=...&page=...&firstItem=...&lastItem=...`
  /// (reference only, untested). NOTE: this is NOT recentHistoryList,
  /// which is “我的常去”. type 取值未实测，先传空，客户端再兜底筛。
  static Future<LoadingState> getHitHistoryList({
    String type = '',
    int page = 1,
    String? firstItem,
    String? lastItem,
  }) {
    return getDataListFromUrl(
      url: '/v6/user/hitHistoryList',
      data: {
        if (type.isNotEmpty) 'type': type,
        'page': page,
        if (firstItem != null) 'firstItem': firstItem,
        if (lastItem != null) 'lastItem': lastItem,
      },
    );
  }

  /// Product detail for the product page, from
  /// `GET /v6/product/detail?id=...`. Throws [ApiFailure] on a bad
  /// response so the page can show its error state with a retry.
  static Future<ProductDetail> getProductDetail(String id) async {
    final response = await Request().get(Api.getProductDetail,
        queryParameters: {'id': id});
    final data = readApiObject(response)['data'];
    if (data is! Map) {
      throw const ApiFailure(
          ApiFailureKind.invalidResponse, '产品详情格式异常，请稍后重试');
    }
    return parseProductDetail(id, data);
  }

  /// Product feed list for one product tab, from
  /// `GET /v6/page/dataList?url=/page?url=/product/feedList` with the
  /// product id and the tab's type (or `subTabFeed` + `subId` for a
  /// server sub-tab), mirroring coolapk-desktop's query builders.
  static Future<LoadingState> getProductFeeds({
    required String productId,
    required String feedType,
    String? subId,
    String? listType,
    required int page,
    String? firstItem,
    String? lastItem,
  }) async {
    return getListData(
      () => Request().get(Api.getDataList, queryParameters: {
        'url': '/page?url=/product/feedList',
        'id': productId,
        'type': subId != null ? 'subTabFeed' : feedType,
        if (subId != null) 'subId': subId,
        if (subId != null) 'cacheExpires': '60',
        if (subId != null) 'withSortCard': '1',
        if (subId != null) 'withSubTabFeedCard': '1',
        if (subId != null) 'ignoreEntityById': '1',
        if (listType != null && listType.isNotEmpty) 'listType': listType,
        if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
        if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
        'page': page,
      }),
    );
  }

  /// Edit history for one feed, from
  /// `GET /v6/feed/changeHistoryList?id=...`, current version first.
  static Future<List<FeedChangeHistoryItem>> getFeedChangeHistory(
      String id) async {
    final response = await Request().get(Api.getFeedChangeHistory,
        queryParameters: {'id': id});
    return parseFeedChangeHistory(readApiObject(response)['data']);
  }

  static Future<Response> getAppDownloadUrl({
    required String packageName,
    required int id,
    required int versionCode,
  }) async {
    return Request().get(
      Api.getAppDownloadUrl,
      queryParameters: {
        'pn': packageName,
        'aid': id,
        'vc': versionCode,
        'extra': '',
      },
      options: Options(followRedirects: false),
    );
  }

  static Future<LoadingState> getAppInfo({
    required String id,
  }) async {
    return getData(
      () => Request().get(Api.getAppInfo, queryParameters: {
        'id': id,
        'installed': 1,
      }),
    );
  }

  static Future<LoadingState> getUserFeed({
    required String uid,
    required int page,
    required String? firstItem,
    required String? lastItem,
    bool includeTop = true,
  }) async {
    return getListData(
      () => Request().get(Api.getUserFeed, queryParameters: {
        'uid': uid,
        'page': page,
        if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
        if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
        'showAnonymous': 0,
        'isIncludeTop': includeTop ? 1 : 0,
        'showDoing': 0,
      }),
    );
  }

  static Future<LoadingState> getFeedReply({
    required String id,
    required String listType,
    required int page,
    required String? firstItem,
    required String? lastItem,
    required int discussMode,
    required String feedType,
    required int blockStatus,
    required int fromFeedAuthor,
    bool verify = true,
  }) async {
    return getListData(
      () => Request().get(Api.getFeedReply,
          options: Options(extra: {'skipCaptcha': !verify}),
          queryParameters: {
            'id': id,
            'listType': listType,
            'page': page,
            if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
            if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
            'discussMode': discussMode,
            'feedType': feedType,
            'blockStatus': blockStatus,
            'fromFeedAuthor': fromFeedAuthor,
          }),
    );
  }

  static Future<LoadingState> getDataFromUrl({
    required String url,
    Map<String, dynamic>? data,
  }) async {
    return getData(
      () => Request().get(Api.getDataFromUrl(url), queryParameters: data),
    );
  }

  static Future<LoadingState> getDataListFromUrl({
    required String url,
    Map<String, dynamic>? data,
  }) async {
    return getListData(
      () => Request().get(
        Api.getDataFromUrl(url),
        queryParameters: data,
      ),
    );
  }

  static Future<LoadingState> getHomeFeed({
    required int page,
    required int firstLaunch,
    required String installTime,
    required String? firstItem,
    required String? lastItem,
  }) async {
    return getListData(
      () => Request().get(
        Api.getHomeFeed,
        queryParameters: {
          'page': page,
          'firstLaunch': firstLaunch,
          'installTime': installTime,
          if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
          if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
          'ids': '',
        },
      ),
    );
  }

  static Future<LoadingState> getDataList({
    required String url,
    required String title,
    required String subTitle,
    required String? firstItem,
    required String? lastItem,
    required int page,
    bool inCluldeConfigCard = false,
  }) async {
    return getListData(
      () => Request().get(
        Api.getDataList,
        queryParameters: {
          'url': url,
          'title': title,
          'subTitle': subTitle,
          if (!firstItem.isNullOrEmpty) 'firstItem': firstItem,
          if (!lastItem.isNullOrEmpty) 'lastItem': lastItem,
          'page': page,
        },
      ),
      inCluldeConfigCard: inCluldeConfigCard,
    );
  }

  static Future<LoadingState> getFeedDetail(
      {required String id, bool verify = false}) async {
    if (!RegExp(r'^[0-9]+$').hasMatch(id)) {
      return LoadingState.error('动态编号无效');
    }
    String? captchaVerification;
    try {
      final response = await Request().get(
        Api.getDataFromUrl('/v6/feed/detail'),
        queryParameters: {'id': id},
        options: Options(extra: {'skipCaptcha': !verify}),
      );
      captchaVerification = response.extra['captchaVerification'] as String?;
      // Only access challenges permit the official public representation.
      readApiObject(response);
      return await handleDataResponse(response);
    } catch (error) {
      final failure = ApiFailure.fromError(error);
      if (verify) {
        if (captchaVerification == 'cancelled') {
          return LoadingState.error('已取消验证，可重试或导入官方设备标识', canVerify: true);
        }
        if (captchaVerification == 'submitted' &&
            failure.kind == ApiFailureKind.captcha) {
          return LoadingState.error('验证已完成，但服务端仍未允许读取详情，可稍后重试或导入官方设备标识',
              canVerify: true);
        }
        return LoadingState.error(failure.message,
            canVerify: failure.kind == ApiFailureKind.captcha ||
                failure.kind == ApiFailureKind.authentication);
      }
      if ([ApiFailureKind.captcha, ApiFailureKind.authentication]
          .contains(failure.kind)) {
        try {
          final publicResponse = await Request().get(
            '${Constants.URL_COOLAPK}feed/$id',
            options: Options(responseType: ResponseType.plain),
          );
          // The official web endpoint can stop serving its JSON representation
          // and return an app-only landing page. That page has no feed body;
          // keep the original access reason instead of treating it as bad JSON.
          final body = publicResponse.data;
          if (body is String &&
              body.trimLeft().startsWith('<') &&
              body.contains('请用酷安手机APP扫码查看详情')) {
            return LoadingState.error(
                failure.kind == ApiFailureKind.captcha
                    ? '当前设备需要验证，公开分享页暂不提供正文。可重试验证，或导入官方设备标识后重试。'
                    : '此内容需要登录，公开分享页暂不提供正文。可重试或检查登录状态。',
                canVerify: true);
          }
          final public = await handleDataResponse(publicResponse);
          if (public is Success) {
            final data = public.response as Datum;
            // A public response cannot establish this account's like state.
            data.userAction = null;
            return Success(data, isPublic: true);
          }
          return public;
        } catch (publicError) {
          return LoadingState.error(ApiFailure.fromError(publicError).message);
        }
      }
      return LoadingState.error(failure.message);
    }
  }

  static Future<LoadingState> getData(
      Future<Response<dynamic>> Function() get) async {
    try {
      var response = await get();
      return await handleDataResponse(response);
    } catch (err) {
      return LoadingState.error(ApiFailure.fromError(err).message);
    }
  }

  static Future<LoadingState> getListData(
    Future<Response<dynamic>> Function() get, {
    bool inCluldeConfigCard = false,
  }) async {
    try {
      var response = await get();
      return await handleListResponse(
        response,
        inCluldeConfigCard: inCluldeConfigCard,
      );
    } catch (err) {
      return LoadingState.error(ApiFailure.fromError(err).message);
    }
  }

  static Future<LoadingState> handleDataResponse(
      Response<dynamic> response) async {
    try {
      DataModel responseData = DataModel.fromJson(readApiObject(response));
      if (responseData.data != null) {
        return LoadingState.success(responseData.data);
      } else {
        return LoadingState.empty();
      }
    } catch (error) {
      return LoadingState.error(ApiFailure.fromError(error).message);
    }
  }

  static Future<LoadingState> handleListResponse(
    Response<dynamic> response, {
    bool inCluldeConfigCard = false,
  }) async {
    try {
      final object = readApiObject(response);
      final raw = object['data'];
      DataListModel responseData = DataListModel.fromJson({
        ...object,
        if (raw is List) 'data': _expandListCards(raw).toList(),
      });
      if (!responseData.data.isNullOrEmpty) {
        List<String> userBlackList = GStorage.blackList
            .get(BlackListBoxKey.userBlackList, defaultValue: <String>[]);
        List<String> topicBlackList = GStorage.blackList
            .get(BlackListBoxKey.topicBlackList, defaultValue: <String>[]);
        List<Datum> accepted = responseData.data!.where((item) {
          return item.entityTemplate == 'refreshCard' &&
                  item.title.orEmpty.contains('没有')
              ? true
              : (Constants.entityTypeList.contains(item.entityType) ||
                  (Constants.entityTemplateList +
                          (inCluldeConfigCard ? ['configCard'] : []))
                      .contains(item.entityTemplate));
        }).toList();
        final filterList = accepted
            .where((item) =>
                !userBlackList.contains(item.uid.toString()) &&
                topicBlackList.firstWhereOrNull((keyword) =>
                        '${item.tags},${item.ttitle},${item.relationRows?.getOrNull(0)?.title}'
                            .contains(keyword)) ==
                    null)
            .toList();
        final cursorRows = responseData.data!.where((item) => item.id != null);
        return Success(filterList,
            rawResponse: accepted,
            firstItem: cursorRows.firstOrNull?.id.toString(),
            lastItem: cursorRows.lastOrNull?.id.toString());
      } else {
        return LoadingState.empty();
      }
    } catch (error) {
      return LoadingState.error(ApiFailure.fromError(error).message);
    }
  }

  /// Search results group normal entities inside listCard containers. Expand
  /// before model parsing so child IDs, messages and pagination remain intact.
  static Iterable<dynamic> _expandListCards(List<dynamic> items,
      [int depth = 0]) sync* {
    if (depth > 20) {
      throw const ApiFailure(ApiFailureKind.invalidResponse, '服务器响应结构异常，请稍后重试');
    }
    for (final item in items) {
      if (item is Map<String, dynamic> &&
          item['entityType'] == 'card' &&
          item['entityTemplate'] == 'listCard') {
        final children = item['entities'];
        if (children is List) yield* _expandListCards(children, depth + 1);
      } else {
        yield item;
      }
    }
  }
}

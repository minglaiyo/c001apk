import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../components/app_sheet.dart';

import '../../../components/common_body.dart';
import '../../../components/content_filter_gate.dart';
import '../../../logic/model/feed/datum.dart';
import '../../../logic/state/loading_state.dart';
import '../../../pages/feed/reply/reply_dialog.dart' show ReplyType;
import '../../../pages/feed/reply/reply_page.dart';
import '../../../pages/feed/reply2reply/reply_2_reply_controller.dart';
import '../../../utils/global_data.dart';

class Reply2ReplyPage extends StatelessWidget {
  const Reply2ReplyPage({
    super.key,
    required this.id,
    required this.replynum,
    required this.originReply,
  });

  final String id;
  final dynamic replynum;
  final Datum originReply;

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
      tag: id,
      init: Reply2ReplyController(originReply: originReply, id: id),
      dispose: (state) {
        state.controller?.scrollController?.dispose();
      },
      builder: (controller) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            middle: Text(
              '共 $replynum 回复',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.normal,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            )),
        child: SafeArea(
          bottom: false,
          child: Obx(
            () => ContentFilterRevealScope(
              contentKeys: controller.revealedContentKeys,
              authorUids: controller.revealedAuthorUids,
              child: Column(children: [
                ContentFilterSummary(controller: controller),
                Expanded(
                  child: controller.loadingState.value is Success
                      ? buildBody(
                          controller,
                          isReply2Reply: true,
                          uid: originReply.uid,
                          onReply: (id, uname, fid) async {
                            if (GlobalData().isLogin) {
                              showBottomSheetPage(
                                context: context,
                                page: ReplyPage(
                                  type: ReplyType.reply,
                                  username: uname,
                                  id: id,
                                ),
                              ).then(
                                (result) {
                                  if (result != null &&
                                      result['data'] != null) {
                                    controller.updateReply(
                                        result['data'] as Datum, id);
                                  }
                                },
                              );
                            }
                          },
                        )
                      : Center(
                          child: buildBody(
                            controller,
                            isReply2Reply: true,
                            uid: originReply.uid,
                          ),
                        ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

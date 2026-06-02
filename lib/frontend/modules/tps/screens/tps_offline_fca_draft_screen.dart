import 'package:flutter/widgets.dart';
import 'package:tanodmobile/frontend/modules/tps/screens/tps_create_fca_screen.dart';
import 'package:tanodmobile/models/local/offline_fca_draft.dart';

class TpsOfflineFcaDraftScreen extends StatelessWidget {
  const TpsOfflineFcaDraftScreen({super.key, this.draft});

  final OfflineFcaDraft? draft;

  @override
  Widget build(BuildContext context) {
    return TpsCreateFcaScreen(offlineDraftMode: true, offlineDraft: draft);
  }
}

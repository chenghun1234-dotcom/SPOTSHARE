import 'package:url_launcher/url_launcher.dart';

class TossService {
  static Future<void> openTossForAd({
    required String bank,
    required String accountNo,
    required int amount,
    required String depositCode,
  }) async {
    final String tossUrl =
        "supertoss://send?bank=$bank&accountNo=$accountNo&amount=$amount&memo=$depositCode";
    final Uri uri = Uri.parse(tossUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(Uri.parse("https://toss.im/_m/deposit"));
    }
  }
}

import '../models/fee_details_model.dart';
import '../services/fees_api_service.dart';

class FeesRepository {
  const FeesRepository(this._feesApiService);

  final FeesApiService _feesApiService;

  Future<FeeDetailsModel> fetchFeeDetails({int? academicSessionId}) {
    return _feesApiService.fetchFeeDetails(
      academicSessionId: academicSessionId,
    );
  }

  Future<String> downloadReceipt(String url) {
    return _feesApiService.downloadReceipt(url);
  }
}

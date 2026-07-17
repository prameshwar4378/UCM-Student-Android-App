class FeeDetailsModel {
  const FeeDetailsModel({
    required this.student,
    required this.summary,
    required this.fees,
    required this.categoryWise,
    required this.batchWise,
    required this.paymentHistory,
  });

  final FeeStudentModel student;
  final FeeSummaryModel summary;
  final List<FeeItemModel> fees;
  final List<FeeGroupModel> categoryWise;
  final List<FeeGroupModel> batchWise;
  final List<PaymentHistoryModel> paymentHistory;

  factory FeeDetailsModel.fromJson(Map<String, dynamic> json) {
    return FeeDetailsModel(
      student: FeeStudentModel.fromJson(_map(json['student'])),
      summary: FeeSummaryModel.fromJson(_map(json['summary'])),
      fees: _list(json['fees']).map(FeeItemModel.fromJson).toList(),
      categoryWise: _list(
        json['category_wise'],
      ).map(FeeGroupModel.fromJson).toList(),
      batchWise: _list(json['batch_wise']).map(FeeGroupModel.fromJson).toList(),
      paymentHistory: _list(
        json['payment_history'],
      ).map(PaymentHistoryModel.fromJson).toList(),
    );
  }

  factory FeeDetailsModel.fromSplitJson({
    required Map<String, dynamic> summary,
    required Map<String, dynamic> invoices,
    required Map<String, dynamic> breakup,
    required Map<String, dynamic> payments,
  }) {
    return FeeDetailsModel(
      student: FeeStudentModel.fromJson(_map(summary['student'])),
      summary: FeeSummaryModel.fromJson(_map(summary['summary'])),
      fees: _list(invoices['fees']).map(FeeItemModel.fromJson).toList(),
      categoryWise: _list(
        breakup['category_wise'],
      ).map(FeeGroupModel.fromJson).toList(),
      batchWise: _list(
        breakup['batch_wise'],
      ).map(FeeGroupModel.fromJson).toList(),
      paymentHistory: _list(
        payments['payments'],
      ).map(PaymentHistoryModel.fromJson).toList(),
    );
  }
}

class FeeStudentModel {
  const FeeStudentModel({
    required this.id,
    required this.admissionNumber,
    required this.name,
    required this.username,
    required this.instituteName,
    required this.instituteLogoUrl,
  });

  final int id;
  final String admissionNumber;
  final String name;
  final String username;
  final String instituteName;
  final String instituteLogoUrl;

  factory FeeStudentModel.fromJson(Map<String, dynamic> json) {
    final institute = _map(json['institute']);
    return FeeStudentModel(
      id: _int(json['id']),
      admissionNumber: json['admission_number'] as String? ?? '',
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      instituteName: institute['name'] as String? ?? '',
      instituteLogoUrl:
          institute['logo_url'] as String? ??
          institute['logo'] as String? ??
          json['institute_logo_url'] as String? ??
          '',
    );
  }
}

class FeeSummaryModel {
  const FeeSummaryModel({
    required this.totalFeeAmount,
    required this.totalPaidAmount,
    required this.totalDueAmount,
    required this.overpaidAmount,
    required this.invoiceCount,
    required this.activePaymentCount,
  });

  final double totalFeeAmount;
  final double totalPaidAmount;
  final double totalDueAmount;
  final double overpaidAmount;
  final int invoiceCount;
  final int activePaymentCount;

  factory FeeSummaryModel.fromJson(Map<String, dynamic> json) {
    return FeeSummaryModel(
      totalFeeAmount: _double(json['total_fee_amount']),
      totalPaidAmount: _double(json['total_paid_amount']),
      totalDueAmount: _double(json['total_due_amount']),
      overpaidAmount: _double(json['overpaid_amount']),
      invoiceCount: _int(json['invoice_count']),
      activePaymentCount: _int(json['active_payment_count']),
    );
  }
}

class FeeItemModel {
  const FeeItemModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.paidAmount,
    required this.dueAmount,
    required this.dueDate,
    required this.status,
    required this.categoryName,
    required this.batchName,
  });

  final int id;
  final String title;
  final double amount;
  final double paidAmount;
  final double dueAmount;
  final String dueDate;
  final String status;
  final String categoryName;
  final String? batchName;

  factory FeeItemModel.fromJson(Map<String, dynamic> json) {
    final category = _map(json['category']);
    final batch = _map(json['batch']);
    return FeeItemModel(
      id: _int(json['id']),
      title: json['title'] as String? ?? '',
      amount: _double(json['amount']),
      paidAmount: _double(json['paid_amount']),
      dueAmount: _double(json['due_amount']),
      dueDate: json['due_date'] as String? ?? '',
      status: json['status'] as String? ?? '',
      categoryName: category['name'] as String? ?? 'General',
      batchName: batch['name'] as String?,
    );
  }
}

class FeeGroupModel {
  const FeeGroupModel({
    required this.id,
    required this.name,
    required this.totalAmount,
    required this.paidAmount,
    required this.dueAmount,
  });

  final int? id;
  final String name;
  final double totalAmount;
  final double paidAmount;
  final double dueAmount;

  factory FeeGroupModel.fromJson(Map<String, dynamic> json) {
    return FeeGroupModel(
      id: json['id'] == null ? null : _int(json['id']),
      name: json['name'] as String? ?? '',
      totalAmount: _double(json['total_amount']),
      paidAmount: _double(json['paid_amount']),
      dueAmount: _double(json['due_amount']),
    );
  }
}

class PaymentHistoryModel {
  const PaymentHistoryModel({
    required this.id,
    required this.receiptNumber,
    required this.amount,
    required this.paidOn,
    required this.method,
    required this.status,
    required this.receiptDownloadUrl,
    required this.invoiceTitle,
  });

  final int id;
  final String receiptNumber;
  final double amount;
  final String paidOn;
  final String method;
  final String status;
  final String receiptDownloadUrl;
  final String invoiceTitle;

  factory PaymentHistoryModel.fromJson(Map<String, dynamic> json) {
    final invoice = _map(json['invoice']);
    return PaymentHistoryModel(
      id: _int(json['id']),
      receiptNumber: json['receipt_number'] as String? ?? '',
      amount: _double(json['amount']),
      paidOn: json['paid_on'] as String? ?? '',
      method: json['method'] as String? ?? '',
      status: json['status'] as String? ?? '',
      receiptDownloadUrl: json['receipt_download_url'] as String? ?? '',
      invoiceTitle: invoice['title'] as String? ?? '',
    );
  }
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const {};
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

double _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '')) ?? 0;
  }
  return 0;
}

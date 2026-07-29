part of 'ai_reports_cubit.dart';

class AiReportsState {
  final bool isLoading;
  final String? errorMessage;
  final bool isAnalyzing;
  final AiReportSummary? summary;
  final bool hasData;

  const AiReportsState({
    this.isLoading = true,
    this.errorMessage,
    this.isAnalyzing = false,
    this.summary,
    this.hasData = false,
  });

  AiReportsState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isAnalyzing,
    AiReportSummary? summary,
    bool? hasData,
  }) {
    return AiReportsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      summary: summary ?? this.summary,
      hasData: hasData ?? this.hasData,
    );
  }
}

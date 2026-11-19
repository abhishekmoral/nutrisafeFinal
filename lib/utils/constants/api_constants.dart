/// -- Backend constants.
/// Only the Supabase URL and the PUBLISHABLE key belong here.
/// Never put the service-role key or any AI API key inside the Flutter app.
class XApiConstants {
  XApiConstants._();

  /// The "nutrisafe" Supabase project. The publishable key is meant to be shipped in the app;
  /// Row Level Security protects the data. (Both can be overridden with --dart-define.)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oowirzrhoqbczjgmhfjg.supabase.co',
  );
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_rTIlHq22IFekR8BYwTQZkQ_VYEzb6T2',
  );

  /// Deep link used after Google sign-in and email links.
  static const String authRedirectUrl = 'com.nutrisafe.nutrisafe://login-callback';

  /// Edge Function names
  static const String healthAgentFunction = 'health-agent';
  static const String deleteAccountFunction = 'delete-account';
  static const String analyzeReportFunction = 'analyze-report';
  static const String productLookupFunction = 'product-lookup';

  /// Storage buckets
  static const String medicalReportsBucket = 'medical-reports';

  /// Open Food Facts (public product database)
  static const String openFoodFactsBaseUrl = 'https://world.openfoodfacts.org';
}

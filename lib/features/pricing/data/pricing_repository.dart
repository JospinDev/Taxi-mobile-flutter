import '../../../core/constants/api_paths.dart';
import '../../../core/models/paginated.dart';
import '../../../core/network/api_client.dart';
import 'models/pricing_rule_model.dart';

/// Pricing API (module 4).
///
/// Clients & drivers only ever see the active rule; the admin manages all.
/// All activation/deactivation actions require an empty JSON body `{}`.
class PricingRepository {
  PricingRepository(this._api);

  final ApiClient _api;

  Future<Paginated<PricingRule>> list({
    Map<String, dynamic>? filters,
    int page = 1,
    int pageSize = 50,
  }) async {
    final data = await _api.get(
      ApiPaths.pricingRules,
      query: {...?filters, 'page': page, 'page_size': pageSize},
    );
    return Paginated.fromJson(
      (data as Map).cast<String, dynamic>(),
      PricingRule.fromJson,
    );
  }

  /// `GET /pricing/rules/active/` — throws 404 when no rule is active.
  Future<PricingRule> active() async {
    final data = await _api.get(ApiPaths.pricingRuleActive);
    return PricingRule.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<PricingRule> create(Map<String, dynamic> body) async {
    final data = await _api.post(ApiPaths.pricingRules, data: body);
    return PricingRule.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<PricingRule> update(int id, Map<String, dynamic> body) async {
    final data = await _api.patch(ApiPaths.pricingRuleById(id), data: body);
    return PricingRule.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> delete(int id) => _api.delete(ApiPaths.pricingRuleById(id));

  Future<PricingRule> activate(int id) async {
    final data = await _api.post(ApiPaths.pricingRuleActivate(id), data: const {});
    return PricingRule.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<PricingRule> deactivate(int id) async {
    final data = await _api.post(
      ApiPaths.pricingRuleDeactivate(id),
      data: const {},
    );
    return PricingRule.fromJson((data as Map).cast<String, dynamic>());
  }
}

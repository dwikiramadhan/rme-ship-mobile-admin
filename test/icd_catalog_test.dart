import 'package:bayan_rme/features/doctor/data/icd10_api.dart';
import 'package:bayan_rme/features/doctor/data/icd9_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ICD lists come from the app's assets, so these run with no network.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(Icd10Api.clearCache);

  test('ICD-10: every code, first page in code order', () async {
    final page = await Icd10Api().fetchIcd10Paginated(limit: 25);
    expect(page.total, 18543);
    expect(page.data.first.code, 'A00');
    expect(page.data.first.display, 'Cholera');
    expect(page.data, hasLength(25));
    expect(page.hasMore, isTrue);
    expect(Icd10Api.getCachedInitial(), same(page));
  });

  test('ICD-10: matches the code or the description, ignoring case', () async {
    final api = Icd10Api();
    final byCode = await api.searchIcd10(query: 'a00.0');
    expect(byCode.first.code, 'A00.0');

    final byText = await api.fetchIcd10Paginated(query: 'CHOLERA', limit: 100);
    expect(byText.data, isNotEmpty);
    expect(
      byText.data.every(
        (i) => '${i.code} ${i.display}'.toLowerCase().contains('cholera'),
      ),
      isTrue,
    );
  });

  test('ICD-10: pages follow on from each other', () async {
    final api = Icd10Api();
    final first = await api.fetchIcd10Paginated(query: 'fever', limit: 5);
    final second = await api.fetchIcd10Paginated(query: 'fever', page: 2, limit: 5);
    expect(second.data.first.code, isNot(first.data.last.code));
    expect(first.totalPages, (first.total / 5).ceil());
  });

  test('ICD-9-CM: procedures with their version', () async {
    final page = await Icd9Api().fetchIcd9Paginated(query: 'ultrasound');
    expect(page.data, isNotEmpty);
    expect(page.data.first.version, 'ICD9CM_2010');
  });

  test('no match: empty, one page', () async {
    final page = await Icd10Api().fetchIcd10Paginated(query: 'zzzz-no-such-code');
    expect(page.data, isEmpty);
    expect(page.totalPages, 1);
    expect(page.hasMore, isFalse);
  });
}

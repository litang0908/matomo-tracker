import 'package:flutter_test/flutter_test.dart';
import 'package:matomo_tracker/src/logger/logger.dart';
import 'package:matomo_tracker/src/matomo_dispatcher.dart';
import 'package:mocktail/mocktail.dart';

import '../ressources/mock/data.dart';
import '../ressources/mock/mock.dart';

void main() {
  const headerKey = 'foo';
  const headerValue = 'bar';

  setUpAll(() {
    registerFallbackValue(Uri());
    when(() => mockMatomoEvent.toMap(mockMatomoTracker)).thenReturn({});
    when(() => mockMatomoTracker.userAgent).thenReturn(null);
    when(() => mockMatomoTracker.log).thenReturn(Logger());
    when(() => mockMatomoTracker.customHeaders).thenReturn({});
  });

  group('sendBatch', () {
    setUpAll(
      () {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => mockHttpResponse);
        when(() => mockHttpResponse.statusCode).thenReturn(200);
      },
    );

    test('it should be able to send MatomoEvent in batch', () async {
      final matomoDispatcher = MatomoDispatcher(
        matomoDispatcherBaseUrl,
        matomoDispatcherToken,
        httpClient: mockHttpClient,
      );

      await matomoDispatcher
          .sendBatch([mockMatomoEvent, mockMatomoEvent], mockMatomoTracker);

      verify(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      );
    });

    test(
        'it should add user agent in http request if the first event has an user agent',
        () async {
      final events = [mockMatomoEvent, mockMatomoEvent];
      when(() => mockMatomoTracker.userAgent)
          .thenReturn(matomoTrackerUserAgent);

      final matomoDispatcher = MatomoDispatcher(
        matomoDispatcherBaseUrl,
        matomoDispatcherToken,
        httpClient: mockHttpClient,
      );

      await matomoDispatcher.sendBatch(events, mockMatomoTracker);

      verify(
        () => mockHttpClient.post(
          any(),
          headers: any(
            named: 'headers',
            that: containsPair(
              MatomoDispatcher.userAgentHeaderKeys,
              matomoTrackerUserAgent,
            ),
          ),
          body: any(named: 'body'),
        ),
      );
    });

    test(
        'it should send nothing in sendBatch if the list of MatomoEvent is empty',
        () async {
      final matomoDispatcher = MatomoDispatcher(
        matomoDispatcherBaseUrl,
        matomoDispatcherToken,
        httpClient: mockHttpClient,
      );

      await matomoDispatcher.sendBatch([], mockMatomoTracker);

      verifyNever(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      );
    });
  });

  test('it should not throw exception if something wrong happen in sendBatch',
      () async {
    when(
      () => mockHttpClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => throw Exception());
    final matomoDispatcher = MatomoDispatcher(
      matomoDispatcherBaseUrl,
      matomoDispatcherToken,
      httpClient: mockHttpClient,
    );

    await expectLater(
      matomoDispatcher
          .sendBatch([mockMatomoEvent, mockMatomoEvent], mockMatomoTracker),
      completes,
    );
  });

  test("it should add the tokenAuth to Uri if it's not null", () {
    final matomoDispatcher = MatomoDispatcher(
      matomoDispatcherBaseUrl,
      matomoDispatcherToken,
      httpClient: mockHttpClient,
    );

    final uri =
        matomoDispatcher.buildUriForEvent(mockMatomoEvent, mockMatomoTracker);

    expect(
      uri.queryParameters[MatomoDispatcher.tokenAuthUriKey],
      matomoDispatcherToken,
    );
  });

  test('should use customHeaders from the tracker', () async {
    when(() => mockMatomoTracker.customHeaders).thenReturn({
      headerKey: headerValue,
    });

    final matomoDispatcher = MatomoDispatcher(
      matomoDispatcherBaseUrl,
      matomoDispatcherToken,
      httpClient: mockHttpClient,
    );

    await matomoDispatcher.sendBatch([mockMatomoEvent], mockMatomoTracker);

    verify(
      () => mockHttpClient.post(
        any(),
        headers: any(
          named: 'headers',
          that: containsPair(headerKey, headerValue),
        ),
        body: any(named: 'body'),
      ),
    );
  });
}

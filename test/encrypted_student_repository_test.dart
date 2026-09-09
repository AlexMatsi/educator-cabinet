import 'dart:convert';

import 'package:educator_cabinet/data/demo_repository.dart';
import 'package:educator_cabinet/data/encrypted_payload_cipher.dart';
import 'package:educator_cabinet/data/encrypted_student_repository.dart';
import 'package:educator_cabinet/data/key_provider.dart';
import 'package:educator_cabinet/data/shared_preferences_student_repository.dart';
import 'package:educator_cabinet/data/student_data_codec.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore implements StudentLocalStore {
  MemoryStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;
  bool failWrite = false;
  bool failDelete = false;

  @override
  String? read(String key) => values[key];

  @override
  Future<bool> write(String key, String value) async {
    if (failWrite) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> delete(String key) async {
    if (failDelete) return false;
    return values.remove(key) != null;
  }
}

class FakeKeyProvider implements KeyProvider {
  FakeKeyProvider({List<int>? key, this.readError, this.createError})
    : _key = key;

  List<int>? _key;
  Object? readError;
  Object? createError;
  int creates = 0;

  @override
  Future<List<int>?> read() async {
    if (readError case final error?)
      throw KeyProviderException('secure read', error);
    return _key;
  }

  @override
  Future<List<int>> create() async {
    creates++;
    if (createError case final error?) {
      throw KeyProviderException('secure write', error);
    }
    return _key = List<int>.generate(32, (index) => index);
  }
}

void main() {
  const codec = StudentDataCodec();
  final key = List<int>.generate(32, (index) => index);

  test('AES-256-GCM envelope is versioned and uses a fresh nonce', () async {
    final cipher = AesGcmPayloadCipher();
    final first = await cipher.encrypt('small json', key);
    final second = await cipher.encrypt('small json', key);
    final firstJson = jsonDecode(first) as Map<String, Object?>;
    final secondJson = jsonDecode(second) as Map<String, Object?>;

    expect(firstJson['version'], 1);
    expect(firstJson['algorithm'], 'AES-256-GCM');
    expect(base64Decode(firstJson['nonce']! as String), hasLength(12));
    expect(firstJson['nonce'], isNot(secondJson['nonce']));
    expect(await cipher.decrypt(first, key), 'small json');
  });

  test(
    'tampering fails authentication and unknown envelopes are rejected',
    () async {
      final cipher = AesGcmPayloadCipher();
      final encrypted = jsonDecode(await cipher.encrypt('payload', key)) as Map;
      encrypted['mac'] = base64Encode(List<int>.filled(16, 0));
      await expectLater(
        cipher.decrypt(jsonEncode(encrypted), key),
        throwsA(
          isA<EncryptedPayloadException>().having(
            (error) => error.kind,
            'kind',
            EncryptedPayloadError.authentication,
          ),
        ),
      );
      await expectLater(
        cipher.decrypt('{"version":99}', key),
        throwsA(
          isA<EncryptedPayloadException>().having(
            (error) => error.kind,
            'kind',
            EncryptedPayloadError.unknownEnvelope,
          ),
        ),
      );
      await expectLater(
        cipher.decrypt('{broken', key),
        throwsA(isA<EncryptedPayloadException>()),
      );
    },
  );

  test('save and reopen preserve encrypted student data', () async {
    final store = MemoryStore();
    final keys = FakeKeyProvider(key: key);
    final repository = EncryptedStudentRepository(
      store: store,
      keyProvider: keys,
    );

    await repository.save(DemoRepository.data);
    final envelope =
        store.values[EncryptedStudentRepository.encryptedStorageKey]!;
    expect(envelope, isNot(contains('Марія Весняна')));

    final reopened = EncryptedStudentRepository(
      store: store,
      keyProvider: keys,
    );
    expect(
      codec.encode(await reopened.load()),
      codec.encode(DemoRepository.data),
    );
  });

  test('missing key does not seed over an encrypted document', () async {
    final store = MemoryStore();
    final first = EncryptedStudentRepository(
      store: store,
      keyProvider: FakeKeyProvider(key: key),
    );
    await first.save(DemoRepository.data);
    final original =
        store.values[EncryptedStudentRepository.encryptedStorageKey];

    final lost = EncryptedStudentRepository(
      store: store,
      keyProvider: FakeKeyProvider(),
    );
    await expectLater(
      lost.load(),
      throwsA(
        isA<StudentStorageException>().having(
          (error) => error.message,
          'message',
          contains('Ключ шифрування втрачено'),
        ),
      ),
    );
    expect(
      store.values[EncryptedStudentRepository.encryptedStorageKey],
      original,
    );
  });

  test(
    'plaintext v2 migration verifies encrypted data before deleting it',
    () async {
      final plaintext = codec.encode(DemoRepository.data);
      final store = MemoryStore({
        EncryptedStudentRepository.plaintextStorageKey: plaintext,
      });
      final repository = EncryptedStudentRepository(
        store: store,
        keyProvider: FakeKeyProvider(),
      );

      expect(codec.encode(await repository.load()), plaintext);
      expect(
        store.values,
        isNot(contains(EncryptedStudentRepository.plaintextStorageKey)),
      );
      expect(
        store.values[EncryptedStudentRepository.encryptedStorageKey],
        isNotNull,
      );
    },
  );

  test(
    'migration keeps plaintext when encrypted write or deletion fails',
    () async {
      final plaintext = codec.encode(DemoRepository.data);
      for (final failure in ['write', 'delete']) {
        final store =
            MemoryStore({
                EncryptedStudentRepository.plaintextStorageKey: plaintext,
              })
              ..failWrite = failure == 'write'
              ..failDelete = failure == 'delete';
        final repository = EncryptedStudentRepository(
          store: store,
          keyProvider: FakeKeyProvider(),
        );

        await expectLater(
          repository.load(),
          throwsA(isA<StudentStorageException>()),
        );
        expect(
          store.values[EncryptedStudentRepository.plaintextStorageKey],
          plaintext,
        );
      }
    },
  );

  test('pending plaintext cleanup resumes safely on next load', () async {
    final plaintext = codec.encode(DemoRepository.data);
    final store = MemoryStore({
      EncryptedStudentRepository.plaintextStorageKey: plaintext,
    })..failDelete = true;
    final keys = FakeKeyProvider();

    await expectLater(
      EncryptedStudentRepository(store: store, keyProvider: keys).load(),
      throwsA(isA<StudentStorageException>()),
    );
    expect(
      store.values[EncryptedStudentRepository.plaintextStorageKey],
      plaintext,
    );
    expect(
      store.values[EncryptedStudentRepository.encryptedStorageKey],
      isNotNull,
    );

    store.failDelete = false;
    final reopened = EncryptedStudentRepository(
      store: store,
      keyProvider: keys,
    );
    expect(codec.encode(await reopened.load()), plaintext);
    expect(
      store.values,
      isNot(contains(EncryptedStudentRepository.plaintextStorageKey)),
    );
  });

  test('conflicting plaintext is never deleted', () async {
    final store = MemoryStore();
    final keys = FakeKeyProvider(key: key);
    final repository = EncryptedStudentRepository(
      store: store,
      keyProvider: keys,
    );
    await repository.save(DemoRepository.data);
    store.values[EncryptedStudentRepository.plaintextStorageKey] = codec.encode(
      const StudentData(classes: [], students: []),
    );

    await expectLater(
      repository.load(),
      throwsA(isA<StudentStorageException>()),
    );
    expect(
      store.values[EncryptedStudentRepository.plaintextStorageKey],
      isNotNull,
    );
  });

  test('empty storage is seeded only once', () async {
    final store = MemoryStore();
    final keys = FakeKeyProvider();
    final first = EncryptedStudentRepository(store: store, keyProvider: keys);
    expect(codec.encode(await first.load()), codec.encode(DemoRepository.data));
    final envelope =
        store.values[EncryptedStudentRepository.encryptedStorageKey];

    final second = EncryptedStudentRepository(store: store, keyProvider: keys);
    expect(
      codec.encode(await second.load()),
      codec.encode(DemoRepository.data),
    );
    expect(
      store.values[EncryptedStudentRepository.encryptedStorageKey],
      envelope,
    );
    expect(keys.creates, 1);
  });

  test(
    'corrupt encrypted data and secure-storage failures are controlled',
    () async {
      final corruptStore = MemoryStore({
        EncryptedStudentRepository.encryptedStorageKey: '{broken',
      });
      await expectLater(
        EncryptedStudentRepository(
          store: corruptStore,
          keyProvider: FakeKeyProvider(key: key),
        ).load(),
        throwsA(isA<StudentStorageException>()),
      );

      final emptyStore = MemoryStore();
      await expectLater(
        EncryptedStudentRepository(
          store: emptyStore,
          keyProvider: FakeKeyProvider(createError: StateError('denied')),
        ).load(),
        throwsA(isA<StudentStorageException>()),
      );
      expect(emptyStore.values, isEmpty);
    },
  );
}
